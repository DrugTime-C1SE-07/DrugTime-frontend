import 'dart:convert';

import 'package:drugtime_mobile/core/api/api_client.dart';
import 'package:drugtime_mobile/features/adherence/data/repositories/remote_adherence_repository.dart';
import 'package:drugtime_mobile/features/adherence/domain/entities/adherence_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'adherence_api_mapper_test.dart' show sampleHistoryJson, samplePatientId;

void main() {
  test('GET sends patient, bounded dates, group and app bearer on each call',
      () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      return http.Response.bytes(
        utf8.encode(jsonEncode(sampleHistoryJson())),
        200,
      );
    });
    var token = 'first-token';
    final repo = RemoteAdherenceRepository(ApiClient(
      baseUrl: Uri.parse('https://api.example.test/'),
      httpClient: client,
      authTokenProvider: () async => token,
    ));

    for (final current in ['first-token', 'second-token']) {
      token = current;
      final history = await repo.fetch(
        patientId: samplePatientId,
        from: DateTime.utc(2026, 10, 1),
        to: DateTime.utc(2026, 10, 22),
      );
      expect(history.patientId, samplePatientId);
    }
    expect(requests, hasLength(2));
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
    expect(requests.map((r) => r.headers['Authorization']),
        ['Bearer first-token', 'Bearer second-token']);
  });

  for (final (status, expected) in [
    (401, AdherenceFailureKind.unauthorized),
    (403, AdherenceFailureKind.denied),
    (422, AdherenceFailureKind.invalidRange),
    (503, AdherenceFailureKind.unavailable),
  ]) {
    test('HTTP $status maps to $expected without retry', () async {
      var calls = 0;
      var unauthorized = 0;
      final repo = RemoteAdherenceRepository(ApiClient(
        baseUrl: Uri.parse('https://api.example.test/'),
        httpClient: MockClient((_) async {
          calls++;
          return http.Response('{"detail":"khong_co_quyen"}', status);
        }),
        authTokenProvider: () async => 'token',
        onUnauthorized: () async => unauthorized++,
      ));
      await expectLater(
        repo.fetch(
          patientId: samplePatientId,
          from: DateTime.utc(2026, 10, 1),
          to: DateTime.utc(2026, 10, 22),
        ),
        throwsA(
            isA<AdherenceFailure>().having((f) => f.kind, 'kind', expected)),
      );
      expect(calls, 1);
      expect(unauthorized, status == 401 ? 1 : 0);
    });
  }

  test('rejects a response for another patient', () async {
    final repo = RemoteAdherenceRepository(ApiClient(
      baseUrl: Uri.parse('https://api.example.test/'),
      httpClient: MockClient((_) async => http.Response.bytes(
            utf8.encode(jsonEncode(sampleHistoryJson(
                patientId: '22222222-2222-4222-8222-222222222222'))),
            200,
          )),
    ));
    await expectLater(
      repo.fetch(
        patientId: samplePatientId,
        from: DateTime.utc(2026, 10, 1),
        to: DateTime.utc(2026, 10, 22),
      ),
      throwsA(isA<AdherenceFailure>()
          .having((f) => f.kind, 'kind', AdherenceFailureKind.invalidResponse)),
    );
  });
}
