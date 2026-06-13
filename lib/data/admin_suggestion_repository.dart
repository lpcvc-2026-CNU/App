import 'package:flutter/foundation.dart';

import '../api/backend_client.dart';

/// 관리자 화면에서 다루는 건의 한 건(`GET /api/suggestions` 응답 항목).
@immutable
class AdminSuggestion {
  const AdminSuggestion({
    required this.id,
    required this.landmarkName,
    required this.description,
    required this.status,
    this.rejectionReason,
    required this.createdAt,
  });

  final String id;
  final String landmarkName;
  final String description;

  /// 'pending' | 'approved' | 'rejected'
  final String status;
  final String? rejectionReason;
  final DateTime createdAt;

  bool get isPending => status == 'pending';

  factory AdminSuggestion.fromJson(Map<String, dynamic> json) {
    return AdminSuggestion(
      id: json['id'] as String,
      landmarkName: (json['landmark_name'] ?? '') as String,
      description: (json['description'] ?? '') as String,
      status: (json['status'] ?? 'pending') as String,
      rejectionReason: json['rejection_reason'] as String?,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

/// 관리자용 건의 조회/승인/반려 레포지토리.
///
/// 모든 엔드포인트가 admin 전용이라 비관리자는 403([BackendException])을 받는다.
class AdminSuggestionRepository {
  AdminSuggestionRepository(this._client);

  final BackendClient _client;

  /// 전체 건의 목록 조회(최신순).
  Future<List<AdminSuggestion>> fetchAll() async {
    final res = await _client.getJson('/api/suggestions', auth: true);
    return [
      for (final item in (res as List))
        AdminSuggestion.fromJson(item as Map<String, dynamic>),
    ];
  }

  /// 건의 승인. 서버가 알림 저장 + 푸시 발송까지 트리거한다.
  Future<void> approve(String id) async {
    await _client.patchJson(
      '/api/suggestions/$id/status',
      {'status': 'approved'},
      auth: true,
    );
  }

  /// 건의 반려. [reason] 은 반려 사유로 사용자 알림 본문에 포함된다.
  Future<void> reject(String id, String reason) async {
    await _client.patchJson(
      '/api/suggestions/$id/status',
      {'status': 'rejected', 'rejection_reason': reason},
      auth: true,
    );
  }
}
