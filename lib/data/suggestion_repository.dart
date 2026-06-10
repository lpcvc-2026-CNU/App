/// 랜드마크 건의 중복 여부를 판별하는 추상 인터페이스.
///
/// 실제 구현은 김민재 님 1순위(랜드마크 DB 조회)가 완료되면
/// 서버/로컬 DB를 조회하는 형태로 교체된다. 그 전까지는 [MockSuggestionRepository]
/// 가 하드코딩된 지원 리스트로 UI 흐름을 검증한다.
abstract class SuggestionRepository {
  /// 입력한 랜드마크명이 이미 지원되는지 검사.
  ///
  /// 중복이면 매칭된 기존 항목명을 반환하고, 아니면 null.
  Future<String?> findExisting(String name);
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
    // TODO(api): 김민재 님 1순위(랜드마크 DB 조회) 연동.
    //   서버/로컬 DB에서 정규화된 이름으로 중복 조회하도록 교체.
    final key = normalizeLandmarkName(name);
    if (key.isEmpty) return null;
    return _index[key];
  }
}
