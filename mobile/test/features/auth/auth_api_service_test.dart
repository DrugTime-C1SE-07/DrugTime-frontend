import 'dart:convert';

import 'package:drugtime_mobile/features/auth/data/sources/auth_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('requestMobileOtp gửi POST JSON tới /auth/mobile/otp', () async {
    late http.Request sent;
    final service = AuthApiService(
      baseUrl: 'http://api.test',
      client: MockClient((request) async {
        sent = request;
        return http.Response('', 204);
      }),
    );

    await service.requestMobileOtp(phone: '+84900000000');

    expect(sent.method, 'POST');
    expect(sent.url.toString(), 'http://api.test/auth/mobile/otp');
    expect(sent.headers['Content-Type'], startsWith('application/json'));
    expect(jsonDecode(sent.body), {'phone': '+84900000000'});
  });

  test('requestMobileOtp ném lỗi mang đúng detail khi backend trả 400', () async {
    final service = AuthApiService(
      baseUrl: 'http://api.test',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({'detail': 'Số điện thoại không hợp lệ'}),
          400,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );

    expect(
      () => service.requestMobileOtp(phone: '123'),
      throwsA(isA<Exception>().having(
        (e) => e.toString(),
        'message',
        contains('Số điện thoại không hợp lệ'),
      )),
    );
  });
}
