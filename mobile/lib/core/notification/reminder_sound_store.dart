import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:drugtime_mobile/core/notification/reminder_sound.dart';

/// Âm thanh người dùng thêm. Không lưu tên file gốc (AC14).
class CustomReminderSound {
  const CustomReminderSound({
    required this.id,
    required this.number,
    required this.path,
    required this.uri,
  });

  final String id;
  final int number;
  final String path;
  final String uri;

  ReminderSound get sound =>
      ReminderSound.custom(id, 'DrugTime nhắc nhở $number', uri);

  Map<String, Object> toJson() =>
      {'id': id, 'number': number, 'path': path, 'uri': uri};

  static CustomReminderSound fromJson(Map<String, dynamic> json) =>
      CustomReminderSound(
        id: json['id'] as String,
        number: json['number'] as int,
        path: json['path'] as String,
        uri: json['uri'] as String,
      );
}

class ReminderSoundSettings {
  const ReminderSoundSettings({
    this.selectedId = 'chime',
    this.customs = const [],
    this.fallbackNotice = false,
  });

  final String selectedId;
  final List<CustomReminderSound> customs;

  /// Âm đã chọn từng bị mất và app đã quay về chuông mặc định (AC7).
  final bool fallbackNotice;

  ReminderSoundSettings copyWith({
    String? selectedId,
    List<CustomReminderSound>? customs,
    bool? fallbackNotice,
  }) =>
      ReminderSoundSettings(
        selectedId: selectedId ?? this.selectedId,
        customs: customs ?? this.customs,
        fallbackNotice: fallbackNotice ?? this.fallbackNotice,
      );
}

abstract class ReminderSoundStore {
  Future<ReminderSoundSettings> read();
  Future<void> write(ReminderSoundSettings settings);
  Future<void> clear();
}

/// Lưu theo thiết bị (bị xóa khi đăng xuất), nên không khóa theo user.
class SecureReminderSoundStore implements ReminderSoundStore {
  SecureReminderSoundStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const key = 'reminder_sound_v1';
  final FlutterSecureStorage _storage;

  @override
  Future<ReminderSoundSettings> read() async {
    final raw = await _storage.read(key: key);
    if (raw == null) return const ReminderSoundSettings();
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return ReminderSoundSettings(
        selectedId: json['selected'] as String,
        customs: [
          for (final item in json['customs'] as List)
            CustomReminderSound.fromJson(item as Map<String, dynamic>),
        ],
        fallbackNotice: json['fallbackNotice'] as bool? ?? false,
      );
    } on Object {
      // Dữ liệu hỏng: về mặc định thay vì để nhắc thuốc mất âm.
      await _storage.delete(key: key);
      return const ReminderSoundSettings();
    }
  }

  @override
  Future<void> write(ReminderSoundSettings settings) => _storage.write(
        key: key,
        value: jsonEncode({
          'selected': settings.selectedId,
          'customs': [for (final c in settings.customs) c.toJson()],
          'fallbackNotice': settings.fallbackNotice,
        }),
      );

  @override
  Future<void> clear() => _storage.delete(key: key);
}
