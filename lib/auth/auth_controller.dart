import 'package:flutter/foundation.dart';

import '../api/backend_client.dart';
import 'token_storage.dart';

/// 인증 상태.
enum AuthStatus {
  /// 앱 시작 직후, 저장된 토큰을 아직 확인하지 못한 상태.
  unknown,

  /// 로그인 됨.
  authenticated,

  /// 로그아웃/미로그인 상태.
  unauthenticated,
}

/// 로그인한 사용자의 최소 정보(클라이언트 보관용).
@immutable
class AuthUser {
  const AuthUser({required this.email, this.nickname});

  final String email;
  final String? nickname;
}

/// 앱 전역의 인증 상태를 관리하는 컨트롤러.
///
/// ChangeNotifier 기반이라 별도 상태관리 패키지 없이 [AuthScope]/
/// ListenableBuilder 로 화면에서 구독할 수 있다.
///
/// ⚠️ 실제 서버 인증 연동(김민재 님 Auth API)은 아직 미구현 상태다.
/// 아래 `// TODO(api):` 지점이 API 연동 포인트이며, 현재는 UI/상태 흐름을
/// 검증하기 위한 목(mock) 동작으로 처리한다.
class AuthController extends ChangeNotifier {
  AuthController({
    required TokenStorage storage,
    required BackendClient backendClient,
  })  : _storage = storage,
        _backend = backendClient;

  final TokenStorage _storage;
  final BackendClient _backend;

  AuthStatus _status = AuthStatus.unknown;
  AuthStatus get status => _status;

  AuthUser? _user;
  AuthUser? get user => _user;

  bool _busy = false;

  /// 로그인/회원가입 등 비동기 작업 진행 여부(버튼 로딩 표시에 사용).
  bool get isBusy => _busy;

  bool get isAuthenticated => _status == AuthStatus.authenticated;

  /// 앱 시작 시 호출. 저장된 토큰을 서버로 검증해 로그인 상태를 복원한다.
  ///
  /// 토큰 존재 여부만 보지 않고 `/api/auth/me` 로 실제 유효성을 확인한다.
  /// (구 빌드의 mock 토큰이나 만료 토큰이 남아 인증 상태로 오인되는 것을 방지)
  Future<void> bootstrap() async {
    final token = await _storage.readAccessToken();
    if (token == null || token.isEmpty) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }
    try {
      final me = await _backend.getJson('/api/auth/me', auth: true);
      _user = AuthUser(
        email: (me['email'] ?? '') as String,
        nickname: me['nickname'] as String?,
      );
      _status = AuthStatus.authenticated;
    } on BackendException catch (e) {
      if (e.isUnauthorized) {
        // 무효 토큰(만료/위조/구 mock) → 정리 후 로그인 화면으로.
        await _storage.clear();
        _status = AuthStatus.unauthenticated;
      } else {
        // 네트워크 일시 오류: 토큰은 유지하고 인증 상태로 낙관 복원.
        _status = AuthStatus.authenticated;
      }
    }
    notifyListeners();
  }

  /// 로그인.
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    return _run(() async {
      final res = await _backend.postJson(
        '/api/auth/login',
        {'email': email, 'password': password},
      );
      await _storage.saveAccessToken(res['access_token'] as String);
      _user = AuthUser(email: email, nickname: res['nickname'] as String?);
      _status = AuthStatus.authenticated;
    });
  }

  /// 회원가입. 성공 시 자동 로그인 처리.
  Future<AuthResult> signUp({
    required String email,
    required String password,
    String? nickname,
  }) async {
    return _run(() async {
      // nickname 미입력 시 이메일 로컬파트를 기본값으로 사용(백엔드 min_length=1 충족).
      final effectiveNickname =
          (nickname == null || nickname.isEmpty) ? email.split('@').first : nickname;
      await _backend.postJson(
        '/api/auth/register',
        {'email': email, 'password': password, 'nickname': effectiveNickname},
      );
      // 가입 성공 후 자동 로그인.
      final res = await _backend.postJson(
        '/api/auth/login',
        {'email': email, 'password': password},
      );
      await _storage.saveAccessToken(res['access_token'] as String);
      _user = AuthUser(email: email, nickname: res['nickname'] as String?);
      _status = AuthStatus.authenticated;
    });
  }

  /// 로그아웃. 서버 FCM 토큰 정리 후 로컬 토큰 삭제.
  Future<void> logout() async {
    try {
      await _backend.postJson('/api/auth/logout', {}, auth: true);
    } catch (_) {}
    await _storage.clear();
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  /// 회원 탈퇴. 서버에서 계정 삭제 후 로컬 토큰 정리.
  Future<AuthResult> withdraw() async {
    return _run(() async {
      await _backend.deleteJson('/api/auth/withdraw', auth: true);
      await _storage.clear();
      _user = null;
      _status = AuthStatus.unauthenticated;
    });
  }

  /// 공통 실행 래퍼: busy 토글 + 예외 → 실패 결과 변환.
  Future<AuthResult> _run(Future<void> Function() action) async {
    if (_busy) return const AuthResult.failure('이미 처리 중입니다.');
    _busy = true;
    notifyListeners();
    try {
      await action();
      return const AuthResult.success();
    } catch (e) {
      return AuthResult.failure('요청을 처리하지 못했습니다. ($e)');
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}

/// 인증 작업 결과.
@immutable
class AuthResult {
  const AuthResult.success()
      : ok = true,
        message = null;
  const AuthResult.failure(this.message) : ok = false;

  final bool ok;
  final String? message;
}
