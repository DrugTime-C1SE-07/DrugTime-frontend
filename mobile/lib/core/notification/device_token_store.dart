import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Chỉ lưu metadata vòng đời token trong secure storage, không lưu nội dung cảnh báo.
class DeviceTokenRecord {
  const DeviceTokenRecord(this.owner, this.token,
      {this.cleanup = false, this.previousToken});
  final String owner, token;
  final String? previousToken;
  // Intent bền vững để khởi động sau xử lý tiếp nếu app dừng giữa đăng ký/đăng xuất.
  final bool cleanup;
}

abstract class DeviceTokenStore {
  Future<DeviceTokenRecord?> read();
  Future<void> write(DeviceTokenRecord value);
  Future<void> clear();
}

class SecureDeviceTokenStore implements DeviceTokenStore {
  SecureDeviceTokenStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;
  static const _key = 'family_push_token';
  @override
  Future<DeviceTokenRecord?> read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return null;
    final value = jsonDecode(raw) as Map<String, dynamic>;
    return DeviceTokenRecord(value['owner'] as String, value['token'] as String,
        cleanup: value['cleanup'] as bool,
        previousToken: value['previous_token'] as String?);
  }

  @override
  Future<void> write(DeviceTokenRecord value) => _storage.write(
      key: _key,
      value: jsonEncode({
        'owner': value.owner,
        'token': value.token,
        'cleanup': value.cleanup,
        'previous_token': value.previousToken
      }));
  @override
  Future<void> clear() => _storage.delete(key: _key);
}
