import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:drugtime_mobile/core/notification/reminder_sound_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const custom = CustomReminderSound(
    id: 'custom_1f2e',
    number: 3,
    path: '/data/user/0/app/files/reminder_sounds/custom_1f2e.mp3',
    uri: 'content://media/external/audio/media/42',
  );

  test('defaults to chime when nothing is stored__AC1', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final settings = await SecureReminderSoundStore().read();
    expect(settings.selectedId, 'chime');
    expect(settings.customs, isEmpty);
    expect(settings.fallbackNotice, isFalse);
  });

  test('round-trips selection, customs and fallback notice__AC1', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final store = SecureReminderSoundStore();
    await store.write(const ReminderSoundSettings(
        selectedId: 'custom_1f2e', customs: [custom], fallbackNotice: true));
    final read = await store.read();
    expect(read.selectedId, 'custom_1f2e');
    expect(read.customs.single.toJson(), custom.toJson());
    expect(read.customs.single.sound.label, 'DrugTime nhắc nhở 3');
    expect(read.fallbackNotice, isTrue);
  });

  test('corrupt data falls back to defaults and is removed', () async {
    FlutterSecureStorage.setMockInitialValues(
        {SecureReminderSoundStore.key: '{hỏng'});
    final store = SecureReminderSoundStore();
    expect((await store.read()).selectedId, 'chime');
    expect(
        await const FlutterSecureStorage()
            .read(key: SecureReminderSoundStore.key),
        isNull);
  });

  test('stored data never contains the original file name__AC14', () async {
    FlutterSecureStorage.setMockInitialValues({});
    await SecureReminderSoundStore()
        .write(const ReminderSoundSettings(customs: [custom]));
    final raw = await const FlutterSecureStorage()
        .read(key: SecureReminderSoundStore.key);
    expect(raw, isNot(contains('Thuoc')));
    expect(custom.toJson().keys, ['id', 'number', 'path', 'uri']);
  });

  test('clear removes everything', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final store = SecureReminderSoundStore();
    await store.write(const ReminderSoundSettings(selectedId: 'urgent'));
    await store.clear();
    expect((await store.read()).selectedId, 'chime');
  });
}
