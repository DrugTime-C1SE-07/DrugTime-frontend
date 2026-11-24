import 'package:drugtime_mobile/core/storage/secure_storage.dart';
import 'package:drugtime_mobile/features/consent/data/account_deletion_repository.dart';
import 'package:drugtime_mobile/features/consent/data/account_deletion_status_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSecureStorage extends SecureStorage {
  final Map<String, String> values = {};

  @override
  Future<String?> read({required String key}) async => values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    values.remove(key);
  }
}

void main() {
  test('lưu và đọc trạng thái null và pending tách biệt theo userId (QD-19)',
      () async {
    final storage = _FakeSecureStorage();
    final store = SecureAccountDeletionStatusStore(storage);
    final verifiedAt = DateTime.utc(2026, 11, 22, 10, 0);
    final pending = PendingAccountDeletion(
      DateTime.utc(2026, 11, 20, 8, 0),
      DateTime.utc(2026, 12, 20, 8, 0),
    );

    expect(await store.read('user-a'), isNull);

    await store.write('user-a', pending: null, verifiedAt: verifiedAt);
    await store.write('user-b', pending: pending, verifiedAt: verifiedAt);

    final statusA = await store.read('user-a');
    final statusB = await store.read('user-b');
    expect(statusA, isNotNull);
    expect(statusA!.pending, isNull);
    expect(statusA.verifiedAt, verifiedAt);

    expect(statusB, isNotNull);
    expect(statusB!.pending, isNotNull);
    expect(statusB.pending!.requestedAt, pending.requestedAt);
    expect(statusB.pending!.scheduledAt, pending.scheduledAt);
  });

  test('clear chỉ xóa đúng userId, clearAll xóa toàn bộ', () async {
    final storage = _FakeSecureStorage();
    final store = SecureAccountDeletionStatusStore(storage);
    final now = DateTime.utc(2026, 11, 22, 10, 0);

    await store.write('user-a', pending: null, verifiedAt: now);
    await store.write('user-b', pending: null, verifiedAt: now);

    await store.clear('user-a');
    expect(await store.read('user-a'), isNull);
    expect(await store.read('user-b'), isNotNull);

    await store.clearAll();
    expect(await store.read('user-b'), isNull);
  });

  test('trả null an toàn khi dữ liệu lưu trữ bị hỏng JSON', () async {
    final storage = _FakeSecureStorage();
    storage.values['account_deletion_status_v1_user-a'] = '{broken-json';
    final store = SecureAccountDeletionStatusStore(storage);

    expect(await store.read('user-a'), isNull);
  });

  test('bắt PlatformException từ SecureStorage an toàn (fail-closed khi đọc)',
      () async {
    final storage = _ThrowingSecureStorage();
    final store = SecureAccountDeletionStatusStore(storage);
    final now = DateTime.utc(2026, 11, 22, 10, 0);

    expect(await store.read('user-a'), isNull);
    await expectLater(
      store.write('user-a', pending: null, verifiedAt: now),
      completes,
    );
    await expectLater(store.clear('user-a'), completes);
    await expectLater(store.clearAll(), completes);
  });
}

class _ThrowingSecureStorage extends SecureStorage {
  @override
  Future<String?> read({required String key}) async {
    throw PlatformException(code: 'keystore_error', message: 'Keystore locked');
  }

  @override
  Future<void> write({required String key, required String value}) async {
    throw PlatformException(code: 'keystore_error', message: 'Keystore locked');
  }

  @override
  Future<void> delete({required String key}) async {
    throw PlatformException(code: 'keystore_error', message: 'Keystore locked');
  }
}
