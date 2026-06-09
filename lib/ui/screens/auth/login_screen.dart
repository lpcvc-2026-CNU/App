import 'package:flutter/material.dart';

import '../../../auth/auth_scope.dart';
import 'signup_screen.dart';
import 'widgets/auth_widgets.dart';

/// 로그인 화면.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final auth = AuthScope.read(context);
    final result = await auth.login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;
    if (!result.ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(result.message ?? '로그인에 실패했습니다.'),
        ),
      );
    }
    // 성공 시에는 AuthGuard 가 상태 변화를 감지해 자동으로 화면을 전환한다.
  }

  String? _validateEmail(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return '이메일을 입력해 주세요.';
    if (!v.contains('@') || !v.contains('.')) return '올바른 이메일 형식이 아닙니다.';
    return null;
  }

  String? _validatePassword(String? value) {
    if ((value ?? '').isEmpty) return '비밀번호를 입력해 주세요.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context); // busy 상태 구독

    return Scaffold(
      backgroundColor: AuthColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.travel_explore,
                        color: AuthColors.accent, size: 64),
                    const SizedBox(height: 20),
                    const Text(
                      '다시 오신 것을 환영해요',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '로그인하고 랜드마크를 탐색해 보세요',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AuthColors.label, fontSize: 14),
                    ),
                    const SizedBox(height: 36),
                    AuthTextField(
                      controller: _emailController,
                      label: '이메일',
                      hint: 'name@example.com',
                      prefixIcon: Icons.mail_outline,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: _validateEmail,
                      enabled: !auth.isBusy,
                    ),
                    const SizedBox(height: 16),
                    AuthTextField(
                      controller: _passwordController,
                      label: '비밀번호',
                      prefixIcon: Icons.lock_outline,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      validator: _validatePassword,
                      onSubmitted: (_) => _submit(),
                      enabled: !auth.isBusy,
                    ),
                    const SizedBox(height: 28),
                    AuthPrimaryButton(
                      label: '로그인',
                      busy: auth.isBusy,
                      onPressed: _submit,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          '아직 계정이 없으신가요?',
                          style: TextStyle(color: AuthColors.label),
                        ),
                        TextButton(
                          onPressed: auth.isBusy
                              ? null
                              : () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const SignUpScreen(),
                                    ),
                                  ),
                          child: const Text(
                            '회원가입',
                            style: TextStyle(
                              color: AuthColors.accent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
