import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/entities/auth_session.dart';

/// Nơi lưu phiên đăng nhập giữa các lần mở app.
abstract interface class AuthSessionStore {
  Future<AuthSession?> read();
  Future<void> write(AuthSession session);
  Future<void> clear();
}

/// Lưu phiên trong Keychain/Keystore qua flutter_secure_storage (token không nằm ở bộ nhớ thường).
class SecureAuthSessionStore implements AuthSessionStore {
  SecureAuthSessionStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage(),
        _useAndroidStore = storage == null &&
            !kIsWeb &&
            defaultTargetPlatform == TargetPlatform.android;

  static const _key = 'auth_session_v1';
  static const _androidStore = MethodChannel('vn.drugtime/session_store');

  final FlutterSecureStorage _storage;
  final bool _useAndroidStore;

  @override
  Future<AuthSession?> read() async {
    final raw = _useAndroidStore
        ? await _androidStore.invokeMethod<String>('read')
        : await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) return null;
    try {
      return AuthSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on FormatException {
      // Dữ liệu hỏng: coi như chưa đăng nhập và xóa để lần sau không đọc lại.
      await clear();
      return null;
    }
  }

  @override
  Future<void> write(AuthSession session) {
    final json = jsonEncode(session.toJson());
    return _useAndroidStore
        ? _androidStore.invokeMethod<void>('write', json)
        : _storage.write(key: _key, value: json);
  }

  @override
  Future<void> clear() => _useAndroidStore
      ? _androidStore.invokeMethod<void>('clear')
      : _storage.delete(key: _key);
}

/// Bản lưu trong RAM, dùng cho test.
class MemoryAuthSessionStore implements AuthSessionStore {
  MemoryAuthSessionStore([this.session]);

  AuthSession? session;

  @override
  Future<AuthSession?> read() async => session;

  @override
  Future<void> write(AuthSession session) async => this.session = session;

  @override
  Future<void> clear() async => session = null;
}
