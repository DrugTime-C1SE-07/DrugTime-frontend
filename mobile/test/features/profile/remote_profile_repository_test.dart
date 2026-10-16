import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/core/api/api_client.dart';
import 'package:drugtime_mobile/features/profile/data/repositories/remote_profile_repository.dart';
import 'package:drugtime_mobile/features/profile/domain/entities/health_profile.dart';
import 'package:drugtime_mobile/features/profile/domain/entities/profile_failure.dart';

void main() {
  late HttpServer server;
  late RemoteProfileRepository repo;
  late List<(String, Uri, Object?, String?)> calls;
  var status = 200;
  Object? response;
  setUp(() async {
    calls = [];
    status = 200;
    response = {
      'full_name': null,
      'date_of_birth': null,
      'gender': null,
      'conditions': []
    };
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final body = await utf8.decodeStream(request);
      calls.add((
        request.method,
        request.uri,
        body.isEmpty ? null : jsonDecode(body),
        request.headers.value('authorization')
      ));
      request.response.statusCode = status;
      if (status != 204) {
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(response));
      }
      await request.response.close();
    });
    repo = RemoteProfileRepository(ApiClient(
        baseUrl: Uri.parse('http://127.0.0.1:${server.port}'),
        authTokenProvider: () async => 'session'));
  });
  tearDown(() async {
    await server.close(force: true);
  });
  test('six operations, nullable GET, no patient selector, 204 writes',
      () async {
    final p = await repo.fetch();
    expect(p.fullName, isNull);
    status = 204;
    await repo.update(ProfileDraft(
        fullName: ' Mai ', dateOfBirth: DateTime(1960), gender: 'nu'));
    status = 200;
    response = {
      'items': [
        {'id': 3, 'name': 'Bệnh'}
      ],
      'total': 21,
      'limit': 20,
      'offset': 20
    };
    final page = await repo.catalog(offset: 20);
    expect(page.offset, 20);
    expect(page.total, 21);
    expect(calls.last.$2.queryParameters, {'offset': '20', 'limit': '20'});
    status = 201;
    response = {
      'id': 91,
      'condition_id': 3,
      'condition_name': 'Bệnh',
      'subtype': null,
      'stage': null
    };
    final link = await repo.addCondition(3);
    expect(link.id, 91);
    status = 200;
    await repo.updateCondition(91, {'stage': null});
    status = 204;
    await repo.deleteCondition(91);
    expect(calls.map((c) => c.$1).toList(),
        ['GET', 'PUT', 'GET', 'POST', 'PATCH', 'DELETE']);
    expect(calls.map((c) => c.$4), everyElement('Bearer session'));
    expect(calls[1].$3,
        {'full_name': 'Mai', 'date_of_birth': '1960-01-01', 'gender': 'nu'});
    expect(calls[4].$2.path, '/profile/conditions/91');
    expect(calls[4].$3, {'stage': null});
    expect(calls.every((c) => !c.$2.queryParameters.containsKey('patient_id')),
        isTrue);
  });
  for (final pair in {
    401: ProfileFailureKind.unauthorized,
    403: ProfileFailureKind.forbidden,
    404: ProfileFailureKind.missing,
    409: ProfileFailureKind.duplicate,
    422: ProfileFailureKind.validation,
    500: ProfileFailureKind.unavailable
  }.entries) {
    test('status ${pair.key} maps safely', () async {
      status = pair.key;
      response = {'detail': 'Private health data'};
      await expectLater(
          repo.fetch(),
          throwsA(
              isA<ProfileFailure>().having((e) => e.kind, 'kind', pair.value)));
    });
  }
  test('consent revoked response', () async {
    status = 403;
    response = {'detail': 'consent_revoked'};
    await expectLater(
        repo.fetch(),
        throwsA(isA<ProfileFailure>()
            .having((e) => e.kind, 'kind', ProfileFailureKind.consent)));
  });
  test('malformed shape becomes safe failure', () async {
    response = {'full_name': 11};
    await expectLater(
        repo.fetch(),
        throwsA(isA<ProfileFailure>().having(
            (e) => e.kind, 'kind', ProfileFailureKind.invalidResponse)));
  });
}
