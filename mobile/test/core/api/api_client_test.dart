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
  late List<String?> contentTypes;
  late int status;
  late String? retryAfterHeader;

  setUp(() async {
    authHeaders = [];
    methods = [];
    uris = [];
    bodies = [];
    contentTypes = [];
    status = 200;
    retryAfterHeader = null;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      authHeaders.add(request.headers.value(HttpHeaders.authorizationHeader));
      methods.add(request.method);
      uris.add(request.uri);
      contentTypes.add(request.headers.value(HttpHeaders.contentTypeHeader));
      bodies.add(await utf8.decodeStream(request));
      request.response.statusCode = status;
      if (retryAfterHeader case final value?) {
        request.response.headers.set(HttpHeaders.retryAfterHeader, value);
      }
      if (status != 204) {
        request.response
          ..headers.contentType = ContentType.json
          ..write(status == 200
              ? '{"ok": true}'
              : '{"detail": "Invalid bearer token"}');
      }
      await request.response.close();
    });
  });

  tearDown(() => server.close(force: true));

  Uri base() => Uri.parse('http://127.0.0.1:${server.port}');

  test('gắn Authorization: Bearer khi có token', () async {
    final client =
        ApiClient(baseUrl: base(), authTokenProvider: () async => 'app-token');

    await client.postJson('/doses/batch', body: {});

    expect(authHeaders.single, 'Bearer app-token');
  });

  test('không gắn header khi chưa đăng nhập (token null)', () async {
    final client =
        ApiClient(baseUrl: base(), authTokenProvider: () async => null);

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
      throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401)),
    );
    expect(called, 1);
  });

  test('lỗi khác 401 không gọi onUnauthorized', () async {
    status = 403;
    var called = 0;
    final client =
        ApiClient(baseUrl: base(), onUnauthorized: () async => called++);

    await expectLater(
        client.postJson('/x', body: {}), throwsA(isA<ApiException>()));
    expect(called, 0);
  });

  test('getJson gửi GET kèm query đã mã hoá và giải mã JSON', () async {
    final client =
        ApiClient(baseUrl: base(), authTokenProvider: () async => 't');

    final result = await client.getJson('/catalog/medications',
        query: {'q': 'thuốc ho', 'limit': '5'});

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

  test('putJson gửi PUT đúng body và Bearer, chấp nhận 204', () async {
    status = 204;
    final client =
        ApiClient(baseUrl: base(), authTokenProvider: () async => 't');
    expect(
        await client.putJson('/profile', body: {'full_name': 'Mai'}), isNull);
    expect(methods.single, 'PUT');
    expect(uris.single.path, '/profile');
    expect(jsonDecode(bodies.single), {'full_name': 'Mai'});
    expect(authHeaders.single, 'Bearer t');
  });

  test('post gửi POST không body, không Content-Type, kèm Bearer', () async {
    final client =
        ApiClient(baseUrl: base(), authTokenProvider: () async => 't');

    final result = await client.post('/family/links/7/reject');

    expect(result, {'ok': true});
    expect(methods.single, 'POST');
    expect(uris.single.path, '/family/links/7/reject');
    expect(bodies.single, isEmpty);
    expect(contentTypes.single, isNull);
    expect(authHeaders.single, 'Bearer t');
  });

  test('postJson với body null vẫn gửi "null" (lý do cần post)', () async {
    final client = ApiClient(baseUrl: base());

    await client.postJson('/x', body: null);

    expect(bodies.single, 'null');
    expect(contentTypes.single, startsWith('application/json'));
  });

  test('post: lỗi 409 ném ApiException kèm mã và body', () async {
    status = 409;
    final client = ApiClient(baseUrl: base());

    await expectLater(
      client.post('/family/links/7/revoke'),
      throwsA(isA<ApiException>()
          .having((e) => e.statusCode, 'statusCode', 409)
          .having((e) => e.isTransient, 'isTransient', isFalse)),
    );
  });

  for (final call in <String, Future<Object?> Function(ApiClient)>{
    'GET': (c) => c.getJson('/medications'),
    'POST': (c) => c.post('/family/links/1/reject'),
    'PUT': (c) => c.putJson('/profile', body: {}),
    'PATCH': (c) => c.patchJson('/medications/1', body: {}),
    'DELETE': (c) => c.delete('/medications/1'),
  }.entries) {
    test('${call.key} nhận 401 gọi onUnauthorized', () async {
      status = 401;
      var called = 0;
      final client =
          ApiClient(baseUrl: base(), onUnauthorized: () async => called++);

      await expectLater(
        call.value(client),
        throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401)),
      );
      expect(called, 1);
    });
  }

  test('429 kèm Retry-After số giây → retryAfter', () async {
    status = 429;
    retryAfterHeader = '900';
    final client = ApiClient(baseUrl: base());

    await expectLater(
      client.postJson('/family/link-requests', body: {}),
      throwsA(isA<ApiException>()
          .having((e) => e.statusCode, 'statusCode', 429)
          .having((e) => e.retryAfter, 'retryAfter',
              const Duration(seconds: 900))),
    );
  });

  test('429 không có Retry-After → retryAfter null', () async {
    status = 429;
    final client = ApiClient(baseUrl: base());

    await expectLater(
      client.postJson('/family/link-requests', body: {}),
      throwsA(isA<ApiException>()
          .having((e) => e.retryAfter, 'retryAfter', isNull)),
    );
  });

  test('Retry-After dạng ngày giờ hoặc không dương → retryAfter null', () async {
    status = 429;
    final client = ApiClient(baseUrl: base());

    for (final value in ['Wed, 21 Oct 2026 07:28:00 GMT', '0', '-5']) {
      retryAfterHeader = value;
      await expectLater(
        client.postJson('/family/link-requests', body: {}),
        throwsA(isA<ApiException>()
            .having((e) => e.retryAfter, 'retryAfter', isNull)),
      );
    }
  });

  test('không kết nối được máy chủ ném ApiException tạm thời', () async {
    final port = server.port;
    await server.close(force: true);
    final client = ApiClient(baseUrl: Uri.parse('http://127.0.0.1:$port'));

    await expectLater(
      client.getJson('/medications'),
      throwsA(isA<ApiException>()
          .having((e) => e.isTransient, 'isTransient', true)),
    );
  });
}
