import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:drugtime_mobile/core/notification/notification_service.dart';

enum ReminderSoundKind { builtin, system, silent, custom }

/// Âm thanh nhắc uống thuốc. Mỗi âm một Android channel vì channel không đổi
/// được âm sau khi tạo.
class ReminderSound {
  const ReminderSound._(this.id, this.label, this.kind,
      {this.rawName, this.uri});

  const ReminderSound.builtin(String id, String label, String rawName)
      : this._(id, label, ReminderSoundKind.builtin, rawName: rawName);

  const ReminderSound.custom(String id, String label, String uri)
      : this._(id, label, ReminderSoundKind.custom, uri: uri);

  final String id;
  final String label;
  final ReminderSoundKind kind;

  /// Tên file trong `android/app/src/main/res/raw` (âm có sẵn).
  final String? rawName;

  /// Content uri MediaStore (âm tự thêm).
  final String? uri;

  bool get playsSound => kind != ReminderSoundKind.silent;

  String get channelId => switch (kind) {
        ReminderSoundKind.system => NotificationService.reminderChannelId,
        ReminderSoundKind.custom => 'drugtime_reminder_$id',
        _ => 'drugtime_reminder_${id}_v1',
      };

  String get channelName => kind == ReminderSoundKind.system
      ? NotificationService.reminderChannelName
      : '${NotificationService.reminderChannelName} · $label';

  AndroidNotificationSound? get androidSound => switch (kind) {
        ReminderSoundKind.builtin =>
          RawResourceAndroidNotificationSound(rawName),
        ReminderSoundKind.custom => UriAndroidNotificationSound(uri!),
        _ => null,
      };

  AndroidNotificationChannel get channel => AndroidNotificationChannel(
        channelId,
        channelName,
        description: NotificationService.reminderChannelDescription,
        importance: Importance.max,
        playSound: playsSound,
        sound: androidSound,
        enableVibration: true,
      );
}

abstract final class ReminderSounds {
  static const chime =
      ReminderSound.builtin('chime', 'Chuông mặc định', 'reminder_chime');
  static const gentle =
      ReminderSound.builtin('gentle', 'Nhẹ nhàng', 'reminder_gentle');
  static const friendly =
      ReminderSound.builtin('friendly', 'Âm cha hữu ơi', 'reminder_friendly');
  static const urgent =
      ReminderSound.builtin('urgent', 'Khẩn cấp', 'reminder_urgent');
  static const system = ReminderSound._(
      'system', 'Chuông điện thoại mặc định', ReminderSoundKind.system);
  static const silent =
      ReminderSound._('silent', 'Im lặng (chỉ rung)', ReminderSoundKind.silent);

  static const all = [chime, gentle, friendly, urgent, system, silent];

  /// Mặc định và đích quay về khi âm đã chọn không còn; không bao giờ là [silent].
  static const fallback = chime;

  static ReminderSound? builtinById(String id) {
    for (final sound in all) {
      if (sound.id == id) return sound;
    }
    return null;
  }
}
