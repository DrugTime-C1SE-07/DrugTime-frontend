import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  SecureStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _databasePasswordKey = 'encrypted_local_db_password';

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

  String _createStrongPassword() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));

    return base64UrlEncode(bytes);
  }
}
