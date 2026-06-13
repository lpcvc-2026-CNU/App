import 'package:flutter/material.dart';

import '../../../api/backend_client.dart';
import '../../../data/admin_suggestion_repository.dart';
import 'rejection_reason_screen.dart';

const _bg = Color(0xFF121212);
const _surface = Color(0xFF1E1E1E);
const _accent = Color(0xFFE61E2B);

/// 관리자(개발자) 전용: 전체 건의 목록 조회 + 승인/반려 처리 화면.
class AdminSuggestionListScreen extends StatefulWidget {
  const AdminSuggestionListScreen({super.key, required this.repository});

  final AdminSuggestionRepository repository;

  @override
  State<AdminSuggestionListScreen> createState() =>
      _AdminSuggestionListScreenState();
}

class _AdminSuggestionListScreenState extends State<AdminSuggestionListScreen> {
  List<AdminSuggestion> _items = [];
  bool _loading = true;
  String? _error;

  /// 승인/반려 처리 중인 건의 ID(이중 탭 방지).
  String? _processingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await widget.repository.fetchAll();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
        _error = null;
      });
    } on BackendException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        // admin 가드는 403을 반환한다(401과 구분).
        _error = e.statusCode == 403 ? '관리자 권한이 없습니다.' : e.message;
      });
    }
  }

  Future<void> _approve(AdminSuggestion s) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _surface,
        title: const Text('건의 승인', style: TextStyle(color: Colors.white)),
        content: Text(
          "'${s.landmarkName}' 건의를 승인할까요?\n사용자에게 승인 알림이 발송됩니다.",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _accent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('승인', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _processingId = s.id);
    try {
      await widget.repository.approve(s.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text("'${s.landmarkName}' 건의를 승인했습니다."),
        ),
      );
      await _load();
    } on BackendException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(behavior: SnackBarBehavior.floating, content: Text(e.message)),
      );
    } finally {
      if (mounted) setState(() => _processingId = null);
    }
  }

  Future<void> _reject(AdminSuggestion s) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => RejectionReasonScreen(
          suggestionId: s.id,
          suggestionTitle: s.landmarkName,
          repository: widget.repository,
        ),
      ),
    );
    if (ok == true) await _load();
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}.${two(local.month)}.${two(local.day)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('건의 관리',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: _accent))
            : RefreshIndicator(
                color: _accent,
                onRefresh: _load,
                child: _buildBody(),
              ),
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null || _items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _error != null
                        ? Icons.lock_outline
                        : Icons.inbox_outlined,
                    color: Colors.white24,
                    size: 56,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _error ?? '접수된 건의가 없습니다',
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 15),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final s = _items[index];
        return _SuggestionCard(
          suggestion: s,
          dateText: _formatDate(s.createdAt),
          processing: _processingId == s.id,
          onApprove: () => _approve(s),
          onReject: () => _reject(s),
        );
      },
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.suggestion,
    required this.dateText,
    required this.processing,
    required this.onApprove,
    required this.onReject,
  });

  final AdminSuggestion suggestion;
  final String dateText;
  final bool processing;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  suggestion.landmarkName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _StatusChip(status: suggestion.status),
            ],
          ),
          if (suggestion.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              suggestion.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white60, fontSize: 13, height: 1.4),
            ),
          ],
          if (suggestion.status == 'rejected' &&
              (suggestion.rejectionReason ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '반려 사유: ${suggestion.rejectionReason}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: _accent.withOpacity(0.8), fontSize: 12, height: 1.4),
            ),
          ],
          const SizedBox(height: 10),
          Text(dateText,
              style: const TextStyle(color: Colors.white30, fontSize: 11)),
          if (suggestion.isPending) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.greenAccent),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: processing ? null : onApprove,
                    child: processing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.greenAccent),
                          )
                        : const Text('승인',
                            style: TextStyle(color: Colors.greenAccent)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _accent),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: processing ? null : onReject,
                    child: const Text('반려', style: TextStyle(color: _accent)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'approved' => ('승인됨', Colors.greenAccent),
      'rejected' => ('반려됨', _accent),
      _ => ('대기 중', Colors.amberAccent),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12)),
    );
  }
}
