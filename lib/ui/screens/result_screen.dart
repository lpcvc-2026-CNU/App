import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../api/local_api_client.dart';
import 'detail_screen.dart';

class ResultScreen extends StatefulWidget {
  final Map<String, dynamic> result;
  final LocalApiClient? apiClient;

  const ResultScreen({super.key, required this.result, this.apiClient});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isAnalyzing = false;

  Future<void> _pickAndAnalyze(ImageSource source) async {
    final apiClient = widget.apiClient;
    if (apiClient == null) {
      Navigator.pop(context);
      return;
    }

    try {
      final image = await _picker.pickImage(source: source);
      if (image == null) return;

      final bytes = await image.readAsBytes();
      setState(() => _isAnalyzing = true);

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
        SnackBar(content: Text('Image search failed: $e')),
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

    return Scaffold(
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
                Expanded(child: _buildDecisionContent(decision)),
              ],
            ),
          ),
          if (_isAnalyzing)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Color(0xFFE61E2B)),
                    SizedBox(height: 16),
                    Text(
                      'Analyzing landmark...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDecisionContent(String decision) {
    switch (decision) {
      case 'matched':
        return _buildCandidateList(
          title: 'Best match',
          subtitle: 'Tap a candidate to open the landmark detail page.',
          candidates: (widget.result['top3'] as List<dynamic>? ?? const []).take(1).toList(),
        );
      case 'ambiguous':
        return _buildCandidateList(
          title: 'Top candidates',
          subtitle: 'The result is ambiguous. Try another angle or inspect the candidates below.',
          candidates: (widget.result['top3'] as List<dynamic>? ?? const []).take(3).toList(),
        );
      case 'low_quality':
      case 'out_of_scope':
      default:
        return _buildOutOfScopeState();
    }
  }

  Widget _buildCandidateList({
    required String title,
    required String subtitle,
    required List<dynamic> candidates,
  }) {
    if (candidates.isEmpty) {
      return _buildOutOfScopeState();
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
    final landmarkId = candidate['landmark_id'].toString();
    final percentage = (candidate['percentage'] as num?)?.toInt() ?? 0;

    return FutureBuilder<Map<String, dynamic>>(
      future: widget.apiClient?.getLandmarkDetails(landmarkId),
      builder: (context, snapshot) {
        final data = snapshot.data ?? {};
        final name = (data['name_ko'] ?? data['name_en'] ?? landmarkId).toString();
        final desc = (data['description_ko'] ??
                data['description_en'] ??
                'Description is not available yet.')
            .toString();

        return GestureDetector(
          onTap: widget.apiClient == null ? null : () => _openDetail(landmarkId),
          child: Container(
            margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
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
                        child: Image.asset(
                          'assets/hero_images/$landmarkId.jpg',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: Colors.grey[850],
                            child: const Center(
                              child: Icon(
                                Icons.image_outlined,
                                size: 50,
                                color: Colors.white30,
                              ),
                            ),
                          ),
                        ),
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
                          color: Colors.black.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '$percentage%',
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
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOutOfScopeState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_off, size: 80, color: Colors.white24),
            const SizedBox(height: 24),
            const Text(
              'No matching landmark was found.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Try taking a clearer photo with the landmark more centered.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 15),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _pickAndAnalyze(ImageSource.camera),
                icon: const Icon(Icons.camera_alt, color: Colors.white),
                label: const Text(
                  'Retake Photo',
                  style: TextStyle(color: Colors.white),
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
                label: const Text(
                  'Choose Another Image',
                  style: TextStyle(color: Colors.white),
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
