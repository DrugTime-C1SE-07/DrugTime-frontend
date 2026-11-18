import 'package:drugtime_mobile/core/storage/secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// Use a dedicated test device. Run twice with --no-uninstall to retain data:
// flutter test integration_test/secure_storage_restart_test.dart -d <device> --no-uninstall
// Repeat with --dart-define=DRUGTIME_VERIFY_STORED_SESSION=true.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const verify = bool.fromEnvironment('DRUGTIME_VERIFY_STORED_SESSION');
  testWidgets('secure storage persists across Android processes',
      (tester) async {
    final storage = SecureStorage();
    const key = 'secure_storage_restart_probe';
    if (verify) {
      expect(await storage.read(key: key), 'persisted');
      final password = await storage.getOrCreateDatabasePassword();
      expect(await storage.read(key: '${key}_password'), password);
      await storage.delete(key: key);
      await storage.delete(key: '${key}_password');
    } else {
      await storage.write(key: key, value: 'persisted');
      await storage.write(
        key: '${key}_password',
        value: await storage.getOrCreateDatabasePassword(),
      );
      expect(await SecureStorage().read(key: key), 'persisted');
    }
  });
}
