import 'dart:convert';

import 'package:http/http.dart' as http;

import '../auth/token_storage.dart';
import 'backend_config.dart';

/// 백엔드 요청 실패를 표현하는 예외.
///
/// FastAPI는 오류 본문을 `{"detail": "..."}` 형태로 내려주므로,
/// 해당 메시지를 [message] 로 보존해 화면에서 그대로 노출할 수 있다.
class BackendException implements Exception {
  BackendException(this.statusCode, this.message);

  /// HTTP 상태 코드(네트워크 자체 실패 시 null).
  final int? statusCode;

  /// 사용자에게 보여줄 수 있는 오류 메시지(서버 detail 우선).
  final String message;

  /// 중복 건의 등 잘못된 요청(400).
  bool get isDuplicate => statusCode == 400;

  /// 인증 만료/누락(401).
  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => 'BackendException($statusCode): $message';
}

/// FastAPI 백엔드와 통신하는 공통 HTTP 클라이언트.
///
/// - 저장된 액세스 토큰을 읽어 `Authorization: Bearer` 헤더를 자동 첨부한다.
/// - 한글 응답을 위해 UTF-8 디코딩한다.
/// - 2xx 외 응답은 [BackendException] 으로 변환해 던진다.
class BackendClient {
  BackendClient({
    required TokenStorage tokenStorage,
    http.Client? httpClient,
  })  : _tokenStorage = tokenStorage,
        _http = httpClient ?? http.Client();

  final TokenStorage _tokenStorage;
  final http.Client _http;

  Uri _uri(String path) => Uri.parse('${BackendConfig.baseUrl}$path');

  Future<Map<String, String>> _headers({bool auth = false}) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (auth) {
      final token = await _tokenStorage.readAccessToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  /// GET 요청 후 디코딩된 JSON 반환.
  Future<dynamic> getJson(String path, {bool auth = false}) async {
    try {
      final res =
          await _http.get(_uri(path), headers: await _headers(auth: auth));
      return _decode(res);
    } on BackendException {
      rethrow;
    } catch (e) {
      throw BackendException(null, '서버에 연결하지 못했습니다. ($e)');
    }
  }

  /// POST 요청 후 디코딩된 JSON 반환.
  Future<dynamic> postJson(
    String path,
    Map<String, dynamic> body, {
    bool auth = false,
  }) async {
    try {
      final res = await _http.post(
        _uri(path),
        headers: await _headers(auth: auth),
        body: jsonEncode(body),
      );
      return _decode(res);
    } on BackendException {
      rethrow;
    } catch (e) {
      throw BackendException(null, '서버에 연결하지 못했습니다. ($e)');
    }
  }

  /// PATCH 요청 후 디코딩된 JSON 반환.
  Future<dynamic> patchJson(
    String path,
    Map<String, dynamic> body, {
    bool auth = false,
  }) async {
    try {
      final res = await _http.patch(
        _uri(path),
        headers: await _headers(auth: auth),
        body: jsonEncode(body),
      );
      return _decode(res);
    } on BackendException {
      rethrow;
    } catch (e) {
      throw BackendException(null, '서버에 연결하지 못했습니다. ($e)');
    }
  }

  /// DELETE 요청 후 디코딩된 JSON 반환.
  Future<dynamic> deleteJson(String path, {bool auth = false}) async {
    try {
      final res =
          await _http.delete(_uri(path), headers: await _headers(auth: auth));
      return _decode(res);
    } on BackendException {
      rethrow;
    } catch (e) {
      throw BackendException(null, '서버에 연결하지 못했습니다. ($e)');
    }
  }

  dynamic _decode(http.Response res) {
    final dynamic decoded =
        res.bodyBytes.isEmpty ? null : jsonDecode(utf8.decode(res.bodyBytes));

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return decoded;
    }

    // FastAPI 오류 본문: {"detail": "..."} (detail이 리스트인 검증오류도 방어).
    String message = '요청을 처리하지 못했습니다.';
    if (decoded is Map && decoded['detail'] != null) {
      final detail = decoded['detail'];
      message = detail is List ? detail.join(', ') : detail.toString();
    }
    throw BackendException(res.statusCode, message);
  }

  void close() => _http.close();
}
