import 'package:flutter/material.dart';

import '../../../api/backend_client.dart';
import '../../../data/admin_suggestion_repository.dart';

const _bg = Color(0xFF121212);
const _surface = Color(0xFF1E1E1E);
const _accent = Color(0xFFE61E2B);

/// 반려 사유 템플릿.
@immutable
class RejectionReason {
  const RejectionReason({required this.label, required this.template});

  /// 드롭다운에 표시될 짧은 사유명.
  final String label;

  /// 선택 시 사유 입력란을 채울 안내 템플릿 문구.
  final String template;
}

/// 관리자(개발자)가 사용할 기본 반려 사유 템플릿 목록.
const List<RejectionReason> kRejectionReasons = [
  RejectionReason(
    label: '중복된 랜드마크',
    template: '이미 지원 목록에 등록되어 있는 랜드마크입니다.',
  ),
  RejectionReason(
    label: '랜드마크 부적합',
    template: '랜드마크로 보기 어려운 장소로 판단되어 반려합니다.',
  ),
  RejectionReason(
    label: '정보 부족',
    template: '장소를 특정하기 위한 정보가 부족합니다. 정확한 이름과 위치를 보완해 다시 건의해 주세요.',
  ),
  RejectionReason(
    label: '품질 기준 미달',
    template: '제공된 정보가 등록 품질 기준에 미치지 못해 반려합니다.',
  ),
  RejectionReason(
    label: '기타 (직접 입력)',
    template: '',
  ),
];

/// 개발자 관리자 뷰: 건의 반려 처리 화면.
///
/// 반려 사유를 드롭다운으로 선택하면 해당 템플릿 문구가 입력란에 채워지고,
/// 필요 시 내용을 수정해 반려 처리한다.
class RejectionReasonScreen extends StatefulWidget {
  const RejectionReasonScreen({
    super.key,
    required this.suggestionId,
    required this.repository,
    this.suggestionTitle = '사용자 건의',
    this.reasons = kRejectionReasons,
  });

  /// 반려 처리할 건의 ID.
  final String suggestionId;

  /// 반려 API 호출에 사용할 레포지토리.
  final AdminSuggestionRepository repository;

  /// 반려 대상 건의 제목(표시용).
  final String suggestionTitle;

  /// 사용할 반려 사유 템플릿 목록.
  final List<RejectionReason> reasons;

  @override
  State<RejectionReasonScreen> createState() => _RejectionReasonScreenState();
}

class _RejectionReasonScreenState extends State<RejectionReasonScreen> {
  RejectionReason? _selected;
  final _messageController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _onSelect(RejectionReason? reason) {
    if (reason == null) return;
    setState(() {
      _selected = reason;
      // 템플릿 문구로 입력란을 채우되, 이후 자유롭게 수정 가능.
      _messageController.text = reason.template;
      _messageController.selection = TextSelection.fromPosition(
        TextPosition(offset: _messageController.text.length),
      );
    });
  }

  Future<void> _submit() async {
    final message = _messageController.text.trim();
    if (_selected == null || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('반려 사유를 선택하고 내용을 입력해 주세요.'),
        ),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);
    try {
      await widget.repository.reject(widget.suggestionId, message);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text("반려 처리되었습니다. (사유: ${_selected!.label})"),
        ),
      );
      // 목록 화면이 true 를 받아 새로고침하도록 결과값과 함께 닫는다.
      Navigator.of(context).pop(true);
    } on BackendException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(behavior: SnackBarBehavior.floating, content: Text(e.message)),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('건의 반려 처리',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.flag_outlined, color: Colors.white54),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('반려 대상',
                              style: TextStyle(
                                  color: Colors.white38, fontSize: 12)),
                          const SizedBox(height: 2),
                          Text(widget.suggestionTitle,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text('반려 사유',
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<RejectionReason>(
                    isExpanded: true,
                    value: _selected,
                    dropdownColor: _surface,
                    hint: const Text('사유를 선택하세요',
                        style: TextStyle(color: Colors.white38)),
                    icon: const Icon(Icons.keyboard_arrow_down,
                        color: Colors.white54),
                    items: [
                      for (final r in widget.reasons)
                        DropdownMenuItem<RejectionReason>(
                          value: r,
                          child: Text(r.label,
                              style: const TextStyle(color: Colors.white)),
                        ),
                    ],
                    onChanged: _onSelect,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('사용자에게 전달할 안내',
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 8),
              TextField(
                controller: _messageController,
                maxLines: 5,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: '사유를 선택하면 안내 문구가 자동으로 채워져요. 필요 시 수정하세요.',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: _surface,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _accent, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    disabledBackgroundColor: _accent.withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white),
                        )
                      : const Icon(Icons.block, color: Colors.white, size: 20),
                  label: const Text('반려 처리',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
