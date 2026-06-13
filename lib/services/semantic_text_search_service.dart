import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

import '../data/text_index_repository.dart';
import 'onnx_inference_service.dart';
import 'tokenizer_service.dart';

class SemanticTextSearchService {
  static const String _policyAssetPath =
      'assets/mobile_artifacts_fp16/text_search_policy.json';

  final OnnxInferenceService _onnxService;
  final TokenizerService _tokenizerService;
  final TextIndexRepository _textIndexRepository;

  Map<String, dynamic>? _policy;

  SemanticTextSearchService(
    this._onnxService, [
    TokenizerService? tokenizerService,
    TextIndexRepository? textIndexRepository,
  ])  : _tokenizerService = tokenizerService ?? TokenizerService(),
        _textIndexRepository = textIndexRepository ?? TextIndexRepository();

  Future<Map<String, dynamic>> search(
    String query, {
    required Map<String, double> keywordScores,
    int topK = 3,
  }) async {
    final policy = await _loadPolicy();
    final semanticWeight = _readDouble(policy, 'semantic_weight', 0.75);
    final keywordWeight = _readDouble(policy, 'keyword_weight', 0.25);
    final matchedThreshold = _readDouble(policy, 'matched_threshold', 0.45);
    final ambiguousMargin = _readDouble(policy, 'ambiguous_margin', 0.08);
    final outOfScopeThreshold =
        _readDouble(policy, 'out_of_scope_threshold', 0.25);
    final noKeywordOosMargin =
        _readDouble(policy, 'no_keyword_oos_margin', 0.05);
    final noKeywordMatchThreshold =
        _readDouble(policy, 'no_keyword_match_threshold', 0.60);

    final tokens = await _tokenizerService.tokenize(query);
    final queryEmbedding = await _onnxService.extractTextEmbedding(tokens);
    final items = await _textIndexRepository.loadItems();
    final byLandmark = <String, Map<String, dynamic>>{};

    for (final item in items) {
      final semanticScore = _dotProduct(queryEmbedding, item.embedding);
      final keywordScore = keywordScores[item.landmarkId] ?? 0.0;
      final finalScore =
          semanticWeight * semanticScore + keywordWeight * keywordScore;
      final current = byLandmark[item.landmarkId];
      if (current == null ||
          finalScore > (current['final_text_score'] as double)) {
        byLandmark[item.landmarkId] = {
          'landmark_id': item.landmarkId,
          'parent_landmark_id': item.parentLandmarkId,
          'score_type': 'semantic_text_fusion',
          'raw_score': semanticScore,
          'semantic_score': semanticScore,
          'keyword_score': keywordScore,
          'final_text_score': finalScore,
          'display_score': _percentage(finalScore),
          'matched_text': item.text,
          'text_type': item.textType,
        };
      }
    }

    final ranked = byLandmark.values.toList()
      ..sort(
        (a, b) => (b['final_text_score'] as double)
            .compareTo(a['final_text_score'] as double),
      );
    final top3 = ranked.take(topK).toList();
    final top1Score =
        top3.isNotEmpty ? top3[0]['final_text_score'] as double : 0.0;
    final top2Score =
        top3.length > 1 ? top3[1]['final_text_score'] as double : 0.0;
    final margin = top1Score - top2Score;

    String decision;
    List<String> reasons;
    final top1KeywordScore =
        top3.isNotEmpty ? top3[0]['keyword_score'] as double : 0.0;
    if (top3.isEmpty || top1Score < outOfScopeThreshold) {
      decision = 'out_of_scope';
      reasons = ['text_top1_below_oos'];
    } else if (top1KeywordScore == 0.0 && top1Score < noKeywordMatchThreshold) {
      decision = 'out_of_scope';
      reasons = ['no_keyword_and_score_below_match'];
    } else if (top1KeywordScore == 0.0 && margin < noKeywordOosMargin) {
      decision = 'out_of_scope';
      reasons = ['no_keyword_and_margin_low'];
    } else if (margin < ambiguousMargin) {
      decision = 'ambiguous';
      reasons = ['text_margin_low'];
    } else if (top1Score >= matchedThreshold) {
      decision = 'matched';
      reasons = ['text_score_high'];
    } else {
      decision = 'ambiguous';
      reasons = ['text_score_mid'];
    }

    return {
      'top3': top3,
      'decision': decision,
      'reason_codes': reasons,
      'score_type': 'semantic_text_fusion',
      'top1_score': top1Score,
      'top2_score': top2Score,
      'margin': margin,
    };
  }

  Future<Map<String, dynamic>> _loadPolicy() async {
    if (_policy != null) return _policy!;
    try {
      final raw = await rootBundle.loadString(_policyAssetPath);
      _policy = json.decode(raw) as Map<String, dynamic>;
    } catch (_) {
      _policy = const {
        'semantic_weight': 0.75,
        'keyword_weight': 0.25,
        'matched_threshold': 0.45,
        'ambiguous_margin': 0.08,
        'out_of_scope_threshold': 0.25,
        'no_keyword_oos_margin': 0.05,
        'no_keyword_match_threshold': 0.60,
      };
    }
    return _policy!;
  }

  double _readDouble(Map<String, dynamic> map, String key, double fallback) {
    final value = map[key];
    return value is num ? value.toDouble() : fallback;
  }

  double _dotProduct(List<double> a, List<double> b) {
    var sum = 0.0;
    for (var i = 0; i < min(a.length, b.length); i++) {
      sum += a[i] * b[i];
    }
    return sum;
  }

  int _percentage(double score) {
    return (score.clamp(0.0, 1.0) * 100).round();
  }
}
