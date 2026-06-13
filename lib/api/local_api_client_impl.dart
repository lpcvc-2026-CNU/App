import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'local_api_client.dart';
import 'backend_client.dart';
import '../services/onnx_inference_service.dart';
import '../services/image_quality_service.dart';
import '../data/database_helper.dart';

/// 온디바이스 시연 환경에 알맞게 보정 및 완화된 ConfidencePolicy 임계값 파라미터
class _ConfidencePolicy {
  static const double rejectThreshold            = 0.22; // FP16 모델 정밀도 회복에 따른 보정
  static const double weakRejectThreshold        = 0.28;
  static const double weakMargin                 = 0.08;
  static const double matchThreshold             = 0.48; // FP16 매칭 활성화
  static const double matchFloor                 = 0.38; 
  static const double matchMargin                = 0.10; 
}

class LocalApiClientImpl implements LocalApiClient {
  final OnnxInferenceService _onnxService;
  final ImageQualityService _qualityService;
  final DatabaseHelper _dbHelper;
  final BackendClient? _backendClient;

  LocalApiClientImpl(this._onnxService, this._qualityService, this._dbHelper, [this._backendClient]);


  // ── 다국어 지원 로케일 정보 ──────────────────────────────────────────────────
  String _languageCode = 'ko'; // 기본값은 한국어

  @override
  String get languageCode => _languageCode;

  @override
  set languageCode(String code) {
    _languageCode = code;
  }

  @override
  String? get modelSpecWarning => _onnxService.modelSpecWarning;


  // ── 프로토타입 캐시 ─────────────────────────────────────────────────────────
  List<String>? _landmarkIds;
  List<List<double>>? _protoMatrix; // (N, 512) – 각 행이 L2-정규화된 프로토타입

  Future<void> _loadPrototypes() async {
    if (_protoMatrix != null) return;
    final String jsonString =
        await rootBundle.loadString('assets/mobile_artifacts_fp16/prototype_index.json');
    final Map<String, dynamic> jsonMap = json.decode(jsonString);
    final items = jsonMap['items'] as List<dynamic>;

    final ids = <String>[];
    final matrix = <List<double>>[];

    for (final item in items) {
      final id = item['landmark_id'] as String;
      final rawList = (item['embedding'] ?? item['prototype']) as List<dynamic>;
      final rawProto = rawList
          .map((e) => (e as num).toDouble())
          .toList();
      ids.add(id);
      matrix.add(_l2Normalize(rawProto));
    }

    _landmarkIds = ids;
    _protoMatrix = matrix;
  }

  /// L2 정규화
  List<double> _l2Normalize(List<double> v) {
    double norm = 0.0;
    for (final x in v) {
      norm += x * x;
    }
    norm = sqrt(norm);
    if (norm < 1e-12) return v;
    return v.map((x) => x / norm).toList();
  }

  /// Python _cosine_to_matrix 와 동일: 임베딩과 각 프로토타입의 내적 (L2-정규화 가정)
  double _dotProduct(List<double> a, List<double> b) {
    double s = 0.0;
    for (int i = 0; i < a.length; i++) {
      s += a[i] * b[i];
    }
    return s;
  }

  /// Python _percentage: int(round(max(0, min(1, score)) * 100))
  int _percentage(double score) {
    return (score.clamp(0.0, 1.0) * 100).round();
  }

  // ── LocalApiClient interface ────────────────────────────────────────────────

  @override
  Future<Map<String, dynamic>> validateImage(Uint8List imageBytes) async {
    return _qualityService.assessImageQuality(imageBytes);
  }

  @override
  Future<List<double>> extractImageEmbedding(Uint8List imageBytes) async {
    return _onnxService.extractEmbedding(imageBytes);
  }

  /// Python search.py _build_outcome + search_by_image 에 해당
  @override
  Future<List<Map<String, dynamic>>> getRetrievalResults(
    List<double> embedding, {
    int topK = 3,
  }) async {
    await _loadPrototypes();

    final ids = _landmarkIds!;
    final matrix = _protoMatrix!;

    // 코사인 유사도 계산 (L2-정규화된 벡터간 내적 = 코사인 유사도)
    final scores = <Map<String, dynamic>>[];
    for (int i = 0; i < ids.length; i++) {
      final score = _dotProduct(embedding, matrix[i]);
      scores.add({
        'landmark_id': ids[i],
        'raw_score': score,
        'display_score': _percentage(score),
        'score_type': 'cosine_similarity',
      });
    }

    // 내림차순 정렬 후 Top-K
    scores.sort((a, b) => (b['raw_score'] as double).compareTo(a['raw_score'] as double));
    return scores.take(topK).toList();
  }

  /// Python search.py apply_decision_policy 를 그대로 포팅 (image 모드)
  @override
  Future<Map<String, dynamic>> checkSearchConfidence(
    List<Map<String, dynamic>> topResults,
    String kind,
  ) async {
    if (topResults.isEmpty) {
      return {'decision': 'out_of_scope', 'reason_codes': ['no_candidate']};
    }

    final double top1Score = topResults[0]['raw_score'] as double;
    final double top2Score =
        topResults.length > 1 ? topResults[1]['raw_score'] as double : 0.0;
    final double margin = top1Score - top2Score;
    final reasons = <String>[];

    String decision;

    if (top1Score < _ConfidencePolicy.rejectThreshold) {
      // 1. Hard reject
      decision = 'out_of_scope';
      reasons.add('top1_below_reject');
    } else if (top1Score < _ConfidencePolicy.weakRejectThreshold &&
        margin < _ConfidencePolicy.weakMargin) {
      // 2. Weak reject
      decision = 'out_of_scope';
      reasons.addAll(['top1_weak', 'margin_low']);
    } else if (top1Score >= _ConfidencePolicy.matchThreshold) {
      // 3. Strong match
      decision = 'matched';
      reasons.add('top1_high');
    } else if (top1Score >= _ConfidencePolicy.matchFloor &&
        margin >= _ConfidencePolicy.matchMargin) {
      // 4. Mid match with sufficient margin
      decision = 'matched';
      reasons.addAll(['top1_mid', 'margin_high']);
    } else {
      // 5. Ambiguous
      decision = 'ambiguous';
      if (top1Score < _ConfidencePolicy.matchThreshold) {
        reasons.add('top1_below_match');
      }
      if (margin < _ConfidencePolicy.matchMargin) {
        reasons.add('margin_low');
      }
    }

    return {'decision': decision, 'reason_codes': reasons};
  }

  @override
  Future<Map<String, dynamic>> getLandmarkDetails(String id) async {
    final db = await _dbHelper.database;
    final res = await db.query('landmarks', where: 'id = ?', whereArgs: [id]);
    if (res.isEmpty) return {};

    final row = Map<String, dynamic>.from(res.first);

    // 설정된 languageCode에 따라 다국어 데이터 바인딩 (en, zh, ja, ko)
    if (_languageCode == 'en') {
      row['name'] = row['name_en'] ?? row['name_ko'] ?? id;
      row['description'] = row['description_en'] ?? row['description_ko'] ?? '';
    } else if (_languageCode == 'zh') {
      row['name'] = row['name_zh'] ?? row['name_en'] ?? row['name_ko'] ?? id;
      row['description'] = row['description_zh'] ?? row['description_en'] ?? row['description_ko'] ?? '';
    } else if (_languageCode == 'ja') {
      row['name'] = row['name_ja'] ?? row['name_en'] ?? row['name_ko'] ?? id;
      row['description'] = row['description_ja'] ?? row['description_en'] ?? row['description_ko'] ?? '';
    } else {
      // 기본값 'ko'
      row['name'] = row['name_ko'] ?? row['name_en'] ?? id;
      row['description'] = row['description_ko'] ?? row['description_en'] ?? '';
    }

    // parent_landmark_id를 활용한 부모 랜드마크 한국어/영어/기타 명칭 조회 추가 (P1)
    final parentId = row['parent_landmark_id'] as String?;
    if (parentId != null && parentId.isNotEmpty) {
      final parentRes = await db.query('landmarks', where: 'id = ?', whereArgs: [parentId]);
      if (parentRes.isNotEmpty) {
        final parentRow = parentRes.first;
        if (_languageCode == 'en') {
          row['parent_name'] = parentRow['name_en'] ?? parentRow['name_ko'] ?? '';
        } else if (_languageCode == 'zh') {
          row['parent_name'] = parentRow['name_zh'] ?? parentRow['name_en'] ?? parentRow['name_ko'] ?? '';
        } else if (_languageCode == 'ja') {
          row['parent_name'] = parentRow['name_ja'] ?? parentRow['name_en'] ?? parentRow['name_ko'] ?? '';
        } else {
          row['parent_name'] = parentRow['name_ko'] ?? parentRow['name_en'] ?? '';
        }
      }
    }

    return row;
  }

  @override
  Future<void> logSearch(Map<String, dynamic> logData) async {
    try {
      final db = await _dbHelper.database;
      await db.insert('search_logs', logData);
    } catch (e) {
      print('로그 기록 실패 (무시): $e');
    }

    if (_backendClient != null) {
      // 서버 로그 기록은 네트워크 통신이 필요하므로, 사용자 UI 흐름에 지장을 주지 않도록
      // 비동기 백그라운드로 호출하고 예외 발생 시 print 로그만 남깁니다.
      _backendClient!.postJson('/api/search/logs', logData).then((_) {
        print('서버 검색 로그 전송 성공');
      }).catchError((err) {
        print('서버 검색 로그 전송 실패 (무시): $err');
      });
    }
  }


  @override
  Future<Map<String, dynamic>> search(Uint8List imageBytes, {String? textQuery}) async {
    final stopwatch = Stopwatch()..start();

    // ── 텍스트 검색 모드 ────────────────────────────────────────────────────
    // 현재 앱 검색은 SQLite LIKE 기반 keyword search이다.
    // text encoder ONNX는 artifact contract에 포함되어 있지만 semantic search는 후속 작업이다.
    if (textQuery != null && textQuery.trim().isNotEmpty) {
      final db = await _dbHelper.database;
      final keyword = textQuery.trim();

      final res = await db.rawQuery('''
        SELECT DISTINCT l.id as landmark_id, l.name_ko
        FROM landmarks l
        LEFT JOIN candidate_texts c ON l.id = c.landmark_id
        WHERE l.name_ko LIKE ? OR l.name_en LIKE ? OR l.district LIKE ? OR c.candidate_text LIKE ?
        LIMIT 3
      ''', ['%$keyword%', '%$keyword%', '%$keyword%', '%$keyword%']);

      final top3 = res
          .map((r) => {
                'landmark_id': r['landmark_id'],
                'score_type': 'keyword_match',
                'raw_score': null,
                'keyword_score': 0.95,
                'semantic_score': null,
              })
          .toList();

      final decision = top3.isNotEmpty ? 'matched' : 'out_of_scope';
      stopwatch.stop();

      await logSearch({
        'timestamp': DateTime.now().toIso8601String(),
        'query_type': 'text',
        'top1_id': top3.isNotEmpty ? top3[0]['landmark_id'] : null,
        'decision': decision,
        'reason_codes': 'keyword_match',
        'latency_ms': stopwatch.elapsedMilliseconds,
        'model_version': 'MobileCLIP2-S3-FP16',
        'backend': 'SQLite-LIKE',
        'top3_scores': top3.map((r) => '${r["landmark_id"]}=0.95').join(', '),
        'margin': 0.0,
        'decision_status': decision,
      });

      return {
        'top3': top3,
        'decision': decision,
        'reason_codes': ['keyword_match'],
        'latency_ms': stopwatch.elapsedMilliseconds,
      };
    }

    // ── 이미지 검색 모드 ────────────────────────────────────────────────────

    // 1. 이미지 품질 검증
    final validation = await validateImage(imageBytes);
    if (validation['ok'] == false) {
      stopwatch.stop();
      return {
        'decision': 'low_quality',
        'reason_codes': validation['reason_codes'],
        'top3': [],
        'latency_ms': stopwatch.elapsedMilliseconds,
      };
    }

    // 2. 임베딩 추출 (전처리 + ONNX 추론 + L2 정규화)
    final embedding = await extractImageEmbedding(imageBytes);
    print('[Debug] embedding[0..4]: ${embedding.take(5).toList()}');

    // 3. 유사도 검색 및 Top-3 랭킹
    final top3 = await getRetrievalResults(embedding);
    print('[Debug] top3 scores: ${top3.map((r) => '${r["landmark_id"]}=${(r["raw_score"] as double).toStringAsFixed(4)}').join(', ')}');

    // 4. 신뢰도 판단 (Confidence Policy)
    final confidence = await checkSearchConfidence(top3, 'image');
    print('[Debug] decision: ${confidence["decision"]}, reasons: ${confidence["reason_codes"]}');

    stopwatch.stop();

    final top1RawScore = top3.isNotEmpty ? top3[0]['raw_score'] as double : 0.0;
    final top2RawScore = top3.length > 1 ? top3[1]['raw_score'] as double : 0.0;
    final margin = top1RawScore - top2RawScore;
    final top3ScoresStr = top3.map((r) => '${r["landmark_id"]}=${(r["raw_score"] as double).toStringAsFixed(4)}').join(', ');

    // 5. 검색 로그 기록
    await logSearch({
      'timestamp': DateTime.now().toIso8601String(),
      'query_type': 'image',
      'top1_id': top3.isNotEmpty ? top3[0]['landmark_id'] : null,
      'decision': confidence['decision'],
      'reason_codes': (confidence['reason_codes'] as List).join(','),
      'latency_ms': stopwatch.elapsedMilliseconds,
      'model_version': 'MobileCLIP2-S3-FP16',
      'backend': 'ONNXRuntime-CPU',
      'top3_scores': top3ScoresStr,
      'margin': margin,
      'decision_status': confidence['decision'],
    });

    return {
      'top3': top3,
      'decision': confidence['decision'],
      'reason_codes': confidence['reason_codes'],
      'latency_ms': stopwatch.elapsedMilliseconds,
    };
  }
}
