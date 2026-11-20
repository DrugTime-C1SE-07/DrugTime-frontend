import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:drugtime_mobile/core/api/api_client.dart';
import 'package:drugtime_mobile/core/api/api_exception.dart';
import 'package:drugtime_mobile/features/consent/data/account_deletion_repository.dart';

void main() {
  test(
      'uses authenticated bodyless lookup/cancel and OTP verification before final create',
      () async {
    final calls = <http.Request>[];
    final api = ApiClient(
        baseUrl: Uri.parse('https://test.local'),
        authTokenProvider: () async => 'session',
        httpClient: MockClient((request) async {
          calls.add(request);
          expect(request.headers['Authorization'], 'Bearer session');
          final path = request.url.path;
          if (path.endsWith('/otp/verify') ||
              path.endsWith('/current/cancel')) {
            return http.Response('', 204);
          }
          if (path.endsWith('/otp')) {
            return http.Response(
                jsonEncode({
                  'challenge_id': 'proof',
                  'expires_at': '2026-11-19T00:05:00Z'
                }),
                201);
          }
          if (path.endsWith('/current')) return http.Response('null', 200);
          return http.Response(
              jsonEncode({
                'status': 'cho_xoa',
                'requested_at': '2026-11-19T00:00:00Z',
                'scheduled_deletion_at': '2026-12-19T00:00:00Z'
              }),
              201);
        }));
    final repo = RemoteAccountDeletionRepository(api);
    expect(await repo.current(), isNull);
    final proof = await repo.issue();
    await repo.verify(proof.id, '123456');
    final result = await repo.create(proof.id);
    await repo.cancel();
    expect(result.scheduledAt, DateTime.utc(2026, 12, 19));
    expect(calls.map((r) => r.method).toList(),
        ['GET', 'POST', 'POST', 'POST', 'POST']);
    for (final index in [0, 1, 4]) {
      expect(calls[index].body, isEmpty);
      expect(calls[index].headers['Content-Type'], isNull);
    }
    expect(
        jsonDecode(calls[2].body), {'challenge_id': 'proof', 'otp': '123456'});
    expect(jsonDecode(calls[3].body), {'challenge_id': 'proof'});
  });
  test('cancel requires exact backend ACK and rate metadata comes from backend',
      () async {
    var status = 200;
    final api = ApiClient(
        baseUrl: Uri.parse('https://test.local'),
        httpClient: MockClient((_) async => http.Response(
            '{"detail":"deletion_otp_invalid"}', status,
            headers: {'Retry-After': '899', 'X-OTP-Attempts-Remaining': '0'})));
    final repo = RemoteAccountDeletionRepository(api);
    await expectLater(repo.cancel(), throwsA(isA<ApiException>()));
    status = 422;
    try {
      await repo.verify('proof', '123456');
      fail('Expected error');
    } on ApiException catch (e) {
      expect(e.retryAfter, const Duration(seconds: 899));
      expect(e.remainingOtpAttempts, 0);
    }
  });
}
