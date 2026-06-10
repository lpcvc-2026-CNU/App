import 'dart:async';

import 'package:flutter/material.dart';

import '../../../api/backend_client.dart';
import '../../../data/suggestion_repository.dart';

/// 사용자 랜드마크 건의 입력 페이지.
///
/// 입력값이 기존 지원 리스트에 존재하면 즉각적으로 안내 메시지와 팝업을 띄워
/// 중복 건의를 차단한다.
class SuggestionScreen extends StatefulWidget {
  SuggestionScreen({super.key, SuggestionRepository? repository})
      : repository = repository ?? MockSuggestionRepository();

  final SuggestionRepository repository;

  @override
  State<SuggestionScreen> createState() => _SuggestionScreenState();
}

const _bg = Color(0xFF121212);
const _surface = Color(0xFF1E1E1E);
const _accent = Color(0xFFE61E2B);

class _SuggestionScreenState extends State<SuggestionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _reasonController = TextEditingController();

  Timer? _debounce;

  /// 중복으로 감지된 기존 항목명(없으면 null).
  String? _duplicateOf;
  bool _checking = false;

  /// 같은 중복에 대해 팝업을 반복해서 띄우지 않도록 마지막으로 팝업을 띄운 값 기억.
  String? _lastPoppedFor;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onNameChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    _locationController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _onNameChanged() {
    _debounce?.cancel();
    final value = _nameController.text;
    if (value.trim().isEmpty) {
      setState(() {
        _duplicateOf = null;
        _checking = false;
        _lastPoppedFor = null;
      });
      return;
    }
    setState(() => _checking = true);
    // 입력이 멈춘 직후(약 400ms) 즉각적으로 중복 검사.
    _debounce =
        Timer(const Duration(milliseconds: 400), () => _checkDuplicate(value));
  }

  Future<void> _checkDuplicate(String value) async {
    final match = await widget.repository.findExisting(value);
    if (!mounted) return;
    setState(() {
      _duplicateOf = match;
      _checking = false;
    });
    // 새롭게 중복이 감지되면 즉시 차단 팝업 노출.
    if (match != null && _lastPoppedFor != match) {
      _lastPoppedFor = match;
      _showDuplicatePopup(match);
    }
  }

  Future<void> _showDuplicatePopup(String existingName) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _surface,
        icon: const Icon(Icons.error_outline, color: _accent, size: 36),
        title: const Text('이미 등록된 랜드마크예요',
            style: TextStyle(color: Colors.white)),
        content: Text(
          "'$existingName'은(는) 이미 지원 목록에 있어 건의할 수 없어요.\n다른 랜드마크를 입력해 주세요.",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _accent),
            onPressed: () => Navigator.pop(context),
            child: const Text('확인', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    // 제출 직전 최종 중복 검사(차단).
    final match = await widget.repository.findExisting(_nameController.text);
    if (!mounted) return;
    if (match != null) {
      setState(() => _duplicateOf = match);
      await _showDuplicatePopup(match);
      return;
    }

    setState(() => _submitting = true);
    try {
      // 위치(선택)와 추천 이유(선택)를 합쳐 description으로 전송.
      final location = _locationController.text.trim();
      final reason = _reasonController.text.trim();
      final description = [
        if (location.isNotEmpty) '위치: $location',
        if (reason.isNotEmpty) reason,
      ].join('\n');

      await widget.repository.submit(
        landmarkName: _nameController.text.trim(),
        description: description,
      );
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('건의가 접수되었어요. 검토 후 알림으로 안내해 드릴게요.'),
        ),
      );
      Navigator.of(context).maybePop();
    } on BackendException catch (e) {
      if (!mounted) return;
      if (e.isDuplicate) {
        // 서버 측 중복 판정 → 기존 팝업 UX 재활용.
        setState(() => _duplicateOf = _nameController.text.trim());
        await _showDuplicatePopup(_nameController.text.trim());
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(e.message),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasDuplicate = _duplicateOf != null;
    final blocked = hasDuplicate || _submitting;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('랜드마크 건의',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                const Text(
                  '추가되었으면 하는 랜드마크를 알려주세요',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                _Field(
                  controller: _nameController,
                  label: '랜드마크 이름',
                  hint: '예: 서울식물원',
                  suffix: _checking
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white38),
                          ),
                        )
                      : hasDuplicate
                          ? const Icon(Icons.error_outline, color: _accent)
                          : _nameController.text.trim().isNotEmpty
                              ? const Icon(Icons.check_circle_outline,
                                  color: Colors.greenAccent)
                              : null,
                  borderColor: hasDuplicate ? _accent : null,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? '랜드마크 이름을 입력해 주세요.'
                      : null,
                ),
                if (hasDuplicate) _DuplicateBanner(name: _duplicateOf!),
                const SizedBox(height: 16),
                _Field(
                  controller: _locationController,
                  label: '위치 (선택)',
                  hint: '예: 서울 강서구 마곡동',
                ),
                const SizedBox(height: 16),
                _Field(
                  controller: _reasonController,
                  label: '추천 이유 (선택)',
                  hint: '이 랜드마크를 추천하는 이유를 적어주세요',
                  maxLines: 4,
                ),
                const SizedBox(height: 28),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accent,
                      disabledBackgroundColor: _accent.withOpacity(0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: blocked ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white),
                          )
                        : Text(
                            hasDuplicate ? '이미 등록된 랜드마크예요' : '건의하기',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DuplicateBanner extends StatelessWidget {
  const _DuplicateBanner({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _accent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _accent.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: _accent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "'$name'은(는) 이미 지원되는 랜드마크예요.",
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.hint,
    this.suffix,
    this.borderColor,
    this.validator,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final Widget? suffix;
  final Color? borderColor;
  final String? Function(String?)? validator;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final base = borderColor ?? Colors.white12;
    return TextFormField(
      controller: controller,
      validator: validator,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Colors.white70),
        hintStyle: const TextStyle(color: Colors.white38),
        suffixIcon: suffix,
        filled: true,
        fillColor: _surface,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: base),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor ?? _accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.orangeAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.orangeAccent, width: 1.5),
        ),
      ),
    );
  }
}
