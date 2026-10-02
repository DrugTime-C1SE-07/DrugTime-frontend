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

  Future<Object?> postJson(
    String path, {
    required Object? body,
  }) async {
    HttpClientRequest request;
    try {
      request = await _httpClient.postUrl(_baseUrl.resolve(path));
    } on SocketException catch (error) {
      throw ApiException(error.message, isTransient: true);
    } on HttpException catch (error) {
      throw ApiException(error.message, isTransient: true);
    }

    request.headers.contentType = ContentType.json;

    final token = await _authTokenProvider?.call();
    if (token != null && token.isNotEmpty) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }

    request.write(jsonEncode(body));

    final HttpClientResponse response;
    try {
      response = await request.close();
    } on SocketException catch (error) {
      throw ApiException(error.message, isTransient: true);
    } on HttpException catch (error) {
      throw ApiException(error.message, isTransient: true);
    }

    final responseBody = await utf8.decodeStream(response);
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
