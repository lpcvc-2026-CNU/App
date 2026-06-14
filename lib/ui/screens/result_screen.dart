import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../api/local_api_client.dart';
import '../../api/app_translations.dart';
import 'detail_screen.dart';

class ResultScreen extends StatefulWidget {
  final Map<String, dynamic> result;
  final LocalApiClient? apiClient;

  const ResultScreen({super.key, required this.result, this.apiClient});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  bool _isAnalyzing = false;
  late final AnimationController _scanController;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scanController.dispose();
    super.dispose();
  }

  Future<void> _pickAndAnalyze(ImageSource source) async {
    final apiClient = widget.apiClient;
    if (apiClient == null) {
      Navigator.pop(context);
      return;
    }

    try {
      final image = await _picker.pickImage(source: source);
      if (image == null) return;

      // 이미지가 픽된 즉시 공백을 지우기 위해 오버레이 시작
      setState(() => _isAnalyzing = true);

      final bytes = await image.readAsBytes();
      final newResult = await apiClient.search(bytes);
      newResult['image_bytes'] = bytes;

      if (!mounted) return;
      setState(() => _isAnalyzing = false);

      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) =>
              ResultScreen(result: newResult, apiClient: apiClient),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isAnalyzing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppTranslations.translate('search_fail', apiClient.languageCode)}$e',
          ),
        ),
      );
    }
  }

  void _openDetail(String landmarkId) {
    final apiClient = widget.apiClient;
    if (apiClient == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetailScreen(
          landmarkId: landmarkId,
          apiClient: apiClient,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final decision = widget.result['decision'] as String? ?? 'out_of_scope';
    final mediaQuery = MediaQuery.of(context);
    final clampedTextScaler = mediaQuery.textScaler.clamp(
      minScaleFactor: 0.85,
      maxScaleFactor: 1.15,
    );
    final lang = widget.apiClient?.languageCode ?? 'ko';

    return MediaQuery(
      data: mediaQuery.copyWith(textScaler: clampedTextScaler),
      child: Scaffold(
        backgroundColor: const Color(0xFF121212),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  Container(
                    height: 220,
                    width: double.infinity,
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[850],
                      borderRadius: BorderRadius.circular(16),
                      image: widget.result['image_bytes'] != null &&
                              (widget.result['image_bytes'] as Uint8List).isNotEmpty
                          ? DecorationImage(
                              image: MemoryImage(widget.result['image_bytes']),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: (widget.result['image_bytes'] == null ||
                            (widget.result['image_bytes'] as Uint8List).isEmpty)
                        ? const Center(
                            child: Icon(
                              Icons.image_outlined,
                              size: 54,
                              color: Colors.white38,
                            ),
                          )
                        : null,
                  ),
                  Expanded(child: _buildDecisionContent(decision, lang)),
                ],
              ),
            ),
            if (_isAnalyzing) _buildScanningOverlay(lang),
          ],
        ),
      ),
    );
  }

  Widget _buildScanningOverlay(String lang) {
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
                      _buildCornerBracket(top: true, left: true),
                      _buildCornerBracket(top: true, left: false),
                      _buildCornerBracket(top: false, left: true),
                      _buildCornerBracket(top: false, left: false),
                    ],
                  ),
                ),
                const SizedBox(height: 36),
                Text(
                  AppTranslations.translate('analyzing', lang),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppTranslations.translate('please_wait', lang),
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

  Widget _buildDecisionContent(String decision, String lang) {
    switch (decision) {
      case 'matched':
        return _buildCandidateList(
          title: AppTranslations.translate('strong_candidate', lang),
          subtitle: AppTranslations.translate('strong_candidate_desc', lang),
          candidates: (widget.result['top3'] as List<dynamic>? ?? const []).take(1).toList(),
          lang: lang,
        );
      case 'ambiguous':
        return _buildCandidateList(
          title: AppTranslations.translate('ambiguous_candidate', lang),
          subtitle: AppTranslations.translate('ambiguous_candidate_desc', lang),
          candidates: (widget.result['top3'] as List<dynamic>? ?? const []).take(3).toList(),
          lang: lang,
        );
      case 'low_quality':
      case 'out_of_scope':
      default:
        return _buildOutOfScopeState(lang);
    }
  }

  Widget _buildCandidateList({
    required String title,
    required String subtitle,
    required List<dynamic> candidates,
    required String lang,
  }) {
    if (candidates.isEmpty) {
      return _buildOutOfScopeState(lang);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 18),
        ...candidates.map((candidate) => _buildLandmarkCard(candidate)),
      ],
    );
  }

  Widget _buildLandmarkCard(Map<String, dynamic> candidate) {
    final lang = widget.apiClient?.languageCode ?? 'ko';
    final landmarkId = candidate['landmark_id'].toString();
    final displayScore = (candidate['display_score'] as num?)?.toInt() ?? 
                         ((candidate['keyword_score'] as num?) != null ? ((candidate['keyword_score'] as num) * 100).toInt() : 0);

    return FutureBuilder<Map<String, dynamic>>(
      future: widget.apiClient?.getLandmarkDetails(landmarkId),
      builder: (context, snapshot) {
        final data = snapshot.data ?? {};
        // API 레벨에서 바인딩된 name 및 description 공통 다국어 프로퍼티 사용
        final rawName = (data['name'] ?? landmarkId).toString();
        final parentName = data['parent_name'] as String?;
        final parentId = data['parent_landmark_id'] as String?;
        final name = (parentName != null && parentName.isNotEmpty)
            ? '$parentName · $rawName'
            : rawName;
        final desc = data['description']?.toString();

        return GestureDetector(
          onTap: widget.apiClient == null ? null : () => _openDetail(landmarkId),
          child: Container(
            margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                      child: AspectRatio(
                        aspectRatio: 16 / 10,
                        child: _buildHeroImage(landmarkId, parentId),
                      ),
                    ),
                    Positioned(
                      top: 14,
                      right: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${AppTranslations.translate('similarity', lang)} $displayScore',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (desc != null && desc.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          desc,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeroImage(String landmarkId, String? parentId) {
    return Image.asset(
      'assets/hero_images/$landmarkId.jpg',
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        if (parentId != null && parentId.isNotEmpty && parentId != landmarkId) {
          return Image.asset(
            'assets/hero_images/$parentId.jpg',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                _buildHeroPlaceholder(50),
          );
        }
        return _buildHeroPlaceholder(50);
      },
    );
  }

  Widget _buildHeroPlaceholder(double iconSize) {
    return Container(
      color: Colors.grey[850],
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: iconSize,
          color: Colors.white30,
        ),
      ),
    );
  }

  Widget _buildOutOfScopeState(String lang) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_off, size: 80, color: Colors.white24),
            const SizedBox(height: 24),
            Text(
              AppTranslations.translate('no_match', lang),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              AppTranslations.translate('no_match_desc', lang),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 15),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _pickAndAnalyze(ImageSource.camera),
                icon: const Icon(Icons.camera_alt, color: Colors.white),
                label: Text(
                  AppTranslations.translate('shoot_again', lang),
                  style: const TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE61E2B),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _pickAndAnalyze(ImageSource.gallery),
                icon: const Icon(Icons.photo_library, color: Colors.white),
                label: Text(
                  AppTranslations.translate('select_other_photo', lang),
                  style: const TextStyle(color: Colors.white),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white54),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
