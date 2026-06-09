import 'package:flutter/material.dart';

import '../../../auth/auth_scope.dart';
import 'widgets/auth_widgets.dart';

/// 회원가입 화면.
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _nicknameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final auth = AuthScope.read(context);
    final result = await auth.signUp(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      nickname: _nicknameController.text.trim().isEmpty
          ? null
          : _nicknameController.text.trim(),
    );

    if (!mounted) return;
    if (result.ok) {
      // 가입 후 자동 로그인 → 가입 플로우를 닫으면 AuthGuard 가 본 화면을 띄운다.
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(result.message ?? '회원가입에 실패했습니다.'),
        ),
      );
    }
  }

  String? _validateEmail(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return '이메일을 입력해 주세요.';
    if (!v.contains('@') || !v.contains('.')) return '올바른 이메일 형식이 아닙니다.';
    return null;
  }

  String? _validatePassword(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return '비밀번호를 입력해 주세요.';
    if (v.length < 8) return '비밀번호는 8자 이상이어야 합니다.';
    return null;
  }

  String? _validateConfirm(String? value) {
    if ((value ?? '').isEmpty) return '비밀번호를 다시 입력해 주세요.';
    if (value != _passwordController.text) return '비밀번호가 일치하지 않습니다.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);

    return Scaffold(
      backgroundColor: AuthColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('회원가입',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  const Text(
                    '계정을 만들어 보세요',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 28),
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
                    controller: _nicknameController,
                    label: '닉네임 (선택)',
                    prefixIcon: Icons.person_outline,
                    textInputAction: TextInputAction.next,
                    enabled: !auth.isBusy,
                  ),
                  const SizedBox(height: 16),
                  AuthTextField(
                    controller: _passwordController,
                    label: '비밀번호',
                    hint: '8자 이상',
                    prefixIcon: Icons.lock_outline,
                    obscureText: true,
                    textInputAction: TextInputAction.next,
                    validator: _validatePassword,
                    enabled: !auth.isBusy,
                  ),
                  const SizedBox(height: 16),
                  AuthTextField(
                    controller: _confirmController,
                    label: '비밀번호 확인',
                    prefixIcon: Icons.lock_outline,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    validator: _validateConfirm,
                    onSubmitted: (_) => _submit(),
                    enabled: !auth.isBusy,
                  ),
                  const SizedBox(height: 28),
                  AuthPrimaryButton(
                    label: '가입하기',
                    busy: auth.isBusy,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
