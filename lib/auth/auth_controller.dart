import 'dart:async';

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
  const AuthUser({required this.email, this.nickname, this.isAdmin = false});

  final String email;
  final String? nickname;

  /// 관리자(개발자) 여부. admin 전용 메뉴(건의 관리) 노출 분기에 사용.
  final bool isAdmin;
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
    String? Function()? pushTokenProvider,
  })  : _storage = storage,
        _backend = backendClient,
        _pushTokenProvider = pushTokenProvider;

  final TokenStorage _storage;
  final BackendClient _backend;

  /// 현재 기기의 FCM 푸시 토큰을 읽어오는 함수(없으면 null).
  /// PushNotificationService에 직접 의존하지 않도록 주입받는다.
  final String? Function()? _pushTokenProvider;

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
      await _loadMe();
      _status = AuthStatus.authenticated;
      // mock 토큰은 앱 실행마다 바뀌고 실 FCM도 재설치 시 바뀌므로 서버와 동기화.
      unawaited(syncPushToken());
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

  /// `/api/auth/me` 응답으로 [_user] 를 구성하는 공통 헬퍼.
  ///
  /// 로그인 응답(TokenResponse)에는 is_admin이 없어 항상 /me 를 기준으로 한다.
  Future<void> _loadMe() async {
    final me = await _backend.getJson('/api/auth/me', auth: true);
    _user = AuthUser(
      email: (me['email'] ?? '') as String,
      nickname: me['nickname'] as String?,
      isAdmin: (me['is_admin'] ?? false) == true,
    );
  }

  /// 현재 기기의 FCM 토큰을 서버(User.push_token)에 반영한다.
  ///
  /// 미인증 상태면 아무것도 하지 않으며, 실패해도 앱 흐름에 영향이 없도록
  /// 조용히 무시한다. 백엔드 엔드포인트가 query parameter 를 받는 점에 주의.
  Future<void> syncPushToken([String? token]) async {
    if (!isAuthenticated) return;
    final t = token ?? _pushTokenProvider?.call();
    if (t == null || t.isEmpty) return;
    try {
      await _backend.patchJson(
        '/api/auth/fcm-token?push_token=${Uri.encodeQueryComponent(t)}',
        {},
        auth: true,
      );
    } catch (_) {}
  }

  /// 로그인. 기기 푸시 토큰이 있으면 함께 보내 알림 수신을 활성화한다.
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    return _run(() async {
      final pushToken = _pushTokenProvider?.call();
      final res = await _backend.postJson(
        '/api/auth/login',
        {
          'email': email,
          'password': password,
          if (pushToken != null && pushToken.isNotEmpty)
            'push_token': pushToken,
        },
      );
      await _storage.saveAccessToken(res['access_token'] as String);
      try {
        await _loadMe();
      } on BackendException {
        // /me 일시 실패 시 로그인 응답 정보로 최소 구성.
        _user = AuthUser(email: email, nickname: res['nickname'] as String?);
      }
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
      final pushToken = _pushTokenProvider?.call();
      await _backend.postJson(
        '/api/auth/register',
        {
          'email': email,
          'password': password,
          'nickname': effectiveNickname,
          if (pushToken != null && pushToken.isNotEmpty)
            'push_token': pushToken,
        },
      );
      // 가입 성공 후 자동 로그인.
      final res = await _backend.postJson(
        '/api/auth/login',
        {
          'email': email,
          'password': password,
          if (pushToken != null && pushToken.isNotEmpty)
            'push_token': pushToken,
        },
      );
      await _storage.saveAccessToken(res['access_token'] as String);
      try {
        await _loadMe();
      } on BackendException {
        _user = AuthUser(email: email, nickname: res['nickname'] as String?);
      }
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
