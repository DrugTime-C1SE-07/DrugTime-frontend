import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_exception.dart';

typedef AuthTokenProvider = Future<String?> Function();

/// Gọi khi API trả 401: phiên không còn hiệu lực, app đưa người dùng về màn Đăng nhập.
typedef UnauthorizedHandler = Future<void> Function();

class ApiClient {
  ApiClient({
    required Uri baseUrl,
    http.Client? httpClient,
    AuthTokenProvider? authTokenProvider,
    UnauthorizedHandler? onUnauthorized,
    this.timeout = const Duration(seconds: 20),
  })  : _baseUrl = baseUrl,
        _httpClient = httpClient ?? http.Client(),
        _authTokenProvider = authTokenProvider,
        _onUnauthorized = onUnauthorized;

  final Uri _baseUrl;
  final http.Client _httpClient;
  final AuthTokenProvider? _authTokenProvider;
  final UnauthorizedHandler? _onUnauthorized;
  final Duration timeout;

  Future<Object?> getJson(String path, {Map<String, String>? query}) =>
      _send('GET', path, query: query);

  Future<Object?> postJson(String path, {required Object? body}) =>
      _send('POST', path, body: body, hasBody: true);

  /// POST không có body và không có `Content-Type`, cho thao tác mà server từ chối mọi body
  /// (kể cả `null` hay `{}`), ví dụ từ chối hoặc hủy liên kết người thân.
  Future<Object?> post(String path) => _send('POST', path);

  Future<Object?> patchJson(String path, {required Object? body}) =>
      _send('PATCH', path, body: body, hasBody: true);

  Future<Object?> putJson(String path, {required Object? body}) =>
      _send('PUT', path, body: body, hasBody: true);

  /// Trả `null` với 204 (không có body).
  Future<Object?> delete(String path) => _send('DELETE', path);

  /// Trả body JSON đã giải mã, hoặc `null` khi body rỗng (ví dụ 204).
  Future<Object?> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    bool hasBody = false,
  }) async {
    var uri = _baseUrl.resolve(path);
    if (query != null && query.isNotEmpty) {
      uri = uri.replace(queryParameters: {...uri.queryParameters, ...query});
    }

    final request = http.Request(method, uri);
    try {
      final token = await _authTokenProvider?.call();
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      if (hasBody) {
        request.headers['Content-Type'] = 'application/json';
        request.body = jsonEncode(body);
      }
      final response = await http.Response.fromStream(
        await _httpClient.send(request).timeout(timeout),
      ).timeout(timeout);

      if (response.statusCode == 401) {
        await _onUnauthorized?.call();
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          response.body.isEmpty ? 'Request failed' : response.body,
          statusCode: response.statusCode,
          isTransient: response.statusCode == 408 ||
              response.statusCode == 429 ||
              response.statusCode >= 500,
          retryAfter: _retryAfter(response.headers['retry-after']),
        );
      }
      if (response.bodyBytes.isEmpty) return null;
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on ApiException {
      rethrow;
    } on TimeoutException catch (error) {
      throw ApiException(error.message ?? 'Request timed out',
          isTransient: true);
    } on http.ClientException catch (error) {
      throw ApiException(error.message, isTransient: true);
    }
  }

  /// Chỉ nhận dạng số giây nguyên dương; dạng ngày giờ HTTP bị bỏ qua.
  static Duration? _retryAfter(String? header) {
    final seconds = int.tryParse(header?.trim() ?? '');
    return seconds == null || seconds <= 0 ? null : Duration(seconds: seconds);
  }
}
