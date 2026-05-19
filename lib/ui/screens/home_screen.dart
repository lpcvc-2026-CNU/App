import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../api/local_api_client.dart';
import 'result_screen.dart';
import 'text_search_screen.dart';

class HomeScreen extends StatefulWidget {
  final LocalApiClient apiClient;

  const HomeScreen({super.key, required this.apiClient});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  bool _isAnalyzing = false;
  final ImagePicker _picker = ImagePicker();
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

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
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final image = await _picker.pickImage(source: source);
      if (image == null) return;
      final bytes = await image.readAsBytes();
      await _onImageSelected(bytes);
    } catch (e) {
      _showMessage('Failed to load image: $e');
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
        'Image search could not start. ONNX model initialization likely failed. Please check the logs.',
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
      _showMessage('Text search failed: $e');
    }
  }

  void _showTextSearchDialog() {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text(
            'Search landmarks by text',
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              hintText: 'e.g. Gyeongbokgung, Myeongdong Cathedral',
              hintStyle: TextStyle(color: Colors.white38),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white38),
              ),
              focusedBorder: UnderlineInputBorder(
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
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white54),
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
              child: const Text('Search', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showQualityErrorSnackbar(List<String> reasons) {
    var message =
        'The photo was hard to analyze. Please retake it more clearly.';
    if (reasons.contains('too_dark')) {
      message = 'The photo is too dark. Please retake it in brighter light.';
    }
    if (reasons.contains('blur_detected')) {
      message = 'The photo is blurry. Please refocus and try again.';
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
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: Color(0xFFE61E2B),
              strokeWidth: 3,
            ),
            SizedBox(height: 24),
            Text(
              'Analyzing landmark...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
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
      color: gradient == null ? Colors.white.withOpacity(0.05) : null,
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
                color: gradient.first.withOpacity(0.35),
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
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: titleSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
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
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text(
          'Seoul Landmark Assistant',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
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
                  const Text(
                    'Choose how you want to search',
                    style: TextStyle(
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
                        title: 'Camera',
                        subtitle: 'Take a photo and identify a landmark',
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
                            aspectRatio: 1,
                            child: _buildActionCard(
                              title: 'Gallery',
                              subtitle: 'Open an image from your device',
                              icon: Icons.photo_library,
                              titleSize: 20,
                              onTap: () => _pickImage(ImageSource.gallery),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: _buildActionCard(
                              title: 'Text',
                              subtitle: 'Find a landmark by keyword',
                              icon: Icons.search,
                              titleSize: 20,
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
    );
  }
}
