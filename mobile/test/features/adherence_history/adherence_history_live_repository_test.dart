import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/core/api/api_client.dart';
import 'package:drugtime_mobile/features/adherence_history/data/repositories/remote_adherence_history_repository.dart';
import 'package:drugtime_mobile/features/adherence_history/domain/entities/adherence_history.dart';
import 'package:drugtime_mobile/features/adherence_history/domain/entities/adherence_history_failure.dart';

void main() {
  final raw = Platform.environment['ADHERENCE_LIVE_CONFIG'];
  test('live_repository_reads_both_groupings_and_observes_revoke', () async {
    final config = jsonDecode(raw!) as Map<String, dynamic>;
    final url = Uri.parse(config['url'] as String);
    if (url.scheme != 'http' ||
        !{'127.0.0.1', 'localhost', '::1'}.contains(url.host)) {
      fail('Live history probe only accepts a local backend');
    }
    var unauthorized = false;
    final repo = RemoteAdherenceHistoryRepository(ApiClient(
        baseUrl: url,
        authTokenProvider: () async => config['token'] as String,
        onUnauthorized: () async {
          unauthorized = true;
        }));
    final from = DateTime.parse('${config['from']}T00:00:00Z');
    final to = DateTime.parse('${config['to']}T00:00:00Z');
    for (final mode in HistoryMode.values) {
      final call = repo.fetch(from: from, to: to, mode: mode);
      if (config['phase'] == 'revoked' || config['phase'] == 'unauthorized') {
        final kind = config['phase'] == 'unauthorized'
            ? HistoryFailureKind.unauthorized
            : HistoryFailureKind.consent;
        await expectLater(call,
            throwsA(isA<HistoryFailure>().having((e) => e.kind, 'kind', kind)));
      } else {
        final data = await call;
        expect(data.patientId, config['patient_id']);
        expect(data.summary.total, config['total']);
        expect(data.summary.rate, config['rate']);
        expect(data.mode, mode);
      }
    }
    expect(unauthorized, config['phase'] == 'unauthorized');
  },
      skip: raw == null
          ? 'Requires local API/DB fixture; run in stage test.'
          : false);
}
