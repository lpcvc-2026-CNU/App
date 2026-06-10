import 'package:flutter/material.dart';

import '../../../auth/auth_scope.dart';
import 'widgets/auth_widgets.dart';

/// 계정 화면: 로그인 사용자 정보 + 로그아웃 / 회원 탈퇴 진입점.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  Future<void> _confirmLogout(BuildContext context) async {
    final ok = await _showConfirm(
      context,
      title: '로그아웃',
      message: '정말 로그아웃하시겠어요?',
      confirmLabel: '로그아웃',
      destructive: false,
    );
    if (ok != true) return;
    // await 이후 context 사용을 피하기 위해 미리 캡처.
    final navigator = Navigator.of(context);
    final auth = AuthScope.read(context);
    await auth.logout();
    // AuthGuard 가 루트 라우트를 로그인 화면으로 바꾸므로,
    // 위에 쌓인 계정 화면을 닫아 로그인 화면이 보이도록 한다.
    navigator.popUntil((route) => route.isFirst);
  }

  Future<void> _confirmWithdraw(BuildContext context) async {
    final ok = await _showConfirm(
      context,
      title: '회원 탈퇴',
      message: '탈퇴하면 계정과 관련 데이터가 모두 삭제되며 복구할 수 없습니다.\n계속하시겠어요?',
      confirmLabel: '탈퇴하기',
      destructive: true,
    );
    if (ok != true) return;

    // await 이후 context 사용을 피하기 위해 미리 캡처.
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final auth = AuthScope.read(context);
    final result = await auth.withdraw();
    if (!result.ok) {
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(result.message ?? '탈퇴 처리에 실패했습니다.'),
        ),
      );
      return;
    }
    // 탈퇴 성공 → 루트(로그인 화면)까지 닫는다.
    navigator.popUntil((route) => route.isFirst);
  }

  Future<bool?> _showConfirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    required bool destructive,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AuthColors.surface,
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: AuthColors.label)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소',
                style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  destructive ? AuthColors.accent : Colors.white24,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel,
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final user = auth.user;

    return Scaffold(
      backgroundColor: AuthColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('내 계정',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AuthColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 28,
                    backgroundColor: AuthColors.accent,
                    child: Icon(Icons.person, color: Colors.white, size: 30),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.nickname?.isNotEmpty == true
                              ? user!.nickname!
                              : '사용자',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user?.email ?? '-',
                          style: const TextStyle(color: AuthColors.label),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            _ActionTile(
              icon: Icons.logout,
              label: '로그아웃',
              onTap: () => _confirmLogout(context),
            ),
            const SizedBox(height: 12),
            _ActionTile(
              icon: Icons.person_remove_outlined,
              label: '회원 탈퇴',
              destructive: true,
              onTap: () => _confirmWithdraw(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AuthColors.accent : Colors.white;
    return Material(
      color: AuthColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 16),
              Text(label, style: TextStyle(color: color, fontSize: 16)),
              const Spacer(),
              const Icon(Icons.chevron_right, color: Colors.white24),
            ],
          ),
        ),
      ),
    );
  }
}
