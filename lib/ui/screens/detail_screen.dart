import 'package:flutter/material.dart';

import '../../api/local_api_client.dart';
import '../../api/app_translations.dart';

class DetailScreen extends StatelessWidget {
  final String landmarkId;
  final LocalApiClient apiClient;

  const DetailScreen({
    super.key,
    required this.landmarkId,
    required this.apiClient,
  });

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
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: apiClient.getLandmarkDetails(landmarkId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFE61E2B)),
            );
          }

          final data = snapshot.data ?? {};
          final name = (data['name'] ?? landmarkId).toString();
          final district = (data['district'] ?? 'District').toString();

          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
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
                            size: 56,
                            color: Colors.white30,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  district,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 24),
                if (data['description'] != null && data['description'].toString().isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppTranslations.translate('landmark_overview', apiClient.languageCode),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          data['description'].toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  /*이곳에 랜드마크에 대한 개요를 기재해주세요*/
                  _buildPlaceholderSection(
                    title: AppTranslations.translate('landmark_overview', apiClient.languageCode),
                    hint: '간단한 소개와 핵심 설명을 넣는 영역',
                    comment: '/*이곳에 랜드마크에 대한 개요를 기재해주세요*/',
                  ),
                /*이곳에 랜드마크에 대한 역사 정보를 기재해주세요*/
                _buildPlaceholderSection(
                  title: '역사와 유래',
                  hint: '유래, 시대적 배경, 주요 사건을 넣는 영역',
                  comment: '/*이곳에 랜드마크에 대한 역사 정보를 기재해주세요*/',
                ),
                /*이곳에 랜드마크에 대한 건축 특징과 주요 포인트를 기재해주세요*/
                _buildPlaceholderSection(
                  title: '건축적 특징 및 주요 볼거리',
                  hint: '건축 특징, 관람 포인트, 대표 요소를 넣는 영역',
                  comment:
                      '/*이곳에 랜드마크에 대한 건축 특징과 주요 포인트를 기재해주세요*/',
                ),
                /*이곳에 랜드마크 방문 팁을 기재해주세요*/
                _buildPlaceholderSection(
                  title: '관람 팁 및 추천 포인트',
                  hint: '추천 동선, 촬영 포인트, 방문 팁을 넣는 영역',
                  comment: '/*이곳에 랜드마크 방문 팁을 기재해주세요*/',
                ),
                /*이곳에 랜드마크의 위치 및 접근 방법을 기재해주세요*/
                _buildPlaceholderSection(
                  title: '위치 및 찾아가는 길',
                  hint: '교통, 주변 지역, 접근 방법을 넣는 영역',
                  comment:
                      '/*이곳에 랜드마크의 위치 및 접근 방법을 기재해주세요*/',
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

  Widget _buildPlaceholderSection({
    required String title,
    required String hint,
    required String comment,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            hint,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            comment,
            style: const TextStyle(
              color: Colors.white30,
              fontSize: 13,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            height: 96,
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white10),
            ),
          ),
        ],
      ),
    );
  }
}
