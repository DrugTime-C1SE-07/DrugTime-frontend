import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:drugtime_mobile/core/api/api_client.dart';
import 'package:drugtime_mobile/features/adherence_history/data/repositories/remote_adherence_history_repository.dart';
import 'package:drugtime_mobile/features/adherence_history/domain/entities/adherence_history.dart';
import 'package:drugtime_mobile/features/adherence_history/domain/entities/adherence_history_failure.dart';
import 'adherence_history_test_helpers.dart';

void main() {
  test(
      'GET carries explicit selectors and fresh bearer; no patient selector or writes',
      () async {
    var token = 'first';
    final requests = <http.Request>[];
    final api = ApiClient(
        baseUrl: Uri.parse('https://api.example.test'),
        authTokenProvider: () async => token,
        httpClient: MockClient((r) async {
          requests.add(r);
          return http.Response(
              jsonEncode(historyFixture(
                  mode: HistoryMode.values.firstWhere(
                      (m) => m.wire == r.url.queryParameters['group_by']))),
              200);
        }));
    final repo = RemoteAdherenceHistoryRepository(api);
    for (final mode in HistoryMode.values) {
      await repo.fetch(
          from: DateTime.utc(2026, 10),
          to: DateTime.utc(2026, 10, 21),
          mode: mode);
      token = 'second';
    }
    expect(requests.map((r) => r.method), ['GET', 'GET']);
    expect(requests.first.url.queryParameters,
        {'from': '2026-10-01', 'to': '2026-10-21', 'group_by': 'date'});
    expect(requests.last.headers['Authorization'], 'Bearer second');
    expect(
        requests.every((r) => !r.url.queryParameters.containsKey('patient_id')),
        isTrue);
  });
  for (final entry in {
    401: HistoryFailureKind.unauthorized,
    403: HistoryFailureKind.forbidden,
    422: HistoryFailureKind.validation,
    500: HistoryFailureKind.unavailable,
    200: HistoryFailureKind.invalidResponse,
  }.entries) {
    test('maps ${entry.key} safely and invokes unauthorized handler', () async {
      var unauthorized = false;
      final repo = RemoteAdherenceHistoryRepository(ApiClient(
          baseUrl: Uri.parse('https://api.example.test'),
          onUnauthorized: () async {
            unauthorized = true;
          },
          httpClient: MockClient(
              (_) async => http.Response('Private raw body', entry.key))));
      await expectLater(
          repo.fetch(
              from: DateTime.utc(2026, 10),
              to: DateTime.utc(2026, 10, 21),
              mode: HistoryMode.date),
          throwsA(isA<HistoryFailure>()
              .having((e) => e.kind, 'kind', entry.value)
              .having(
                  (e) => e.toString().contains('Private'), 'safe', isFalse)));
      expect(unauthorized, entry.key == 401);
    });
  }
  test('network and consent errors remain failures', () async {
    for (final network in [true, false]) {
      final repo = RemoteAdherenceHistoryRepository(ApiClient(
          baseUrl: Uri.parse('https://api.example.test'),
          httpClient: MockClient((_) async {
            if (network) throw http.ClientException('offline');
            return http.Response('{"detail":"consent_revoked"}', 403);
          })));
      await expectLater(
          repo.fetch(
              from: DateTime.utc(2026, 10),
              to: DateTime.utc(2026, 10, 21),
              mode: HistoryMode.date),
          throwsA(isA<HistoryFailure>().having(
              (e) => e.kind,
              'kind',
              network
                  ? HistoryFailureKind.network
                  : HistoryFailureKind.consent)));
    }
  });
}
