import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 인증 토큰을 저장/조회/삭제하는 추상 인터페이스.
///
/// 실제 저장 구현(보안 저장소, 메모리 등)을 이 인터페이스 뒤로 숨겨,
/// 추후 백엔드/저장 방식이 바뀌어도 화면·컨트롤러 코드는 영향받지 않도록 한다.
abstract class TokenStorage {
  /// 액세스 토큰 저장.
  Future<void> saveAccessToken(String token);

  /// 리프레시 토큰 저장. (선택적으로 사용)
  Future<void> saveRefreshToken(String token);

  /// 저장된 액세스 토큰을 반환. 없으면 null.
  Future<String?> readAccessToken();

  /// 저장된 리프레시 토큰을 반환. 없으면 null.
  Future<String?> readRefreshToken();

  /// 모든 토큰 삭제(로그아웃/탈퇴 시).
  Future<void> clear();
}

/// OS 보안 저장소(Android Keystore / iOS Keychain)에 토큰을 암호화 저장하는 구현.
///
/// 평문 SharedPreferences 대신 사용해, 토큰을 안전하게 보관한다.
class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  final FlutterSecureStorage _storage;

  static const _kAccessToken = 'auth_access_token';
  static const _kRefreshToken = 'auth_refresh_token';

  @override
  Future<void> saveAccessToken(String token) =>
      _storage.write(key: _kAccessToken, value: token);

  @override
  Future<void> saveRefreshToken(String token) =>
      _storage.write(key: _kRefreshToken, value: token);

  @override
  Future<String?> readAccessToken() => _storage.read(key: _kAccessToken);

  @override
  Future<String?> readRefreshToken() => _storage.read(key: _kRefreshToken);

  @override
  Future<void> clear() async {
    await _storage.delete(key: _kAccessToken);
    await _storage.delete(key: _kRefreshToken);
  }
}

/// 테스트/로컬 개발용 인메모리 구현.
///
/// flutter_secure_storage 가 동작하지 않는 환경(단위 테스트 등)에서
/// 대체 주입할 수 있다.
class InMemoryTokenStorage implements TokenStorage {
  String? _access;
  String? _refresh;

  @override
  Future<void> saveAccessToken(String token) async => _access = token;

  @override
  Future<void> saveRefreshToken(String token) async => _refresh = token;

  @override
  Future<String?> readAccessToken() async => _access;

  @override
  Future<String?> readRefreshToken() async => _refresh;

  @override
  Future<void> clear() async {
    _access = null;
    _refresh = null;
  }
}
