import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../api/local_api_client.dart';
import '../../api/app_translations.dart';
import 'detail_screen.dart';

class TextSearchScreen extends StatefulWidget {
  final String initialQuery;
  final Map<String, dynamic>? initialResult;
  final LocalApiClient apiClient;

  const TextSearchScreen({
    super.key,
    required this.initialQuery,
    required this.initialResult,
    required this.apiClient,
  });

  @override
  State<TextSearchScreen> createState() => _TextSearchScreenState();
}

class _TextSearchScreenState extends State<TextSearchScreen> {
  late final TextEditingController _searchController;
  Map<String, dynamic>? _result;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery);
    _result = widget.initialResult;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    FocusScope.of(context).unfocus();
    setState(() => _isSearching = true);

    try {
      final result = await widget.apiClient.search(
        Uint8List(0),
        textQuery: trimmed,
      );
      setState(() => _result = result);
    } catch (e) {
      setState(() {
        _result = {'decision': 'out_of_scope', 'top3': []};
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            '${AppTranslations.translate('text_search_fail', widget.apiClient.languageCode)}$e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  void _openDetail(String landmarkId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetailScreen(
          landmarkId: landmarkId,
          apiClient: widget.apiClient,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.apiClient.languageCode;
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          AppTranslations.translate('text_search_title', lang),
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: AppTranslations.translate('text_search_input_hint', lang),
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(Icons.search, color: Colors.white54),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white54),
                      onPressed: _searchController.clear,
                    ),
                  ),
                  onSubmitted: _performSearch,
                ),
              ),
            ),
            Expanded(
              child: _isSearching
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFE61E2B),
                      ),
                    )
                  : _buildContent(lang),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(String lang) {
    if (_result == null) {
      return Center(
        child: Text(
          AppTranslations.translate('enter_query_prompt', lang),
          style: const TextStyle(color: Colors.white54, fontSize: 16),
        ),
      );
    }

    final decision = _result!['decision'] as String? ?? 'out_of_scope';
    if (decision == 'out_of_scope') {
      return _buildOutOfScopeState(lang);
    }

    final topList = _result!['top3'] as List<dynamic>? ?? const [];
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      children: [
        Text(
          '${AppTranslations.translate('search', lang)} (${topList.length})',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ...topList.map((item) => _buildLandmarkCard(item['landmark_id'])),
      ],
    );
  }

  Widget _buildLandmarkCard(String landmarkId) {
    return FutureBuilder<Map<String, dynamic>>(
      future: widget.apiClient.getLandmarkDetails(landmarkId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFFE61E2B)),
            ),
          );
        }

        final data = snapshot.data ?? {};
        final name = data['name'] ?? landmarkId;
        final desc = data['description'] ?? '';

        return GestureDetector(
          onTap: () => _openDetail(landmarkId),
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
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (desc.toString().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          desc.toString(),
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

  Widget _buildOutOfScopeState(String lang) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 80, color: Colors.white24),
            const SizedBox(height: 24),
            Text(
              AppTranslations.translate('no_search_result', lang),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              AppTranslations.translate('no_search_result_desc', lang),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}
