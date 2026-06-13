import 'package:flutter/foundation.dart';

import '../api/backend_client.dart';

/// 서버에 저장된 알림 한 건(`GET /api/notifications` 응답 항목).
@immutable
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      title: (json['title'] ?? '') as String,
      body: (json['body'] ?? '') as String,
      isRead: (json['is_read'] ?? false) == true,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        title: title,
        body: body,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt,
      );
}

/// 알림함(알림 이력) 조회/읽음 처리를 담당하는 레포지토리.
class NotificationRepository {
  NotificationRepository(this._client);

  final BackendClient _client;

  /// 내 알림 목록 조회. 서버가 최신순으로 정렬해 내려준다.
  Future<List<AppNotification>> fetchAll() async {
    final res = await _client.getJson('/api/notifications', auth: true);
    return [
      for (final item in (res as List))
        AppNotification.fromJson(item as Map<String, dynamic>),
    ];
  }

  /// 지정한 알림을 읽음 처리하고 갱신된 알림을 반환한다.
  Future<AppNotification> markRead(String id) async {
    final res =
        await _client.patchJson('/api/notifications/$id/read', {}, auth: true);
    return AppNotification.fromJson(res as Map<String, dynamic>);
  }
}
