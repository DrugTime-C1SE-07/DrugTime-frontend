import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:drugtime_mobile/core/api/api_client.dart';
import 'package:drugtime_mobile/core/notification/device_token_coordinator.dart';
import 'package:drugtime_mobile/core/notification/device_token_store.dart';
import 'package:drugtime_mobile/core/notification/family_push_service.dart';
import 'package:drugtime_mobile/features/auth/domain/entities/auth_session.dart';

class TokenStore implements DeviceTokenStore {
  DeviceTokenRecord? record;
  @override
  Future<DeviceTokenRecord?> read() async => record;
  @override
  Future<void> write(DeviceTokenRecord value) async {
    record = value;
  }

  @override
  Future<void> clear() async {
    record = null;
  }
}

class Messaging implements FamilyMessaging {
  final refresh = StreamController<String>.broadcast(sync: true);
  int deletes = 0;
  bool failDelete = false;
  String token = 'first';
  final auto = <bool>[];
  @override
  Stream<String> get tokenRefresh => refresh.stream;
  @override
  Future<String?> getToken() async => token;
  @override
  Future<void> deleteToken() async {
    if (failDelete) throw StateError('delete failed');
    deletes++;
  }

  @override
  Future<void> setAutoInit(bool value) async {
    auto.add(value);
  }
}

AuthSession tokenSession(String user) => AuthSession(
    userId: user,
    accessToken: 'bearer-$user',
    expiresAt: DateTime.now().add(const Duration(days: 1)),
    profileComplete: true);

void main() {
  test(
      'refresh sends previous token atomically; late old-installation event cannot register for B',
      () async {
    final messaging = Messaging(), store = TokenStore();
    final requests = <http.Request>[];
    final updated = Completer<void>();
    final c = DeviceTokenCoordinator(
        messaging: messaging,
        store: store,
        clearHealth: () {},
        clearNotifications: () async {},
        clientForSession: (session) => ApiClient(
            baseUrl: Uri.parse('http://localhost'),
            authTokenProvider: () async => session.accessToken,
            httpClient: MockClient((r) async {
              requests.add(r);
              if (r.method == 'PUT' &&
                  jsonDecode(r.body)['fcm_token'] == 'refreshed') {
                updated.complete();
              }
              return http.Response('', 204);
            })));
    await c.activate(tokenSession('A'));
    messaging.token = 'refreshed';
    messaging.refresh.add('refreshed');
    await updated.future;
    await c.logout(tokenSession('A'));
    expect(jsonDecode(requests[1].body)['previous_fcm_token'], 'first');
    messaging.token = 'for-B';
    await c.activate(tokenSession('B'));
    final before = requests.length;
    messaging.refresh.add('first');
    await Future<void>.delayed(Duration.zero);
    expect(requests.length, before);
    expect(store.record!.owner, 'B');
    expect(store.record!.token, 'for-B');
    await c.dispose();
    await messaging.refresh.close();
  });
  test(
      'delayed PUT settles before logout DELETE with old bearer; late refresh ignored',
      () async {
    final messaging = Messaging(), store = TokenStore();
    final requests = <http.Request>[];
    final started = Completer<void>(), put = Completer<http.Response>();
    final c = DeviceTokenCoordinator(
        messaging: messaging,
        store: store,
        clearHealth: () {},
        clearNotifications: () async {},
        clientForSession: (session) => ApiClient(
            baseUrl: Uri.parse('http://localhost'),
            authTokenProvider: () async => session.accessToken,
            httpClient: MockClient((r) async {
              requests.add(r);
              if (r.method == 'PUT') {
                started.complete();
                return put.future;
              }
              return http.Response('', 204);
            })));
    final activation = c.activate(tokenSession('A'));
    await started.future;
    final logout = c.logout(tokenSession('A'));
    messaging.refresh.add('stale');
    expect(requests.length, 1);
    put.complete(http.Response('', 204));
    await activation;
    await logout;
    expect(requests.map((r) => r.method), ['PUT', 'DELETE']);
    expect(
        requests.every((r) => r.headers['Authorization'] == 'Bearer bearer-A'),
        true);
    expect(store.record, isNull);
    expect(messaging.deletes, 1);
    await c.dispose();
    await messaging.refresh.close();
  });
  test(
      'failed DELETE retains cleanup; retry and restart rotate before new registration',
      () async {
    final messaging = Messaging(), store = TokenStore();
    var status = 204;
    final c = DeviceTokenCoordinator(
        messaging: messaging,
        store: store,
        clearHealth: () {},
        clearNotifications: () async {},
        clientForSession: (session) => ApiClient(
            baseUrl: Uri.parse('http://localhost'),
            httpClient: MockClient((_) async => http.Response('', status))));
    await c.activate(tokenSession('A'));
    status = 503;
    await expectLater(c.logout(tokenSession('A')), throwsA(isA<Exception>()));
    expect(store.record!.cleanup, true);
    expect(messaging.deletes, 0);
    status = 204;
    await c.logout(tokenSession('A'));
    expect(store.record, isNull);
    store.record = const DeviceTokenRecord('A', 'old', cleanup: true);
    await c.activate(tokenSession('B'));
    expect(messaging.deletes, 2);
    expect(store.record!.owner, 'B');
    await c.dispose();
    await messaging.refresh.close();
  });
  for (final status in [401, 409]) {
    test(
        '$status rotates the old installation without claiming token or recursive DELETE',
        () async {
      final messaging = Messaging(), store = TokenStore();
      final methods = <String>[];
      final c = DeviceTokenCoordinator(
          messaging: messaging,
          store: store,
          clearHealth: () {},
          clearNotifications: () async {},
          clientForSession: (session) => ApiClient(
              baseUrl: Uri.parse('http://localhost'),
              httpClient: MockClient((r) async {
                methods.add(r.method);
                return http.Response('{}', status);
              })));
      await expectLater(
          c.activate(tokenSession('A')), throwsA(isA<Exception>()));
      expect(methods, ['PUT']);
      expect(messaging.deletes, 1);
      expect(store.record, isNull);
      await c.dispose();
      await messaging.refresh.close();
    });
  }
  test('deleteToken failure survives restart and blocks a new user PUT',
      () async {
    final messaging = Messaging()..failDelete = true;
    final store = TokenStore()
      ..record = const DeviceTokenRecord('A', 'old', cleanup: true);
    final c = DeviceTokenCoordinator(
        messaging: messaging,
        store: store,
        clearHealth: () {},
        clearNotifications: () async {},
        clientForSession: (_) => throw StateError('must not PUT'));
    await expectLater(c.activate(tokenSession('B')), throwsStateError);
    expect(store.record!.cleanup, true);
    expect(store.record!.owner, 'A');
    await c.dispose();
    await messaging.refresh.close();
  });
}
