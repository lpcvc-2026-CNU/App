import '../api/backend_client.dart';
import 'landmark_repository.dart';

/// 랜드마크 건의의 중복 검사 및 제출을 담당하는 추상 인터페이스.
///
/// 실연동 구현은 [ApiSuggestionRepository] 이며, UI/단위 테스트용으로는
/// [MockSuggestionRepository] 가 하드코딩 리스트로 흐름을 검증한다.
abstract class SuggestionRepository {
  /// 입력한 랜드마크명이 이미 지원되는지 검사.
  ///
  /// 중복이면 매칭된 기존 항목명을 반환하고, 아니면 null.
  Future<String?> findExisting(String name);

  /// 건의 제출. 서버측 중복 검증에서 막히면 [BackendException](400)이 던져진다.
  Future<void> submit({
    required String landmarkName,
    required String description,
  });
}

/// 비교용 정규화: 공백 제거 + 소문자화.
/// (한글은 소문자 영향 없음, 영문/대소문자/공백 차이를 흡수)
String normalizeLandmarkName(String input) =>
    input.replaceAll(RegExp(r'\s+'), '').toLowerCase();

/// UI 검증용 목(mock) 구현.
///
/// ⚠️ 데이터 연동 전까지만 사용. 실제 연동 시 [SuggestionRepository] 를
/// 구현한 DB/네트워크 버전으로 교체한다.
class MockSuggestionRepository implements SuggestionRepository {
  /// 이미 지원 중인 서울 주요 랜드마크 예시 목록.
  static const List<String> _existing = [
    '경복궁',
    '창덕궁',
    '덕수궁',
    '남산서울타워',
    'N서울타워',
    '명동성당',
    '광장시장',
    '동대문디자인플라자',
    '롯데월드타워',
    '63빌딩',
    '한강공원',
    '청계천',
    '서울숲',
    '북촌한옥마을',
    '인사동',
  ];

  late final Map<String, String> _index = {
    for (final name in _existing) normalizeLandmarkName(name): name,
  };

  @override
  Future<String?> findExisting(String name) async {
    final key = normalizeLandmarkName(name);
    if (key.isEmpty) return null;
    return _index[key];
  }

  @override
  Future<void> submit({
    required String landmarkName,
    required String description,
  }) async {
    // 목 구현: 실제 전송 없이 지연만 흉내낸다.
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }
}

/// 백엔드(`/api/...`) 실연동 구현.
///
/// - 중복 검사: [LandmarkRepository]가 캐시한 공식 랜드마크 목록과 대조.
/// - 제출: `POST /api/suggestions` (인증 필요). 서버가 대기/승인 건까지
///   포함해 최종 중복을 검증하며, 막히면 [BackendException](400)을 던진다.
class ApiSuggestionRepository implements SuggestionRepository {
  ApiSuggestionRepository({
    required BackendClient client,
    required LandmarkRepository landmarks,
  })  : _client = client,
        _landmarks = landmarks;

  final BackendClient _client;
  final LandmarkRepository _landmarks;

  @override
  Future<String?> findExisting(String name) => _landmarks.findExisting(name);

  @override
  Future<void> submit({
    required String landmarkName,
    required String description,
  }) async {
    await _client.postJson(
      '/api/suggestions',
      {'landmark_name': landmarkName, 'description': description},
      auth: true,
    );
  }
}
