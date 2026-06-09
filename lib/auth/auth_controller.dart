import 'package:flutter/foundation.dart';

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
  AuthController({required TokenStorage storage}) : _storage = storage;

  final TokenStorage _storage;

  AuthStatus _status = AuthStatus.unknown;
  AuthStatus get status => _status;

  AuthUser? _user;
  AuthUser? get user => _user;

  bool _busy = false;

  /// 로그인/회원가입 등 비동기 작업 진행 여부(버튼 로딩 표시에 사용).
  bool get isBusy => _busy;

  bool get isAuthenticated => _status == AuthStatus.authenticated;

  /// 앱 시작 시 호출. 저장된 토큰이 있으면 로그인 상태로 복원한다.
  Future<void> bootstrap() async {
    final token = await _storage.readAccessToken();
    _status = (token != null && token.isNotEmpty)
        ? AuthStatus.authenticated
        : AuthStatus.unauthenticated;
    notifyListeners();
  }

  /// 로그인.
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    return _run(() async {
      // TODO(api): 김민재 님 Auth API(POST /auth/login) 연동.
      //   응답으로 받은 accessToken/refreshToken 을 저장한다.
      await Future<void>.delayed(const Duration(milliseconds: 600));
      const fakeToken = 'mock-access-token';
      await _storage.saveAccessToken(fakeToken);
      _user = AuthUser(email: email);
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
      // TODO(api): 김민재 님 Auth API(POST /auth/signup) 연동.
      await Future<void>.delayed(const Duration(milliseconds: 600));
      const fakeToken = 'mock-access-token';
      await _storage.saveAccessToken(fakeToken);
      _user = AuthUser(email: email, nickname: nickname);
      _status = AuthStatus.authenticated;
    });
  }

  /// 로그아웃. 토큰을 삭제하고 미인증 상태로 전환.
  Future<void> logout() async {
    // TODO(api): 필요 시 서버 세션 무효화(POST /auth/logout) 호출.
    await _storage.clear();
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  /// 회원 탈퇴. 서버 탈퇴 후 로컬 토큰까지 정리.
  Future<AuthResult> withdraw() async {
    return _run(() async {
      // TODO(api): 김민재 님 Auth API(DELETE /auth/me) 연동.
      await Future<void>.delayed(const Duration(milliseconds: 600));
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
