import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../api/local_api_client.dart';
import '../../api/app_translations.dart';
import '../../data/suggestion_repository.dart';
import 'result_screen.dart';
import 'text_search_screen.dart';

import 'auth/account_screen.dart';
import 'suggestion/suggestion_screen.dart';

class HomeScreen extends StatefulWidget {
  final LocalApiClient apiClient;
  final SuggestionRepository suggestionRepository;

  const HomeScreen({
    super.key,
    required this.apiClient,
    required this.suggestionRepository,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  bool _isAnalyzing = false;
  final ImagePicker _picker = ImagePicker();
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  late final AnimationController _scanController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scanController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final image = await _picker.pickImage(source: source);
      if (image == null) return;
      
      // 이미지가 선택된 즉시 공백 없이 스캔 오버레이 시작
      setState(() => _isAnalyzing = true);
      
      final bytes = await image.readAsBytes();
      await _onImageSelected(bytes);
    } catch (e) {
      setState(() => _isAnalyzing = false);
      _showMessage('${AppTranslations.translate('camera_fail', widget.apiClient.languageCode)}$e');
    }
  }

  Future<void> _onImageSelected(Uint8List imageBytes) async {
    setState(() => _isAnalyzing = true);

    try {
      final result = await widget.apiClient.search(imageBytes);
      result['image_bytes'] = imageBytes;

      if (!mounted) return;
      setState(() => _isAnalyzing = false);

      if (result['decision'] == 'low_quality') {
        _showQualityErrorSnackbar(result['reason_codes'] as List<String>? ?? []);
        return;
      }

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              ResultScreen(result: result, apiClient: widget.apiClient),
        ),
      );
    } catch (e, stackTrace) {
      print('Image search failed: $e');
      print(stackTrace);
      if (!mounted) return;
      setState(() => _isAnalyzing = false);
      _showMessage(
        AppTranslations.translate('search_init_fail', widget.apiClient.languageCode),
      );
    }
  }

  Future<void> _onTextSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    setState(() => _isAnalyzing = true);
    try {
      final result = await widget.apiClient.search(
        Uint8List(0),
        textQuery: trimmed,
      );
      if (!mounted) return;
      setState(() => _isAnalyzing = false);
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TextSearchScreen(
            initialQuery: trimmed,
            initialResult: result,
            apiClient: widget.apiClient,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isAnalyzing = false);
      _showMessage('${AppTranslations.translate('text_search_fail', widget.apiClient.languageCode)}$e');
    }
  }

  void _showTextSearchDialog() {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: Text(
            AppTranslations.translate('text_search_dialog_title', widget.apiClient.languageCode),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: AppTranslations.translate('text_search_hint', widget.apiClient.languageCode),
              hintStyle: const TextStyle(color: Colors.white38),
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white38),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFFE61E2B)),
              ),
            ),
            onSubmitted: (value) {
              Navigator.pop(context);
              _onTextSearch(value);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                AppTranslations.translate('cancel', widget.apiClient.languageCode),
                style: const TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE61E2B),
              ),
              onPressed: () {
                Navigator.pop(context);
                _onTextSearch(controller.text);
              },
              child: Text(
                AppTranslations.translate('search', widget.apiClient.languageCode),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showQualityErrorSnackbar(List<String> reasons) {
    var message =
        AppTranslations.translate('quality_error_general', widget.apiClient.languageCode);
    if (reasons.contains('too_dark')) {
      message = AppTranslations.translate('quality_error_dark', widget.apiClient.languageCode);
    }
    if (reasons.contains('blur_detected')) {
      message = AppTranslations.translate('quality_error_blur', widget.apiClient.languageCode);
    }
    _showMessage(message);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 4),
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildScanningOverlay() {
    return AnimatedBuilder(
      animation: _scanController,
      builder: (context, child) {
        return Container(
          color: Colors.black.withValues(alpha: 0.85),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFFE61E2B).withValues(alpha: 0.7),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    color: Colors.white.withValues(alpha: 0.03),
                  ),
                  child: Stack(
                    clipBehavior: Clip.antiAlias,
                    children: [
                      // 위아래로 움직이는 스캔 레이저 라인
                      Positioned(
                        top: 256 * _scanController.value,
                        left: 12,
                        right: 12,
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE61E2B),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFE61E2B).withValues(alpha: 0.8),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ),
                      // 네 모퉁이에 고급 포커스 브래킷 디자인 추가
                      _buildCornerBracket(top: true, left: true),
                      _buildCornerBracket(top: true, left: false),
                      _buildCornerBracket(top: false, left: true),
                      _buildCornerBracket(top: false, left: false),
                    ],
                  ),
                ),
                const SizedBox(height: 36),
                Text(
                  AppTranslations.translate('analyzing', widget.apiClient.languageCode),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppTranslations.translate('please_wait', widget.apiClient.languageCode),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCornerBracket({required bool top, required bool left}) {
    return Positioned(
      top: top ? 12 : null,
      bottom: top ? null : 12,
      left: left ? 12 : null,
      right: left ? null : 12,
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          border: Border(
            top: top ? const BorderSide(color: Color(0xFFE61E2B), width: 3) : BorderSide.none,
            bottom: top ? BorderSide.none : const BorderSide(color: Color(0xFFE61E2B), width: 3),
            left: left ? const BorderSide(color: Color(0xFFE61E2B), width: 3) : BorderSide.none,
            right: left ? BorderSide.none : const BorderSide(color: Color(0xFFE61E2B), width: 3),
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    List<Color>? gradient,
    double titleSize = 22,
  }) {
    final decoration = BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      color: gradient == null ? Colors.white.withValues(alpha: 0.05) : null,
      gradient: gradient == null
          ? null
          : LinearGradient(
               colors: gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
      border: gradient == null ? Border.all(color: Colors.white12) : null,
      boxShadow: gradient == null
          ? null
          : [
              BoxShadow(
                color: gradient.first.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
    );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: decoration,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    maxLines: 1,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: titleSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final clampedTextScaler = mediaQuery.textScaler.clamp(
      minScaleFactor: 0.85,
      maxScaleFactor: 1.15,
    );

    return MediaQuery(
      data: mediaQuery.copyWith(textScaler: clampedTextScaler),
      child: Scaffold(
        backgroundColor: const Color(0xFF121212),
        appBar: AppBar(
          title: Text(
            AppTranslations.translate('app_title', widget.apiClient.languageCode),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.language, color: Colors.white),
              tooltip: AppTranslations.translate('language_select', widget.apiClient.languageCode),
              onSelected: (String code) {
                setState(() {
                  widget.apiClient.languageCode = code;
                });
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'ko',
                  child: Text('한국어'),
                ),
                const PopupMenuItem<String>(
                  value: 'en',
                  child: Text('English'),
                ),
                const PopupMenuItem<String>(
                  value: 'zh',
                  child: Text('简体中文'),
                ),
                const PopupMenuItem<String>(
                  value: 'ja',
                  child: Text('日本語'),
                ),
              ],
            ),
            IconButton(
              tooltip: '랜드마크 건의',
              icon: const Icon(Icons.add_location_alt_outlined, color: Colors.white),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SuggestionScreen(
                    repository: widget.suggestionRepository,
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: '내 계정',
              icon: const Icon(Icons.account_circle_outlined, color: Colors.white),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AccountScreen()),
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    Text(
                      AppTranslations.translate('select_search_method', widget.apiClient.languageCode),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 32),
                    ScaleTransition(
                      scale: _pulseAnimation,
                      child: SizedBox(
                        height: 190,
                        width: double.infinity,
                        child: _buildActionCard(
                          title: AppTranslations.translate('camera_shot', widget.apiClient.languageCode),
                          subtitle: AppTranslations.translate('camera_shot_desc', widget.apiClient.languageCode),
                          icon: Icons.camera_alt,
                          onTap: () => _pickImage(ImageSource.camera),
                          gradient: const [Color(0xFFE61E2B), Color(0xFF8A0038)],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: AspectRatio(
                              aspectRatio: 0.85,
                              child: _buildActionCard(
                                title: AppTranslations.translate('gallery_load', widget.apiClient.languageCode),
                                subtitle: AppTranslations.translate('gallery_load_desc', widget.apiClient.languageCode),
                                icon: Icons.photo_library,
                                titleSize: 18,
                                onTap: () => _pickImage(ImageSource.gallery),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: AspectRatio(
                              aspectRatio: 0.85,
                              child: _buildActionCard(
                                title: AppTranslations.translate('keyword_search', widget.apiClient.languageCode),
                                subtitle: AppTranslations.translate('keyword_search_desc', widget.apiClient.languageCode),
                                icon: Icons.search,
                                titleSize: 18,
                                onTap: _showTextSearchDialog,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_isAnalyzing) _buildScanningOverlay(),
          ],
        ),
      ),
    );
  }
}
