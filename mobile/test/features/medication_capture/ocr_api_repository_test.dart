import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:drugtime_mobile/core/api/api_client.dart';
import 'package:drugtime_mobile/features/medication_capture/data/ocr_api_repository.dart';
import 'package:drugtime_mobile/features/medication_capture/domain/ocr_models.dart';

void main() {
  final noMatch = {
    'status': 'no_match',
    'items': [],
    'preselected_id': null,
    'suggested_query': null,
    'reasons': []
  };
  test(
      'sends only original text/limit and pinned bearer; no-match200 is success',
      () async {
    const text = 'PANADOL\r\n500mg\n😀';
    final repo = RemoteOcrMatchingRepository(ApiClient(
        baseUrl: Uri.parse('https://test.invalid'),
        authTokenProvider: () async => 'new-session',
        httpClient: MockClient((r) async {
          expect(r.method, 'POST');
          expect(r.url.path, '/catalog/medications/match');
          expect(r.headers['Authorization'], 'Bearer old-session');
          expect(jsonDecode(r.body), {'text': text, 'limit': 5});
          return http.Response(jsonEncode(noMatch), 200);
        })));
    expect((await repo.match(text, sessionToken: 'old-session')).status,
        OcrMatchStatus.noMatch);
  });
  test('boundary text/limit; invalid input never reaches HTTP', () async {
    var calls = 0;
    final repo = RemoteOcrMatchingRepository(ApiClient(
        baseUrl: Uri.parse('https://test.invalid'),
        httpClient: MockClient((r) async {
          calls++;
          return http.Response(jsonEncode(noMatch), 200);
        })));
    for (final n in [1999, 2000]) {
      await repo.match('😀' * n, sessionToken: 'x', limit: 10);
    }
    for (final value in [' \r\n', '😀' * 2001]) {
      await expectLater(
          repo.match(value, sessionToken: 'x'), throwsA(isA<OcrFailure>()));
    }
    for (final n in [0, 11]) {
      await expectLater(repo.match('A', sessionToken: 'x', limit: n),
          throwsA(isA<OcrFailure>()));
    }
    expect(calls, 2);
  });
  for (final entry in {
    401: OcrFailureKind.unauthorized,
    422: OcrFailureKind.validation,
    500: OcrFailureKind.server,
    201: OcrFailureKind.badResponse
  }.entries) {
    test('HTTP${entry.key} is safe and not a false success', () async {
      final repo = RemoteOcrMatchingRepository(ApiClient(
          baseUrl: Uri.parse('https://test.invalid'),
          httpClient: MockClient(
              (_) async => http.Response('PRIVATE OCR PAYLOAD', entry.key))));
      await expectLater(
          repo.match('A', sessionToken: 'x'),
          throwsA(isA<OcrFailure>()
              .having((e) => e.kind, 'kind', entry.value)
              .having((e) => e.toString().contains('PRIVATE'), 'safe', false)));
    });
  }
  test('invalid JSON and network failures are sanitized', () async {
    for (final network in [false, true]) {
      final repo = RemoteOcrMatchingRepository(ApiClient(
          baseUrl: Uri.parse('https://test.invalid'),
          httpClient: MockClient((_) async {
            if (network) throw http.ClientException('PRIVATE');
            return http.Response('{', 200);
          })));
      await expectLater(
          repo.match('A', sessionToken: 'x'), throwsA(isA<OcrFailure>()));
    }
  });
}
