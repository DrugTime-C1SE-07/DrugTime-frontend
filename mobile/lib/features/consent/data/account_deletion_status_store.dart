import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/storage/secure_storage.dart';
import 'account_deletion_repository.dart';

/// Trạng thái xóa tài khoản đã xác minh gần nhất từ server cho một `userId`.
///
/// Chỉ dùng để quyết định có được phép mở app ngoại tuyến hay không khi mất mạng;
/// không thay thế kiểm tra PEP của server khi có mạng.
class CachedDeletionStatus {
  const CachedDeletionStatus({
    required this.pending,
    required this.verifiedAt,
  });

  final PendingAccountDeletion? pending;
  final DateTime verifiedAt;

  Map<String, Object?> toJson() => {
        'verified_at': verifiedAt.toUtc().toIso8601String(),
        'pending': pending == null
            ? null
            : {
                'requested_at': pending!.requestedAt.toUtc().toIso8601String(),
                'scheduled_deletion_at':
                    pending!.scheduledAt.toUtc().toIso8601String(),
              },
      };

  static CachedDeletionStatus? tryFromJson(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final verifiedRaw = decoded['verified_at'];
      if (verifiedRaw is! String) return null;
      final verifiedAt = DateTime.tryParse(verifiedRaw);
      if (verifiedAt == null) return null;
      final pendingRaw = decoded['pending'];
      PendingAccountDeletion? pending;
      if (pendingRaw != null) {
        if (pendingRaw is! Map<String, dynamic>) return null;
        pending = PendingAccountDeletion.fromJson(pendingRaw);
      }
      return CachedDeletionStatus(pending: pending, verifiedAt: verifiedAt);
    } catch (_) {
      return null;
    }
  }
}

abstract class AccountDeletionStatusStore {
  Future<CachedDeletionStatus?> read(String userId);

  Future<void> write(
    String userId, {
    required PendingAccountDeletion? pending,
    required DateTime verifiedAt,
  });

  Future<void> clear(String userId);

  Future<void> clearAll();
}

/// Lưu trạng thái xóa mã hóa theo từng `userId` trong [SecureStorage] (QD-19).
class SecureAccountDeletionStatusStore implements AccountDeletionStatusStore {
  SecureAccountDeletionStatusStore(this._storage);

  final SecureStorage _storage;

  static const _indexKey = 'account_deletion_status_users_v1';
  static String _keyFor(String userId) => 'account_deletion_status_v1_$userId';

  @override
  Future<CachedDeletionStatus?> read(String userId) async {
    if (userId.isEmpty) return null;
    try {
      final raw = await _storage.read(key: _keyFor(userId));
      if (raw == null || raw.isEmpty) return null;
      return CachedDeletionStatus.tryFromJson(raw);
    } catch (error) {
      debugPrint(
        'SecureAccountDeletionStatusStore.read failed: ${error.runtimeType}',
      );
      return null;
    }
  }

  @override
  Future<void> write(
    String userId, {
    required PendingAccountDeletion? pending,
    required DateTime verifiedAt,
  }) async {
    if (userId.isEmpty) return;
    final status =
        CachedDeletionStatus(pending: pending, verifiedAt: verifiedAt);
    try {
      await _storage.write(
        key: _keyFor(userId),
        value: jsonEncode(status.toJson()),
      );
      final users = await _readIndex();
      if (users.add(userId)) {
        await _storage.write(key: _indexKey, value: jsonEncode(users.toList()));
      }
    } catch (error) {
      debugPrint(
        'SecureAccountDeletionStatusStore.write failed: ${error.runtimeType}',
      );
    }
  }

  @override
  Future<void> clear(String userId) async {
    if (userId.isEmpty) return;
    try {
      await _storage.delete(key: _keyFor(userId));
      final users = await _readIndex();
      if (users.remove(userId)) {
        if (users.isEmpty) {
          await _storage.delete(key: _indexKey);
        } else {
          await _storage.write(
              key: _indexKey, value: jsonEncode(users.toList()));
        }
      }
    } catch (error) {
      debugPrint(
        'SecureAccountDeletionStatusStore.clear failed: ${error.runtimeType}',
      );
    }
  }

  @override
  Future<void> clearAll() async {
    try {
      final users = await _readIndex();
      for (final userId in users) {
        await _storage.delete(key: _keyFor(userId));
      }
      await _storage.delete(key: _indexKey);
    } catch (error) {
      debugPrint(
        'SecureAccountDeletionStatusStore.clearAll failed: ${error.runtimeType}',
      );
    }
  }

  Future<Set<String>> _readIndex() async {
    try {
      final raw = await _storage.read(key: _indexKey);
      if (raw == null || raw.isEmpty) return <String>{};
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.whereType<String>().toSet();
      }
    } catch (error) {
      debugPrint(
        'SecureAccountDeletionStatusStore._readIndex failed: ${error.runtimeType}',
      );
    }
    return <String>{};
  }
}

class InMemoryAccountDeletionStatusStore implements AccountDeletionStatusStore {
  final Map<String, CachedDeletionStatus> _items = {};

  @override
  Future<CachedDeletionStatus?> read(String userId) async => _items[userId];

  @override
  Future<void> write(
    String userId, {
    required PendingAccountDeletion? pending,
    required DateTime verifiedAt,
  }) async {
    if (userId.isEmpty) return;
    _items[userId] =
        CachedDeletionStatus(pending: pending, verifiedAt: verifiedAt);
  }

  @override
  Future<void> clear(String userId) async {
    _items.remove(userId);
  }

  @override
  Future<void> clearAll() async {
    _items.clear();
  }
}
