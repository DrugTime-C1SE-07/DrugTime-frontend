import 'dart:convert';
import 'dart:io';

import 'api_exception.dart';

typedef AuthTokenProvider = Future<String?> Function();

/// Gọi khi API trả 401: phiên không còn hiệu lực, app đưa người dùng về màn Đăng nhập.
typedef UnauthorizedHandler = Future<void> Function();

class ApiClient {
  ApiClient({
    required Uri baseUrl,
    HttpClient? httpClient,
    AuthTokenProvider? authTokenProvider,
    UnauthorizedHandler? onUnauthorized,
  })  : _baseUrl = baseUrl,
        _httpClient = httpClient ?? HttpClient(),
        _authTokenProvider = authTokenProvider,
        _onUnauthorized = onUnauthorized;

  final Uri _baseUrl;
  final HttpClient _httpClient;
  final AuthTokenProvider? _authTokenProvider;
  final UnauthorizedHandler? _onUnauthorized;

  Future<Object?> getJson(String path, {Map<String, String>? query}) =>
      _send('GET', path, query: query);

  Future<Object?> postJson(String path, {required Object? body}) =>
      _send('POST', path, body: body, hasBody: true);

  Future<Object?> patchJson(String path, {required Object? body}) =>
      _send('PATCH', path, body: body, hasBody: true);

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

    HttpClientRequest request;
    try {
      request = await _httpClient.openUrl(method, uri);
    } on SocketException catch (error) {
      throw ApiException(error.message, isTransient: true);
    } on HttpException catch (error) {
      throw ApiException(error.message, isTransient: true);
    }

    final token = await _authTokenProvider?.call();
    if (token != null && token.isNotEmpty) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }

    if (hasBody) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
    }

    final HttpClientResponse response;
    final String responseBody;
    try {
      response = await request.close();
      responseBody = await utf8.decodeStream(response);
    } on SocketException catch (error) {
      throw ApiException(error.message, isTransient: true);
    } on HttpException catch (error) {
      throw ApiException(error.message, isTransient: true);
    }

    if (response.statusCode == HttpStatus.unauthorized) {
      await _onUnauthorized?.call();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        responseBody.isEmpty ? response.reasonPhrase : responseBody,
        statusCode: response.statusCode,
        isTransient: response.statusCode == HttpStatus.requestTimeout ||
            response.statusCode == HttpStatus.tooManyRequests ||
            response.statusCode >= 500,
      );
    }

    if (responseBody.isEmpty) {
      return null;
    }

    return jsonDecode(responseBody);
  }
}
