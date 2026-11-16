import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  SecureStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _databasePasswordKey = 'encrypted_local_db_password';
  static const _reminderPermissionsAskedKey = 'reminder_permissions_asked';

  final FlutterSecureStorage _storage;

  Future<String> getOrCreateDatabasePassword() async {
    final currentPassword = await _storage.read(key: _databasePasswordKey);
    if (currentPassword != null && currentPassword.isNotEmpty) {
      return currentPassword;
    }

    final newPassword = _createStrongPassword();
    await _storage.write(key: _databasePasswordKey, value: newPassword);

    return newPassword;
  }

  /// `true` ở lần gọi đầu tiên sau khi cài app, các lần sau `false`.
  Future<bool> markReminderPermissionsAsked() async {
    if (await _storage.read(key: _reminderPermissionsAskedKey) != null) {
      return false;
    }
    await _storage.write(key: _reminderPermissionsAskedKey, value: '1');
    return true;
  }

  String _createStrongPassword() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));

    return base64UrlEncode(bytes);
  }
}
