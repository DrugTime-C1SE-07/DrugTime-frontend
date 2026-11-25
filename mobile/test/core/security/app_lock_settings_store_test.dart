import 'package:drugtime_mobile/core/security/app_lock_settings_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('defaults to disabled', () async {
    expect(await SecureAppLockSettingsStore().readEnabled(), isFalse);
  });

  test('persists enabled across instances and clears back to disabled',
      () async {
    await SecureAppLockSettingsStore().writeEnabled(true);
    expect(await SecureAppLockSettingsStore().readEnabled(), isTrue);

    await SecureAppLockSettingsStore().clear();
    expect(await SecureAppLockSettingsStore().readEnabled(), isFalse);
  });

  test('treats a corrupted value as disabled', () async {
    FlutterSecureStorage.setMockInitialValues({'app_lock_enabled_v1': 'yes?'});
    expect(await SecureAppLockSettingsStore().readEnabled(), isFalse);
  });
}
