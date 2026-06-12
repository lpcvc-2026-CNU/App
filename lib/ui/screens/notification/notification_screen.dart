import 'dart:async';

import 'package:flutter/material.dart';

import '../../../api/backend_client.dart';
import '../../../data/notification_repository.dart';
import '../../../services/push_notification_service.dart';

const _bg = Color(0xFF121212);
const _surface = Color(0xFF1E1E1E);
const _accent = Color(0xFFE61E2B);

/// 알림함: 서버에 저장된 내 알림 이력을 최신순으로 보여준다.
///
/// - 안읽은 알림은 강조 표시되며, 탭하면 읽음 처리된다.
/// - 아래로 당겨 새로고침할 수 있고, 포그라운드 푸시 수신 시 자동 갱신된다.
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key, required this.repository});

  final NotificationRepository repository;

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<AppNotification> _items = [];
  bool _loading = true;

  /// 포그라운드 푸시 수신 시 목록 자동 갱신용 구독.
  /// (mock 모드에서는 발화하지 않으므로 pull-to-refresh가 대체 수단)
  StreamSubscription<dynamic>? _messageSub;

  @override
  void initState() {
    super.initState();
    _load();
    _messageSub = PushNotificationService.instance.messageStream
        .listen((_) => _load());
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final items = await widget.repository.fetchAll();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } on BackendException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(behavior: SnackBarBehavior.floating, content: Text(e.message)),
      );
    }
  }

  Future<void> _onTap(int index) async {
    final item = _items[index];
    if (item.isRead) return;
    // 낙관적으로 즉시 읽음 표시하고, 서버 응답으로 확정한다.
    setState(() => _items[index] = item.copyWith(isRead: true));
    try {
      final updated = await widget.repository.markRead(item.id);
      if (!mounted) return;
      setState(() => _items[index] = updated);
    } on BackendException catch (e) {
      if (!mounted) return;
      setState(() => _items[index] = item);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(behavior: SnackBarBehavior.floating, content: Text(e.message)),
      );
    }
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}.${two(local.month)}.${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title:
            const Text('알림함', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: _accent),
              )
            : RefreshIndicator(
                color: _accent,
                onRefresh: _load,
                child: _items.isEmpty
                    ? ListView(
                        // 비어 있어도 당겨서 새로고침이 동작하도록 스크롤 유지.
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.6,
                            child: const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.notifications_none,
                                      color: Colors.white24, size: 56),
                                  SizedBox(height: 12),
                                  Text('알림이 없습니다',
                                      style: TextStyle(
                                          color: Colors.white38, fontSize: 15)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 16),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) =>
                            _NotificationCard(
                          item: _items[index],
                          dateText: _formatDate(_items[index].createdAt),
                          onTap: () => _onTap(index),
                        ),
                      ),
              ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.item,
    required this.dateText,
    required this.onTap,
  });

  final AppNotification item;
  final String dateText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unread = !item.isRead;
    return Material(
      color: _surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: unread ? _accent.withOpacity(0.6) : Colors.white12,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (unread)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: const BoxDecoration(
                        color: _accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  Expanded(
                    child: Text(
                      item.title,
                      style: TextStyle(
                        color: unread ? Colors.white : Colors.white54,
                        fontSize: 15,
                        fontWeight:
                            unread ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                item.body,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: unread ? Colors.white70 : Colors.white38,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                dateText,
                style: const TextStyle(color: Colors.white30, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
