import 'dart:convert';
import 'dart:io';

import 'package:drugtime_mobile/core/api/api_client.dart';
import 'package:drugtime_mobile/features/consent/data/repositories/remote_consent_repository.dart';
import 'package:drugtime_mobile/features/consent/domain/entities/consent.dart';
import 'package:drugtime_mobile/features/consent/domain/entities/consent_failure.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> consentJson(String purpose, {bool granted = false}) => {
      'purpose': purpose,
      'status': granted ? 'granted' : 'not_granted',
      'granted_at': granted ? '2026-10-03T17:20:05+07:00' : null,
      'document_version': granted ? '2026-10-v1' : null,
      'current_document_version': '2026-10-v1',
    };

class _Request {
  _Request(this.method, this.uri, this.authorization, this.body);

  final String method;
  final Uri uri;
  final String? authorization;
  final String body;

  Object? get json => body.isEmpty ? null : jsonDecode(body);
}

void main() {
  late HttpServer server;
  late List<_Request> requests;
  late List<(int, Object?)> replies;
  late int unauthorizedCalls;
  late RemoteConsentRepository repo;

  setUp(() async {
    requests = [];
    replies = [];
    unauthorizedCalls = 0;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      requests.add(_Request(
        request.method,
        request.uri,
        request.headers.value(HttpHeaders.authorizationHeader),
        await utf8.decodeStream(request),
      ));
      final (status, body) = replies.removeAt(0);
      request.response.statusCode = status;
      if (body != null) {
        request.response
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(body));
      }
      await request.response.close();
    });
    repo = RemoteConsentRepository(ApiClient(
      baseUrl: Uri.parse('http://127.0.0.1:${server.port}'),
      authTokenProvider: () async => 'app-token',
      onUnauthorized: () async => unauthorizedCalls++,
    ));
  });

  tearDown(() => server.close(force: true));

  test('fetchAll đọc đủ ba mục đích của GET /consents', () async {
    replies.add((200, {
      'items': [
        consentJson('health_data', granted: true),
        consentJson('family_sharing'),
        consentJson('ai_meal'),
      ]
    }));

    final states = await repo.fetchAll();

    expect(states.map((s) => s.purpose), ConsentPurpose.values);
    expect(states.map((s) => s.granted), [true, false, false]);
    expect(states.first.grantedAt, DateTime.parse('2026-10-03T17:20:05+07:00'));
    expect(states.first.documentVersion, '2026-10-v1');
    expect(requests.single.method, 'GET');
    expect(requests.single.uri.path, '/consents');
    expect(requests.single.authorization, 'Bearer app-token');
  });

  test('grant gửi POST /consents với một mục đích và phiên bản văn bản; 201 và 200 đều ok',
      () async {
    replies
      ..add((201, consentJson('health_data', granted: true)))
      ..add((200, consentJson('health_data', granted: true)));

    final first = await repo.grant(ConsentPurpose.healthData);
    final again = await repo.grant(ConsentPurpose.healthData);

    expect(first.granted, isTrue);
    expect(again.granted, isTrue);
    expect(requests.map((r) => (r.method, r.uri.path)), [
      ('POST', '/consents'),
      ('POST', '/consents'),
    ]);
    expect(requests.first.json, {'purpose': 'health_data', 'document_version': '2026-10-v1'});
  });

  test('withdraw gửi POST /consents/{purpose}/withdraw và trả not_granted', () async {
    replies.add((200, consentJson('family_sharing')));

    final state = await repo.withdraw(ConsentPurpose.familySharing);

    expect(state.purpose, ConsentPurpose.familySharing);
    expect(state.granted, isFalse);
    expect(requests.single.method, 'POST');
    expect(requests.single.uri.path, '/consents/family_sharing/withdraw');
  });

  Future<void> expectKind(Future<Object?> call, ConsentFailureKind kind) => expectLater(
        call,
        throwsA(isA<ConsentFailure>().having((f) => f.kind, 'kind', kind)),
      );

  test('map lỗi: 422 outdated, 503 mạng, 401 phiên hết hạn, 422 field', () async {
    replies
      ..add((422, {'detail': 'consent_document_outdated'}))
      ..add((503, {'detail': 'unavailable'}))
      ..add((401, {'detail': 'Missing bearer token'}))
      ..add((422, {
        'detail': [
          {'loc': ['body', 'purpose'], 'msg': 'x', 'type': 'enum'}
        ]
      }));

    await expectKind(repo.grant(ConsentPurpose.aiMeal), ConsentFailureKind.documentOutdated);
    await expectKind(repo.fetchAll(), ConsentFailureKind.network);
    await expectKind(repo.withdraw(ConsentPurpose.aiMeal), ConsentFailureKind.unauthorized);
    await expectKind(repo.grant(ConsentPurpose.aiMeal), ConsentFailureKind.unknown);
    expect(unauthorizedCalls, 1);
  });

  test('không kết nối được máy chủ → network', () async {
    await server.close(force: true);

    await expectKind(repo.fetchAll(), ConsentFailureKind.network);
  });
}
