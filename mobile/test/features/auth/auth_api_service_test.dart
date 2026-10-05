import 'dart:convert';

import 'package:drugtime_mobile/features/auth/data/sources/auth_api_exception.dart';
import 'package:drugtime_mobile/features/auth/data/sources/auth_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response _json(Object body, int status) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

AuthApiService _service(Future<http.Response> Function(http.Request) handler) =>
    AuthApiService(baseUrl: 'http://api.test', client: MockClient(handler));

Matcher _authError(AuthErrorKind kind, {String? code}) => throwsA(
      isA<AuthApiException>()
          .having((e) => e.kind, 'kind', kind)
          .having((e) => e.code, 'code', code),
    );

void main() {
  test('requestMobileOtp gửi POST JSON tới /auth/mobile/otp', () async {
    late http.Request sent;
    final service = _service((request) async {
      sent = request;
      return http.Response('', 204);
    });

    await service.requestMobileOtp(phone: '+84900000001');

    expect(sent.method, 'POST');
    expect(sent.url.toString(), 'http://api.test/auth/mobile/otp');
    expect(sent.headers['Content-Type'], startsWith('application/json'));
    expect(sent.headers.containsKey('Authorization'), isFalse);
    expect(jsonDecode(sent.body), {'phone': '+84900000001'});
  });

  test('verifyMobileOtp trả JSON phiên khi 200', () async {
    final service = _service((request) async {
      expect(jsonDecode(request.body), {'email': 'lan@example.com', 'token': '123456'});
      return _json({
        'user_id': 'u-1',
        'session': {
          'access_token': 'app-token',
          'token_type': 'bearer',
          'session_type': 'mobile',
          'expires_at': '2026-10-12T09:15:02+07:00',
          'expires_in': 864000,
        },
        'profile_complete': false,
      }, 200);
    });

    final body = await service.verifyMobileOtp(email: 'lan@example.com', token: '123456');

    expect(body['user_id'], 'u-1');
    expect((body['session'] as Map)['access_token'], 'app-token');
  });

  test('completeProfile gửi bearer và body theo contract', () async {
    late http.Request sent;
    final service = _service((request) async {
      sent = request;
      return http.Response('', 204);
    });

    await service.completeProfile(
      accessToken: 'app-token',
      fullName: 'Nguyễn Thị Lan',
      dateOfBirth: DateTime(1958, 4, 12),
      gender: 'nu',
    );

    expect(sent.url.toString(), 'http://api.test/auth/profile');
    expect(sent.headers['Authorization'], 'Bearer app-token');
    expect(jsonDecode(sent.body), {
      'ho_ten': 'Nguyễn Thị Lan',
      'ngay_sinh': '1958-04-12',
      'gioi_tinh': 'nu',
    });
  });

  group('phân loại lỗi theo mã HTTP', () {
    final cases = <(int, Object, AuthErrorKind, String?)>[
      (401, {'detail': 'Invalid credentials'}, AuthErrorKind.invalidCredentials,
          'Invalid credentials'),
      (403, {'detail': 'admin_must_use_web'}, AuthErrorKind.adminMustUseWeb,
          'admin_must_use_web'),
      (422, {'detail': 'invalid_phone'}, AuthErrorKind.invalidInput, 'invalid_phone'),
      (
        422,
        {
          'detail': [
            {'loc': ['body', 'token'], 'msg': 'Field required', 'type': 'missing'}
          ]
        },
        AuthErrorKind.invalidInput,
        null
      ),
      (429, {'detail': 'rate_limited'}, AuthErrorKind.rateLimited, 'rate_limited'),
      (503, {'detail': 'auth_provider_unavailable'}, AuthErrorKind.unavailable,
          'auth_provider_unavailable'),
      (500, {'detail': 'Internal Server Error'}, AuthErrorKind.unavailable,
          'Internal Server Error'),
    ];
    for (final (status, body, kind, code) in cases) {
      test('$status → $kind', () {
        final service = _service((_) async => _json(body, status));

        expect(
          () => service.verifyMobileOtp(phone: '+84900000001', token: '000000'),
          _authError(kind, code: code),
        );
      });
    }

    test('body không phải JSON vẫn phân loại theo mã', () {
      final service = _service((_) async => http.Response('Bad gateway', 502));

      expect(() => service.requestMobileOtp(email: 'a@b.vn'),
          _authError(AuthErrorKind.unavailable));
    });

    test('lỗi mạng → network', () {
      final service =
          _service((_) async => throw http.ClientException('Connection refused'));

      expect(() => service.requestMobileOtp(email: 'a@b.vn'),
          _authError(AuthErrorKind.network));
    });

    test('quá thời gian chờ → network', () {
      final service = AuthApiService(
        baseUrl: 'http://api.test',
        timeout: const Duration(milliseconds: 10),
        client: MockClient((_) => Future.delayed(
            const Duration(milliseconds: 200), () => http.Response('', 204))),
      );

      expect(() => service.requestMobileOtp(email: 'a@b.vn'),
          _authError(AuthErrorKind.network));
    });
  });
}
