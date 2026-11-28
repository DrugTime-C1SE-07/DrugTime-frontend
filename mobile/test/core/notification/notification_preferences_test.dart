import 'package:drugtime_mobile/core/notification/notification_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TC-606-01..02 ReminderPreferences defaults, repeatDelay & low_stock', () {
    test('TC-606-01: defaults are all true and repeatDelay is 10 minutes (QD-20, AC12)', () {
      const prefs = ReminderPreferences();
      expect(ReminderPreferences.repeatDelay, const Duration(minutes: 10));
      expect(prefs.enabled, isTrue);
      expect(prefs.vibrate, isTrue);
      expect(prefs.repeatIfMissed, isTrue);
      expect(prefs.toJson(), {
        'enabled': true,
        'vibrate': true,
        'repeat': true,
        'low_stock': true,
      });
    });

    test('TC-606-02: low_stock round-trips and defaults to true when missing', () {
      final disabled = ReminderPreferences.fromJson({
        'enabled': true,
        'vibrate': false,
        'repeat': true,
        'low_stock': false,
      });
      expect(disabled.vibrate, isFalse);
      expect(disabled.repeatIfMissed, isTrue);
      expect(disabled.toJson()['low_stock'], isFalse);

      final legacy = ReminderPreferences.fromJson({'enabled': true, 'vibrate': true});
      expect(legacy.repeatIfMissed, isTrue);
      expect(legacy.toJson()['low_stock'], isTrue);
    });
  });

  group('TC-606-03..04 SecureReminderPreferencesStore & Controller lifecycle', () {
    test('TC-606-03: read default, write/read, recover corrupt JSON, and clear', () async {
      FlutterSecureStorage.setMockInitialValues({});
      final store = SecureReminderPreferencesStore();
      expect(await store.read(), const ReminderPreferences());

      final custom = ReminderPreferences.fromJson({
        'enabled': false,
        'vibrate': false,
        'repeat': false,
        'low_stock': false,
      });
      await store.write(custom);
      expect(await store.read(), custom);

      FlutterSecureStorage.setMockInitialValues({
        SecureReminderPreferencesStore.key: '{corrupt-json',
      });
      expect(await store.read(), const ReminderPreferences());
      expect(
        await const FlutterSecureStorage().read(key: SecureReminderPreferencesStore.key),
        isNull,
      );

      await store.write(custom);
      await store.clear();
      expect(await store.read(), const ReminderPreferences());
    });

    test('TC-606-04: NotificationPreferencesController only fires onRemindersChanged when changed', () async {
      FlutterSecureStorage.setMockInitialValues({});
      final controller = NotificationPreferencesController(
        store: SecureReminderPreferencesStore(),
      );
      var changes = 0;
      controller.onRemindersChanged = () => changes++;

      await controller.load();
      expect(controller.reminders, const ReminderPreferences());

      await controller.save(reminders: const ReminderPreferences());
      expect(changes, 0);

      await controller.save(reminders: const ReminderPreferences(vibrate: false));
      expect(changes, 1);

      await controller.clear();
      expect(controller.reminders, const ReminderPreferences());
    });
  });
}
