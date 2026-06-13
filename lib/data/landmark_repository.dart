import '../api/backend_client.dart';
import 'suggestion_repository.dart' show normalizeLandmarkName;

/// 공식 랜드마크 마스터 데이터(`GET /api/landmarks`)를 조회·캐시하고,
/// 클라이언트 측 중복 검사를 제공한다.
///
/// 김민재 님 1순위(랜드마크 DB/조회 API)와 직접 연동하는 구현으로,
/// 기존 [MockSuggestionRepository] 의 하드코딩 리스트를 대체한다.
class LandmarkRepository {
  LandmarkRepository(this._client);

  final BackendClient _client;

  /// 정규화된 이름(공백제거·소문자) → 표시용 한국어 이름.
  /// 다국어 명칭(ko/en/zh/ja)을 모두 키로 등록해 어느 언어로 입력해도 잡는다.
  Map<String, String>? _index;

  Future<void> _ensureLoaded() async {
    if (_index != null) return;
    final data = await _client.getJson('/api/landmarks');
    final index = <String, String>{};
    if (data is List) {
      for (final item in data) {
        if (item is! Map) continue;
        final display =
            (item['name_ko'] ?? item['name_en'] ?? '').toString();
        for (final key in const ['name_ko', 'name_en', 'name_zh', 'name_ja']) {
          final value = item[key];
          if (value == null) continue;
          final norm = normalizeLandmarkName(value.toString());
          if (norm.isNotEmpty) index[norm] = display;
        }
      }
    }
    _index = index;
  }

  /// 마스터 데이터 강제 새로고침.
  Future<void> refresh() async {
    _index = null;
    await _ensureLoaded();
  }

  /// 입력명이 기존 공식 랜드마크와 일치하면 표시용 이름 반환, 아니면 null.
  ///
  /// 네트워크 실패 시에는 null을 반환해 화면 흐름을 막지 않고,
  /// 최종 중복 판정은 제출 시 서버 검증(`POST /api/suggestions`)에 위임한다.
  Future<String?> findExisting(String name) async {
    final key = normalizeLandmarkName(name);
    if (key.isEmpty) return null;
    try {
      await _ensureLoaded();
    } catch (_) {
      return null;
    }
    return _index?[key];
  }
}
