import 'dart:convert';

import 'package:drugtime_mobile/core/api/api_client.dart';
import 'package:drugtime_mobile/features/adherence/data/repositories/remote_adherence_repository.dart';
import 'package:drugtime_mobile/features/adherence/domain/entities/adherence_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../adherence/adherence_api_mapper_test.dart'
    show sampleHistoryJson, samplePatientId;

void main() {
  test('AC4: refetches the selected patient and current bearer after a denial',
      () async {
    final requests = <http.Request>[];
    var token = 'session-one';
    final client = MockClient((request) async {
      requests.add(request);
      if (requests.length == 2) {
        return http.Response('{"detail":"khong_co_quyen"}', 403);
      }
      return http.Response.bytes(
          utf8.encode(jsonEncode(sampleHistoryJson())), 200);
    });
    addTearDown(client.close);
    final repo = RemoteAdherenceRepository(ApiClient(
      baseUrl: Uri.parse('https://api.example.test/'),
      httpClient: client,
      authTokenProvider: () async => token,
    ));
    Future<Object?> read() => repo.fetch(
          patientId: samplePatientId,
          from: DateTime.utc(2026, 10, 1),
          to: DateTime.utc(2026, 10, 22),
        );
    expect(await read(), isNotNull);
    token = 'session-two';
    await expectLater(
        read(),
        throwsA(isA<AdherenceFailure>()
            .having((e) => e.kind, 'kind', AdherenceFailureKind.denied)));
    expect(await read(), isNotNull);
    expect(requests, hasLength(3));
    expect(requests.map((r) => r.headers['Authorization']),
        ['Bearer session-one', 'Bearer session-two', 'Bearer session-two']);
    for (final request in requests) {
      expect(request.method, 'GET');
      expect(request.url.path, '/adherence');
      expect(request.url.queryParameters, {
        'patient_id': samplePatientId,
        'from': '2026-10-01',
        'to': '2026-10-22',
        'group_by': 'date',
      });
    }
  });

  test('AC6: a network failure after success never returns cached history',
      () async {
    var calls = 0;
    final client = MockClient((_) async {
      if (++calls > 1) throw http.ClientException('offline');
      return http.Response.bytes(
          utf8.encode(jsonEncode(sampleHistoryJson())), 200);
    });
    addTearDown(client.close);
    final repo = RemoteAdherenceRepository(ApiClient(
      baseUrl: Uri.parse('https://api.example.test/'),
      httpClient: client,
    ));
    Future<Object?> read() => repo.fetch(
          patientId: samplePatientId,
          from: DateTime.utc(2026, 10, 1),
          to: DateTime.utc(2026, 10, 22),
        );
    expect(await read(), isNotNull);
    await expectLater(
        read(),
        throwsA(isA<AdherenceFailure>()
            .having((e) => e.kind, 'kind', AdherenceFailureKind.network)));
    expect(calls, 2);
  });

  test('AC4: a response for P cannot satisfy a request for Q', () async {
    const other = '22222222-2222-4222-8222-222222222222';
    final requested = <String?>[];
    final client = MockClient((request) async {
      requested.add(request.url.queryParameters['patient_id']);
      return http.Response.bytes(
          utf8.encode(jsonEncode(sampleHistoryJson())), 200);
    });
    addTearDown(client.close);
    final repo = RemoteAdherenceRepository(ApiClient(
      baseUrl: Uri.parse('https://api.example.test/'),
      httpClient: client,
    ));
    await repo.fetch(
      patientId: samplePatientId,
      from: DateTime.utc(2026, 10, 1),
      to: DateTime.utc(2026, 10, 22),
    );
    await expectLater(
        repo.fetch(
          patientId: other,
          from: DateTime.utc(2026, 10, 1),
          to: DateTime.utc(2026, 10, 22),
        ),
        throwsA(isA<AdherenceFailure>().having(
            (e) => e.kind, 'kind', AdherenceFailureKind.invalidResponse)));
    expect(requested, [samplePatientId, other]);
  });
}
