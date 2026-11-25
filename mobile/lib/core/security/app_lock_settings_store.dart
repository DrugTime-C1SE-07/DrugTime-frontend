import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../storage/secure_storage.dart';

/// Nơi lưu cờ bật/tắt "Khóa ứng dụng" theo thiết bị.
abstract interface class AppLockSettingsStore {
  Future<bool> readEnabled();
  Future<void> writeEnabled(bool enabled);
  Future<void> clear();
}

/// Lưu cờ trong Keychain/Keystore, cùng chỗ với phiên đăng nhập.
class SecureAppLockSettingsStore implements AppLockSettingsStore {
  SecureAppLockSettingsStore({FlutterSecureStorage? storage})
      : _storage = SecureStorage(storage: storage);

  static const _key = 'app_lock_enabled_v1';

  final SecureStorage _storage;

  // Giá trị lạ coi như tắt: không khóa người dùng ngoài app vì dữ liệu hỏng.
  @override
  Future<bool> readEnabled() async => await _storage.read(key: _key) == 'true';

  @override
  Future<void> writeEnabled(bool enabled) =>
      _storage.write(key: _key, value: enabled ? 'true' : 'false');

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

/// Bản lưu trong RAM, dùng cho test.
class MemoryAppLockSettingsStore implements AppLockSettingsStore {
  MemoryAppLockSettingsStore([this.enabled = false]);

  bool enabled;

  @override
  Future<bool> readEnabled() async => enabled;

  @override
  Future<void> writeEnabled(bool enabled) async => this.enabled = enabled;

  @override
  Future<void> clear() async => enabled = false;
}
