import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/core/storage/secure_storage.dart';

void main() {
  test('markReminderPermissionsAsked is true only on the first call', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final storage = SecureStorage();

    expect(await storage.markReminderPermissionsAsked(), isTrue);
    expect(await storage.markReminderPermissionsAsked(), isFalse);
    // Instance mới (mở lại app) vẫn đọc được cờ đã lưu.
    expect(await SecureStorage().markReminderPermissionsAsked(), isFalse);
  });
}
