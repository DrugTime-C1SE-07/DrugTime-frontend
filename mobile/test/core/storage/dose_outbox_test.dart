import 'dart:async';
import 'dart:io';

import 'package:drugtime_mobile/core/storage/local_db/local_db.dart';
import 'package:drugtime_mobile/core/storage/local_db/local_medication_store.dart';
import 'package:drugtime_mobile/core/storage/local_db/local_models.dart';
import 'package:drugtime_mobile/core/storage/local_db/sqlite_dose_outbox.dart';
import 'package:drugtime_mobile/core/sync/sync_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late SqliteDoseOutbox outbox;

  Future<void> seedSchedule(Database targetDb, {int id = 101}) async {
    await targetDb.insert(
      LocalDb.schedulesTable,
      {
        'id': id,
        'patient_user_id': 'patient-001',
        'user_medication_id': 201,
        'medication_id': 301,
        'medication_name': 'Panadol',
        'strength_text': '500mg',
        'dosage_form': 'Viên',
        'quantity_per_dose': '1',
        'doses_per_day': 1,
        'intake_time': '08:00:00',
        'days_of_week': '1,2,3,4,5,6,7',
        'reminder_enabled': 1,
        'effective_from': '2026-10-01T00:00:00.000Z',
        'ended_at': null,
        'server_synced_at': '2026-10-01T00:00:00.000Z',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  setUp(() async {
    db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: LocalDb.createSchema,
      ),
    );
    await seedSchedule(db);
    outbox = SqliteDoseOutbox(getDatabase: () async => db);
  });

  tearDown(() async {
    await outbox.dispose();
    await db.close();
  });

  group('SqliteDoseOutbox — enqueue & Idempotency', () {
    test('enqueue tạo bản ghi mới với trạng thái pending_upload', () async {
      final scheduledAt = DateTime.utc(2026, 10, 5, 8, 0);
      final takenAt = DateTime.utc(2026, 10, 5, 8, 2);

      final record = await outbox.enqueue(
        medicationScheduleId: 101,
        scheduledAt: scheduledAt,
        takenAt: takenAt,
      );

      expect(record.clientUuid, isNotEmpty);
      expect(record.medicationScheduleId, 101);
      expect(record.scheduledAt, scheduledAt);
      expect(record.takenAt, takenAt);
      expect(record.syncState, DoseLogSyncState.pendingUpload);

      final pending = await outbox.getPendingLogs();
      expect(pending, hasLength(1));
      expect(pending.first.clientUuid, record.clientUuid);
    });

    test(
        'enqueue lần 2 cho cùng lượt uống bảo toàn nguyên vẹn taken_at và client_uuid',
        () async {
      final scheduledAt = DateTime.utc(2026, 10, 5, 8, 0);
      final initialTakenAt = DateTime.utc(2026, 10, 5, 8, 2);
      final secondTakenAt = DateTime.utc(2026, 10, 5, 8, 15);

      final firstRecord = await outbox.enqueue(
        medicationScheduleId: 101,
        scheduledAt: scheduledAt,
        takenAt: initialTakenAt,
      );

      final secondRecord = await outbox.enqueue(
        medicationScheduleId: 101,
        scheduledAt: scheduledAt,
        takenAt: secondTakenAt,
      );

      expect(secondRecord.clientUuid, firstRecord.clientUuid);
      expect(secondRecord.takenAt, initialTakenAt); // KHÔNG bị ghi đè!

      final rows = await db.query(LocalDb.doseLogsTable);
      expect(rows, hasLength(1));
    });

    test(
        'enqueue song song (Future.wait) trên cùng kết nối chỉ tạo duy nhất 1 dòng',
        () async {
      final scheduledAt = DateTime.utc(2026, 10, 5, 12, 0);

      final results = await Future.wait([
        outbox.enqueue(
          medicationScheduleId: 101,
          scheduledAt: scheduledAt,
          takenAt: DateTime.utc(2026, 10, 5, 12, 1),
        ),
        outbox.enqueue(
          medicationScheduleId: 101,
          scheduledAt: scheduledAt,
          takenAt: DateTime.utc(2026, 10, 5, 12, 2),
        ),
      ]);

      expect(results[0].clientUuid, results[1].clientUuid);

      final rows = await db.query(LocalDb.doseLogsTable);
      expect(rows, hasLength(1));
    });

    test('enqueue chuẩn hóa múi giờ sang UTC chống trùng lặp chuỗi', () async {
      // 08:00:00+07:00 tương đương 01:00:00Z
      final localTime = DateTime.parse('2026-10-05T08:00:00+07:00');
      final utcTime = DateTime.parse('2026-10-05T01:00:00Z');

      final r1 = await outbox.enqueue(
        medicationScheduleId: 101,
        scheduledAt: localTime,
        takenAt: localTime,
      );

      final r2 = await outbox.enqueue(
        medicationScheduleId: 101,
        scheduledAt: utcTime,
        takenAt: utcTime,
      );

      expect(r1.clientUuid, r2.clientUuid);
      final rows = await db.query(LocalDb.doseLogsTable);
      expect(rows, hasLength(1));
    });

    test('Đua lệnh đa kết nối (Multi-connection isolate simulation)', () async {
      final tempDir =
          await Directory.systemTemp.createTemp('drugtime_race_test_');
      final dbPath = path.join(tempDir.path, 'race.db');

      try {
        final db1 = await databaseFactory.openDatabase(
          dbPath,
          options: OpenDatabaseOptions(
            version: 1,
            onCreate: LocalDb.createSchema,
            singleInstance: false,
          ),
        );
        await db1.execute('PRAGMA busy_timeout = 5000;');
        await seedSchedule(db1);

        final db2 = await databaseFactory.openDatabase(
          dbPath,
          options: OpenDatabaseOptions(
            version: 1,
            singleInstance: false,
          ),
        );
        await db2.execute('PRAGMA busy_timeout = 5000;');

        final outbox1 = SqliteDoseOutbox(getDatabase: () async => db1);
        final outbox2 = SqliteDoseOutbox(getDatabase: () async => db2);

        final scheduledAt = DateTime.utc(2026, 10, 5, 20, 0);

        final results = await Future.wait([
          outbox1.enqueue(
            medicationScheduleId: 101,
            scheduledAt: scheduledAt,
            takenAt: DateTime.utc(2026, 10, 5, 20, 1),
          ),
          outbox2.enqueue(
            medicationScheduleId: 101,
            scheduledAt: scheduledAt,
            takenAt: DateTime.utc(2026, 10, 5, 20, 2),
          ),
        ]);

        expect(results[0].clientUuid, results[1].clientUuid);

        final rows = await db1.query(LocalDb.doseLogsTable);
        expect(rows, hasLength(1));

        await outbox1.dispose();
        await outbox2.dispose();
        await db1.close();
        await db2.close();
      } finally {
        await tempDir.delete(recursive: true);
      }
    });
  });

  group('SqliteDoseOutbox — markSynced & markFailed', () {
    test('markSynced cập nhật id, synced_at và phát stream synced', () async {
      final record = await outbox.enqueue(
        medicationScheduleId: 101,
        scheduledAt: DateTime.utc(2026, 10, 5, 8, 0),
        takenAt: DateTime.utc(2026, 10, 5, 8, 1),
      );

      final emitted = <DoseLogSyncState?>[];
      final sub = outbox.watchStatus(record.clientUuid).listen(emitted.add);

      await Future<void>.delayed(const Duration(milliseconds: 20));

      await outbox.markSynced(
        clientUuid: record.clientUuid,
        serverId: 999,
        syncedAt: DateTime.utc(2026, 10, 5, 8, 5),
      );

      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(
          emitted, [DoseLogSyncState.pendingUpload, DoseLogSyncState.synced]);

      final rows = await db.query(
        LocalDb.doseLogsTable,
        where: 'client_uuid = ?',
        whereArgs: [record.clientUuid],
      );
      expect(rows.first['sync_state'], 'synced');
      expect(rows.first['id'], 999);
      expect(rows.first['synced_at'], '2026-10-05T08:05:00.000Z');

      await sub.cancel();
    });

    test('markSynced với serverId null không làm mất id đã có (COALESCE)',
        () async {
      final record = await outbox.enqueue(
        medicationScheduleId: 101,
        scheduledAt: DateTime.utc(2026, 10, 5, 8, 0),
        takenAt: DateTime.utc(2026, 10, 5, 8, 1),
      );

      await outbox.markSynced(
        clientUuid: record.clientUuid,
        serverId: 777,
        syncedAt: DateTime.utc(2026, 10, 5, 8, 5),
      );

      // Gọi lần 2 với serverId null
      await outbox.markSynced(
        clientUuid: record.clientUuid,
        serverId: null,
        syncedAt: DateTime.utc(2026, 10, 5, 8, 6),
      );

      final rows = await db.query(
        LocalDb.doseLogsTable,
        where: 'client_uuid = ?',
        whereArgs: [record.clientUuid],
      );
      expect(rows.first['id'], 777); // Vẫn bảo toàn id=777!
    });

    test('markSynced lần 2 không phát lại sự kiện lặp', () async {
      final record = await outbox.enqueue(
        medicationScheduleId: 101,
        scheduledAt: DateTime.utc(2026, 10, 5, 8, 0),
        takenAt: DateTime.utc(2026, 10, 5, 8, 1),
      );

      await outbox.markSynced(
        clientUuid: record.clientUuid,
        serverId: 1,
        syncedAt: DateTime.utc(2026, 10, 5, 8, 5),
      );

      final emitted = <DoseLogSyncState?>[];
      final sub = outbox.watchStatus(record.clientUuid).listen(emitted.add);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Gọi lại markSynced khi đã synced
      await outbox.markSynced(
        clientUuid: record.clientUuid,
        serverId: 1,
        syncedAt: DateTime.utc(2026, 10, 5, 8, 6),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Chỉ có 1 giá trị ban đầu, không có sự kiện mới
      expect(emitted, [DoseLogSyncState.synced]);

      await sub.cancel();
    });

    test('Bản ghi đã synced không bị markFailed ghi đè', () async {
      final record = await outbox.enqueue(
        medicationScheduleId: 101,
        scheduledAt: DateTime.utc(2026, 10, 5, 8, 0),
        takenAt: DateTime.utc(2026, 10, 5, 8, 1),
      );

      await outbox.markSynced(
        clientUuid: record.clientUuid,
        serverId: 10,
        syncedAt: DateTime.utc(2026, 10, 5, 8, 5),
      );

      // Cố ý gọi markFailed sau khi đã synced
      await outbox.markFailed(
        clientUuid: record.clientUuid,
        errorMessage: 'Late failure network error',
      );

      final rows = await db.query(
        LocalDb.doseLogsTable,
        where: 'client_uuid = ?',
        whereArgs: [record.clientUuid],
      );
      expect(rows.first['sync_state'], 'synced'); // Giữ nguyên synced!
    });

    test('Bản ghi failed có thể chuyển sang synced khi server nhận thành công',
        () async {
      final record = await outbox.enqueue(
        medicationScheduleId: 101,
        scheduledAt: DateTime.utc(2026, 10, 5, 8, 0),
        takenAt: DateTime.utc(2026, 10, 5, 8, 1),
      );

      await outbox.markFailed(
        clientUuid: record.clientUuid,
        errorMessage: 'Initial failure',
      );

      expect((await outbox.getPendingLogs()), isEmpty);

      await outbox.markSynced(
        clientUuid: record.clientUuid,
        serverId: 888,
        syncedAt: DateTime.utc(2026, 10, 5, 8, 10),
      );

      final rows = await db.query(
        LocalDb.doseLogsTable,
        where: 'client_uuid = ?',
        whereArgs: [record.clientUuid],
      );
      expect(rows.first['sync_state'], 'synced');
      expect(rows.first['id'], 888);
    });

    test(
        'markSynced và markFailed với clientUuid không tồn tại không lỗi và không phát stream',
        () async {
      final emitted = <DoseLogSyncState?>[];
      final sub = outbox.watchStatus('non-existent-uuid').listen(emitted.add);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      await outbox.markSynced(
        clientUuid: 'non-existent-uuid',
        serverId: 1,
        syncedAt: DateTime.now().toUtc(),
      );

      await outbox.markFailed(
        clientUuid: 'non-existent-uuid',
        errorMessage: 'error',
      );

      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(emitted, [null]); // Chỉ có emit khởi tạo ban đầu
      await sub.cancel();
    });
  });

  group('SqliteDoseOutbox — watchStatus & Lifecycle', () {
    test('watchStatus emit null cho UUID chưa từng tồn tại', () async {
      final state = await outbox.watchStatus('random-uuid').first;
      expect(state, isNull);
    });

    test(
        'watchStatus phát sự kiện đúng clientUuid và không bị ảnh hưởng bởi UUID khác',
        () async {
      final r1 = await outbox.enqueue(
        medicationScheduleId: 101,
        scheduledAt: DateTime.utc(2026, 10, 5, 8, 0),
        takenAt: DateTime.utc(2026, 10, 5, 8, 1),
      );

      await seedSchedule(db, id: 102);
      final r2 = await outbox.enqueue(
        medicationScheduleId: 102,
        scheduledAt: DateTime.utc(2026, 10, 5, 9, 0),
        takenAt: DateTime.utc(2026, 10, 5, 9, 1),
      );

      final emittedR1 = <DoseLogSyncState?>[];
      final sub1 = outbox.watchStatus(r1.clientUuid).listen(emittedR1.add);

      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Đổi trạng thái r2
      await outbox.markSynced(
        clientUuid: r2.clientUuid,
        serverId: 2,
        syncedAt: DateTime.utc(2026, 10, 5, 9, 5),
      );

      await Future<void>.delayed(const Duration(milliseconds: 20));

      // r1 vẫn chỉ có pendingUpload, không bị nhận sự kiện của r2
      expect(emittedR1, [DoseLogSyncState.pendingUpload]);

      await sub1.cancel();
    });

    test('dispose an toàn, gọi 2 lần không lỗi', () async {
      await outbox.dispose();
      await expectLater(outbox.dispose(), completes);
    });
  });

  group('SqliteDoseOutbox — SyncEngine Integration', () {
    test(
        'DoseOutboxSyncEngine cập nhật trạng thái outbox và phát stream synced',
        () async {
      final record = await outbox.enqueue(
        medicationScheduleId: 101,
        scheduledAt: DateTime.utc(2026, 10, 5, 8, 0),
        takenAt: DateTime.utc(2026, 10, 5, 8, 1),
      );

      final fakeStore = _FakeStore();
      final fakeRemote = _FakeRemote([
        DoseUploadResult(
          clientUuid: record.clientUuid,
          status: DoseUploadResultStatus.synced,
          serverId: 456,
          syncedAt: DateTime.utc(2026, 10, 5, 8, 10),
        ),
      ]);
      final fakeMonitor = _FakeMonitor();

      final engine = DoseOutboxSyncEngine(
        localStore: fakeStore,
        remoteDataSource: fakeRemote,
        connectivityMonitor: fakeMonitor,
        outbox: outbox,
      );

      final emitted = <DoseLogSyncState?>[];
      final sub = outbox.watchStatus(record.clientUuid).listen(emitted.add);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      await engine.syncPendingDoseLogs();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(
          emitted, [DoseLogSyncState.pendingUpload, DoseLogSyncState.synced]);

      final rows = await db.query(
        LocalDb.doseLogsTable,
        where: 'client_uuid = ?',
        whereArgs: [record.clientUuid],
      );
      expect(rows.first['sync_state'], 'synced');
      expect(rows.first['id'], 456);

      await sub.cancel();
      await engine.dispose();
    });
  });
}

class _FakeStore implements LocalMedicationStore {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRemote implements DoseRemoteDataSource {
  _FakeRemote(this.results);
  final List<DoseUploadResult> results;

  @override
  Future<List<DoseUploadResult>> uploadDoses(
          List<LocalDoseLog> doseLogs) async =>
      results;
}

class _FakeMonitor implements ConnectivityMonitor {
  @override
  Stream<bool> get onlineChanges => Stream.value(true);
  @override
  Future<bool> get isOnline async => true;
  @override
  Future<void> dispose() async {}
}
