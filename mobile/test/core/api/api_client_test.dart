import 'dart:convert';
import 'dart:io';

import 'package:drugtime_mobile/core/api/api_client.dart';
import 'package:drugtime_mobile/core/api/api_exception.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late HttpServer server;
  late List<String?> authHeaders;
  late List<String> methods;
  late List<Uri> uris;
  late List<String> bodies;
  late int status;

  setUp(() async {
    authHeaders = [];
    methods = [];
    uris = [];
    bodies = [];
    status = 200;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      authHeaders.add(request.headers.value(HttpHeaders.authorizationHeader));
      methods.add(request.method);
      uris.add(request.uri);
      bodies.add(await utf8.decodeStream(request));
      request.response.statusCode = status;
      if (status != 204) {
        request.response
          ..headers.contentType = ContentType.json
          ..write(status == 200 ? '{"ok": true}' : '{"detail": "Invalid bearer token"}');
      }
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

  test('getJson gửi GET kèm query đã mã hoá và giải mã JSON', () async {
    final client = ApiClient(baseUrl: base(), authTokenProvider: () async => 't');

    final result = await client.getJson('/catalog/medications', query: {'q': 'thuốc ho', 'limit': '5'});

    expect(result, {'ok': true});
    expect(methods.single, 'GET');
    expect(uris.single.path, '/catalog/medications');
    expect(uris.single.queryParameters, {'q': 'thuốc ho', 'limit': '5'});
    expect(bodies.single, isEmpty);
    expect(authHeaders.single, 'Bearer t');
  });

  test('patchJson gửi PATCH với body JSON', () async {
    final client = ApiClient(baseUrl: base());

    await client.patchJson('/medications/7', body: {'stopped': false});

    expect(methods.single, 'PATCH');
    expect(uris.single.path, '/medications/7');
    expect(jsonDecode(bodies.single), {'stopped': false});
  });

  test('delete nhận 204 trả null', () async {
    status = 204;
    final client = ApiClient(baseUrl: base());

    expect(await client.delete('/medications/7'), isNull);
    expect(methods.single, 'DELETE');
  });

  for (final call in <String, Future<Object?> Function(ApiClient)>{
    'GET': (c) => c.getJson('/medications'),
    'PATCH': (c) => c.patchJson('/medications/1', body: {}),
    'DELETE': (c) => c.delete('/medications/1'),
  }.entries) {
    test('${call.key} nhận 401 gọi onUnauthorized', () async {
      status = 401;
      var called = 0;
      final client = ApiClient(baseUrl: base(), onUnauthorized: () async => called++);

      await expectLater(
        call.value(client),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401)),
      );
      expect(called, 1);
    });
  }

  test('không kết nối được máy chủ ném ApiException tạm thời', () async {
    final port = server.port;
    await server.close(force: true);
    final client = ApiClient(baseUrl: Uri.parse('http://127.0.0.1:$port'));

    await expectLater(
      client.getJson('/medications'),
      throwsA(isA<ApiException>().having((e) => e.isTransient, 'isTransient', true)),
    );
  });
}
