import 'dart:typed_data';

/// 로컬 및 외부 API 간의 전환을 유연하게 하기 위한 추상 인터페이스
abstract class LocalApiClient {
  /// 통합 검색 파이프라인
  Future<Map<String, dynamic>> search(Uint8List imageBytes, {String? textQuery});
  
  /// 이미지 품질 검증 (/api/images/validation)
  Future<Map<String, dynamic>> validateImage(Uint8List imageBytes);
  
  /// 이미지 임베딩 추출 (/api/image-embeddings)
  Future<List<double>> extractImageEmbedding(Uint8List imageBytes);
  
  /// 유사도 계산 및 랭킹 조회 (/api/retrieval-results)
  Future<List<Map<String, dynamic>>> getRetrievalResults(List<double> embedding, {int topK = 3});
  
  /// 검색 신뢰도 판단 (4-way policy) (/api/search-confidence)
  Future<Map<String, dynamic>> checkSearchConfidence(List<Map<String, dynamic>> topResults, String kind);
  
  /// 랜드마크 상세 정보 조회 (/api/landmarks/{id})
  Future<Map<String, dynamic>> getLandmarkDetails(String id);
  
  /// 검색 로그 로컬 저장 (/api/search-logs)
  Future<void> logSearch(Map<String, dynamic> logData);
}
