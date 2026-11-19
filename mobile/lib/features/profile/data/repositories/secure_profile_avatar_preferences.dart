import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/utils/app_assets.dart';
import '../../domain/repositories/profile_avatar_preferences.dart';

class SecureProfileAvatarPreferences implements ProfileAvatarPreferences {
  SecureProfileAvatarPreferences({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  String _key(String userId) =>
      'profile_avatar_v1_${base64Url.encode(utf8.encode(userId))}';

  @override
  Future<String?> read(String userId) async {
    final key = _key(userId);
    final path = await _storage.read(key: key);
    if (path == null) return null;
    if (AppAssets.profileAvatars.contains(path)) return path;
    await _storage.delete(key: key);
    return null;
  }

  @override
  Future<void> write(String userId, String assetPath) async {
    if (!AppAssets.profileAvatars.contains(assetPath)) {
      throw ArgumentError('Unknown avatar');
    }
    await _storage.write(key: _key(userId), value: assetPath);
  }
}
