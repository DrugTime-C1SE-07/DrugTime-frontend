import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  SecureStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? _deviceStorage,
        _injected = storage != null;

  // ponytail: RSA OAEP fails across restarts on some Android KeyStores. Keep
  // the AES-backed v10 backend until the upstream RSA path supports them.
  static const _deviceStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      storageNamespace: 'drugtime_secure_aes_v1',
      // ignore: deprecated_member_use
      encryptedSharedPreferences: true,
      migrateOnAlgorithmChange: false,
      resetOnError: false,
    ),
  );
  static const _legacyStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: false),
  );
  static const _migrationKey = 'legacy_storage_migrated_v1';
  static Future<void>? _migration;

  static const _databasePasswordKey = 'encrypted_local_db_password';
  static const _reminderPermissionsAskedKey = 'reminder_permissions_asked';

  final FlutterSecureStorage _storage;
  final bool _injected;

  Future<void> _ready() async {
    if (_injected ||
        kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    try {
      await (_migration ??= _migrateLegacy());
    } catch (_) {
      _migration = null;
      rethrow;
    }
  }

  static Future<void> _migrateLegacy() async {
    if (await _deviceStorage.read(key: _migrationKey) != null) return;
    Map<String, String> values;
    try {
      values = await _legacyStorage.readAll();
    } on PlatformException catch (error) {
      // Leave unreadable legacy files intact, rather than deleting user data.
      final message = error.message ?? '';
      if (!message.contains('Migration failed after algorithm change') &&
          !message.contains('Key mismatch after algorithm change')) {
        rethrow;
      }
      debugPrint('Không đọc được khóa kho cũ; giữ nguyên dữ liệu mã hóa cũ.');
      values = {};
    }
    for (final entry in values.entries) {
      // Retrying an interrupted migration must not overwrite newer values.
      if (await _deviceStorage.read(key: entry.key) == null) {
        await _deviceStorage.write(key: entry.key, value: entry.value);
      }
    }
    await _deviceStorage.write(key: _migrationKey, value: '1');
  }

  Future<String?> read({required String key}) async {
    await _ready();
    return _storage.read(key: key);
  }

  Future<void> write({required String key, required String value}) async {
    await _ready();
    await _storage.write(key: key, value: value);
  }

  Future<void> delete({required String key}) async {
    await _ready();
    await _storage.delete(key: key);
  }

  Future<String> getOrCreateDatabasePassword() async {
    final currentPassword = await read(key: _databasePasswordKey);
    if (currentPassword != null && currentPassword.isNotEmpty) {
      return currentPassword;
    }

    final newPassword = _createStrongPassword();
    await write(key: _databasePasswordKey, value: newPassword);

    return newPassword;
  }

  /// `true` ở lần gọi đầu tiên sau khi cài app, các lần sau `false`.
  Future<bool> markReminderPermissionsAsked() async {
    if (await read(key: _reminderPermissionsAskedKey) != null) {
      return false;
    }
    await write(key: _reminderPermissionsAskedKey, value: '1');
    return true;
  }

  String _createStrongPassword() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));

    return base64UrlEncode(bytes);
  }
}
