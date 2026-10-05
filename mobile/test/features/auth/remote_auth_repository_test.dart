import 'dart:convert';

import 'package:drugtime_mobile/features/auth/data/repositories/remote_auth_repository.dart';
import 'package:drugtime_mobile/features/auth/data/sources/auth_api_exception.dart';
import 'package:drugtime_mobile/features/auth/data/sources/auth_api_service.dart';
import 'package:drugtime_mobile/features/auth/data/sources/auth_session_store.dart';
import 'package:drugtime_mobile/features/auth/domain/entities/auth_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> _verifyBody({bool profileComplete = false, DateTime? expiresAt}) => {
      'user_id': 'u-1',
      'session': {
        'access_token': 'app-token',
        'token_type': 'bearer',
        'session_type': 'mobile',
        'expires_at': (expiresAt ?? DateTime.now().add(const Duration(days: 10)))
            .toIso8601String(),
        'expires_in': 864000,
      },
      'profile_complete': profileComplete,
    };

void main() {
  late MemoryAuthSessionStore store;
  late List<http.Request> requests;
  late Map<String, dynamic> verifyBody;
  late int profileStatus;

  RemoteAuthRepository repo() => RemoteAuthRepository(
        apiService: AuthApiService(
          baseUrl: 'http://api.test',
          client: MockClient((request) async {
            requests.add(request);
            if (request.url.path == '/auth/mobile/verify') {
              return http.Response(jsonEncode(verifyBody), 200);
            }
            if (request.url.path == '/auth/profile') {
              return http.Response('', profileStatus);
            }
            return http.Response('', 204);
          }),
        ),
        sessionStore: store,
      );

  setUp(() {
    store = MemoryAuthSessionStore();
    requests = [];
    verifyBody = _verifyBody();
    profileStatus = 204;
  });

  test('verifyOtp lưu phiên vào store', () async {
    final session = await repo().verifyOtp(email: 'a@b.vn', token: '123456');

    expect(session.accessToken, 'app-token');
    expect(session.profileComplete, isFalse);
    expect(store.session?.accessToken, 'app-token');
  });

  test('repo mới đọc lại phiên đã lưu (mở lại app)', () async {
    await repo().verifyOtp(email: 'a@b.vn', token: '123456');

    final again = await repo().getCurrentSession();

    expect(again?.userId, 'u-1');
    expect(again?.accessToken, 'app-token');
  });

  test('phiên hết hạn bị xóa và trả null', () async {
    verifyBody = _verifyBody(expiresAt: DateTime.now().subtract(const Duration(minutes: 1)));
    await repo().verifyOtp(email: 'a@b.vn', token: '123456');

    expect(await repo().getCurrentSession(), isNull);
    expect(store.session, isNull);
  });

  test('completeProfile gửi token đang lưu và cập nhật cờ profileComplete', () async {
    await repo().verifyOtp(email: 'a@b.vn', token: '123456');

    final updated = await repo().completeProfile(
      fullName: 'Nguyễn Thị Lan',
      dateOfBirth: DateTime(1958, 4, 12),
      gender: 'nu',
    );

    expect(updated.profileComplete, isTrue);
    expect(store.session?.profileComplete, isTrue);
    expect(requests.last.headers['Authorization'], 'Bearer app-token');
  });

  test('completeProfile lỗi thì phiên giữ nguyên profileComplete=false', () async {
    profileStatus = 422;
    await repo().verifyOtp(email: 'a@b.vn', token: '123456');

    await expectLater(
      repo().completeProfile(fullName: 'X', dateOfBirth: DateTime(1990), gender: 'nam'),
      throwsA(isA<AuthApiException>()),
    );
    expect(store.session?.profileComplete, isFalse);
  });

  test('completeProfile khi chưa đăng nhập → invalidCredentials, không gọi API', () async {
    await expectLater(
      repo().completeProfile(fullName: 'X', dateOfBirth: DateTime(1990), gender: 'nam'),
      throwsA(isA<AuthApiException>()
          .having((e) => e.kind, 'kind', AuthErrorKind.invalidCredentials)),
    );
    expect(requests, isEmpty);
  });

  test('signOut xóa store', () async {
    await repo().verifyOtp(email: 'a@b.vn', token: '123456');

    await repo().signOut();

    expect(store.session, isNull);
    expect(await repo().getCurrentSession(), isNull);
  });

  test('toJson/fromJson giữ nguyên mọi field (định dạng lưu)', () {
    final session = AuthSession(
      userId: 'u-1',
      accessToken: 't',
      sessionType: 'mobile',
      expiresAt: DateTime.utc(2026, 10, 12, 2, 15, 2),
      expiresInSeconds: 864000,
      profileComplete: true,
    );

    final restored = AuthSession.fromJson(
        jsonDecode(jsonEncode(session.toJson())) as Map<String, dynamic>);

    expect(restored.toJson(), session.toJson());
  });
}
