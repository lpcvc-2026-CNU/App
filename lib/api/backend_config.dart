import 'package:flutter/foundation.dart';

/// FastAPI 백엔드(`backend/`) 접속 설정.
///
/// 백엔드는 기본적으로 `0.0.0.0:8000`(uvicorn)에서 동작한다.
/// 개발 환경에 따라 호스트 주소가 달라지므로 한 곳에서 분기한다.
class BackendConfig {
  const BackendConfig._();

  /// 백엔드 base URL.
  ///
  /// 우선순위:
  ///   1) `--dart-define=BACKEND_URL=http://...` 로 주입한 값
  ///   2) Android 에뮬레이터 → 호스트 PC를 가리키는 `10.0.2.2`
  ///   3) 그 외(iOS 시뮬레이터/데스크톱/웹) → `localhost`
  static String get baseUrl {
    const override = String.fromEnvironment('BACKEND_URL');
    if (override.isNotEmpty) return override;

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://localhost:8000';
  }
}
