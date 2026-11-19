import 'package:drugtime_mobile/core/storage/secure_storage.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('migration retries safely, preserves keys, and does not restore logout',
      () async {
    const channel =
        MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    final legacy = {
      'auth_session_v1': 'old-session',
      'encrypted_local_db_password': 'existing-password',
      'family_push_token': 'old-token',
    };
    final current = {'family_push_token': 'new-token'};
    var failOnce = true;
    var legacyReads = 0;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      final args = Map<String, dynamic>.from(call.arguments as Map);
      final options = Map<String, dynamic>.from(args['options'] as Map);
      expect(options['resetOnError'], 'false');
      final isLegacy = options['storageNamespace'] != 'drugtime_secure_aes_v1';
      final data = isLegacy ? legacy : current;
      final key = args['key'] as String?;
      switch (call.method) {
        case 'readAll':
          legacyReads++;
          if (failOnce) {
            failOnce = false;
            throw PlatformException(code: 'temporarily_unavailable');
          }
          return Map<String, String>.from(data);
        case 'read':
          return data[key];
        case 'write':
          expect(isLegacy, isFalse);
          data[key!] = args['value'] as String;
          return null;
        case 'delete':
          expect(isLegacy, isFalse);
          data.remove(key);
          return null;
      }
      throw StateError('Unexpected method: ${call.method}');
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    final storage = SecureStorage();
    await expectLater(
      storage.read(key: 'auth_session_v1'),
      throwsA(isA<PlatformException>()),
    );
    final values = await Future.wait([
      storage.read(key: 'auth_session_v1'),
      SecureStorage().getOrCreateDatabasePassword(),
      storage.read(key: 'family_push_token'),
    ]);
    expect(values, ['old-session', 'existing-password', 'new-token']);
    expect(legacyReads, 2); // One failed attempt, then one shared migration.
    expect(legacy['auth_session_v1'], 'old-session');

    await storage.delete(key: 'auth_session_v1');
    expect(await SecureStorage().read(key: 'auth_session_v1'), isNull);
    expect(legacyReads, 2);
  });
}
