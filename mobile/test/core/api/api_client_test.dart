import 'dart:io';

import 'package:drugtime_mobile/core/api/api_client.dart';
import 'package:drugtime_mobile/core/api/api_exception.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late HttpServer server;
  late List<String?> authHeaders;
  late int status;

  setUp(() async {
    authHeaders = [];
    status = 200;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      authHeaders.add(request.headers.value(HttpHeaders.authorizationHeader));
      await request.drain<void>();
      request.response
        ..statusCode = status
        ..headers.contentType = ContentType.json
        ..write(status == 200 ? '{"ok": true}' : '{"detail": "Invalid bearer token"}');
      await request.response.close();
    });
  });

  tearDown(() => server.close(force: true));

  Uri base() => Uri.parse('http://127.0.0.1:${server.port}');

  test('gắn Authorization: Bearer khi có token', () async {
    final client = ApiClient(baseUrl: base(), authTokenProvider: () async => 'app-token');

    await client.postJson('/doses/batch', body: {});

    expect(authHeaders.single, 'Bearer app-token');
  });

  test('không gắn header khi chưa đăng nhập (token null)', () async {
    final client = ApiClient(baseUrl: base(), authTokenProvider: () async => null);

    await client.postJson('/doses/batch', body: {});

    expect(authHeaders.single, isNull);
  });

  test('401 gọi onUnauthorized rồi ném ApiException 401', () async {
    status = 401;
    var called = 0;
    final client = ApiClient(
      baseUrl: base(),
      authTokenProvider: () async => 'expired',
      onUnauthorized: () async => called++,
    );

    await expectLater(
      client.postJson('/doses/batch', body: {}),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401)),
    );
    expect(called, 1);
  });

  test('lỗi khác 401 không gọi onUnauthorized', () async {
    status = 403;
    var called = 0;
    final client = ApiClient(baseUrl: base(), onUnauthorized: () async => called++);

    await expectLater(client.postJson('/x', body: {}), throwsA(isA<ApiException>()));
    expect(called, 0);
  });
}
