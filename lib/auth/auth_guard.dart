import 'package:flutter/material.dart';

import 'auth_controller.dart';
import 'auth_scope.dart';
import '../ui/screens/auth/login_screen.dart';

/// 인증 상태에 따라 화면을 분기하는 가드 위젯.
///
/// - [AuthStatus.unknown]   → 로딩 스플래시(토큰 확인 중)
/// - [AuthStatus.authenticated]   → [child] (보호된 실제 화면)
/// - [AuthStatus.unauthenticated] → [LoginScreen]
///
/// 앱 진입점을 이 위젯으로 감싸면, 로그인 여부에 따라 자동으로
/// 로그인 화면 ↔ 본 화면이 전환된다.
class AuthGuard extends StatelessWidget {
  const AuthGuard({super.key, required this.child});

  /// 인증된 사용자에게 보여줄 보호 대상 화면.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);

    switch (auth.status) {
      case AuthStatus.unknown:
        return const _AuthSplash();
      case AuthStatus.authenticated:
        return child;
      case AuthStatus.unauthenticated:
        return const LoginScreen();
    }
  }
}

class _AuthSplash extends StatelessWidget {
  const _AuthSplash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF121212),
      body: Center(
        child: CircularProgressIndicator(color: Color(0xFFE61E2B)),
      ),
    );
  }
}
