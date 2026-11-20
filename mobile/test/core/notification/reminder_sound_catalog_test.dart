import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:drugtime_mobile/core/notification/notification_service.dart';
import 'package:drugtime_mobile/core/notification/reminder_sound.dart';

void main() {
  test('built-in catalog has the six S08-4a sounds with stable channels__AC1',
      () {
    expect([
      for (final s in ReminderSounds.all) s.label
    ], [
      'Chuông mặc định',
      'Nhẹ nhàng',
      'Âm cha hữu ơi',
      'Khẩn cấp',
      'Chuông điện thoại mặc định',
      'Im lặng (chỉ rung)',
    ]);
    expect([
      for (final s in ReminderSounds.all) s.channelId
    ], [
      'drugtime_reminder_chime_v1',
      'drugtime_reminder_gentle_v1',
      'drugtime_reminder_friendly_v1',
      'drugtime_reminder_urgent_v1',
      NotificationService.reminderChannelId,
      'drugtime_reminder_silent_v1',
    ]);
    expect(ReminderSounds.fallback, same(ReminderSounds.chime));
    expect(ReminderSounds.builtinById('gentle'), same(ReminderSounds.gentle));
    expect(ReminderSounds.builtinById('custom_x'), isNull);
  });

  test('built-in sound plays its raw resource on a max-importance channel', () {
    final channel = ReminderSounds.gentle.channel;
    expect(channel.importance, Importance.max);
    expect(channel.playSound, isTrue);
    expect((channel.sound! as RawResourceAndroidNotificationSound).sound,
        'reminder_gentle');
    expect(channel.description, NotificationService.reminderChannelDescription);
  });

  test('silent channel has no sound but vibrates__AC8', () {
    final channel = ReminderSounds.silent.channel;
    expect(channel.playSound, isFalse);
    expect(channel.sound, isNull);
    expect(channel.enableVibration, isTrue);
    expect(channel.importance, Importance.max);
  });

  test('system sound keeps the existing reminder channel', () {
    final channel = ReminderSounds.system.channel;
    expect(channel.id, NotificationService.reminderChannelId);
    expect(channel.name, NotificationService.reminderChannelName);
    expect(channel.sound, isNull);
    expect(channel.playSound, isTrue);
  });

  test('custom sound uses its MediaStore uri on its own channel', () {
    const sound = ReminderSound.custom(
        'custom_abc', 'DrugTime nhắc nhở 1', 'content://media/1');
    final channel = sound.channel;
    expect(channel.id, 'drugtime_reminder_custom_abc');
    expect((channel.sound! as UriAndroidNotificationSound).sound,
        'content://media/1');
    expect(channel.importance, Importance.max);
  });
}
