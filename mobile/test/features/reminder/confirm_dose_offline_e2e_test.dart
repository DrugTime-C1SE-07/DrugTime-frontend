import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:drugtime_mobile/core/notification/reminder_scheduler.dart';
import 'package:drugtime_mobile/core/storage/local_db/local_db.dart';
import 'package:drugtime_mobile/core/storage/local_db/local_medication_store.dart';
import 'package:drugtime_mobile/core/storage/local_db/local_models.dart';
import 'package:drugtime_mobile/core/storage/local_db/sqlite_dose_outbox.dart';
import 'package:drugtime_mobile/core/sync/sync_engine.dart';
import 'package:drugtime_mobile/features/reminder/domain/entities/dose_reminder.dart';
import 'package:drugtime_mobile/features/reminder/presentation/state/dose_reminder_controller.dart';

class _TestLocalDb implements LocalDb {
  _TestLocalDb(this._db);
  final Database _db;

  @override
  Future<Database> get database async => _db;

  @override
  Future<void> close() async => _db.close();
}

class FakeConnectivityMonitor implements ConnectivityMonitor {
  FakeConnectivityMonitor({bool initialOnline = false})
      : _online = initialOnline;

  bool _online;
  final _controller = StreamController<bool>.broadcast();

  @override
  Stream<bool> get onlineChanges => _controller.stream;

  @override
  Future<bool> get isOnline async => _online;

  void setOnline(bool online) {
    _online = online;
    _controller.add(online);
  }

  @override
  Future<void> dispose() async => _controller.close();
}

class MockDoseRemoteDataSource implements DoseRemoteDataSource {
  final List<List<LocalDoseLog>> uploadCalls = [];
  bool shouldFail = false;

  @override
  Future<List<DoseUploadResult>> uploadDoses(List<LocalDoseLog> doseLogs) async {
    if (shouldFail) {
      throw const SocketException('No network connection');
    }
    uploadCalls.add(doseLogs);
    return doseLogs
        .map((log) => DoseUploadResult(
              clientUuid: log.clientUuid,
              status: DoseUploadResultStatus.synced,
              serverId: 999,
              syncedAt: DateTime.now().toUtc(),
            ))
        .toList();
  }
}

class _MockReminderScheduler implements ReminderScheduler {
  final List<Map<String, dynamic>> cancelledOccurrences = [];
  final List<int> cancelledSchedules = [];

  @override
  Future<void> cancelOccurrence({
    int? scheduleId,
    int? medicationScheduleId,
    required DateTime scheduledAt,
  }) async {
    cancelledOccurrences.add({
      'scheduleId': scheduleId ?? medicationScheduleId,
      'scheduledAt': scheduledAt,
    });
  }

  @override
  Future<void> cancelAllForSchedule(int scheduleId) async {
    cancelledSchedules.add(scheduleId);
  }

  @override
  Future<void> snooze({
    required int medicationScheduleId,
    required DateTime scheduledAt,
    required DateTime remindAt,
  }) async {}
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Task 2.12: E2E Offline Dose Confirmation & Sync Flow', () {
    late Database db;
    late SqliteDoseOutbox outbox;
    late SqliteLocalMedicationStore localStore;
    late FakeConnectivityMonitor connectivity;
    late MockDoseRemoteDataSource remoteDataSource;
    late DoseOutboxSyncEngine syncEngine;
    late _MockReminderScheduler scheduler;

    final scheduledAt = DateTime.utc(2026, 10, 29, 8, 0, 0);
    final item = DoseReminderItem(
      medicationScheduleId: 101,
      scheduledAt: scheduledAt,
      medicationName: 'Panadol Extra',
      dosageText: '1 viên',
      instruction: 'Uống sau ăn',
    );
    final group = DoseReminderGroup([item]);

    setUp(() async {
      db = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: LocalDb.createSchema,
        ),
      );

      // Seed dữ liệu lịch uống vào SQLite
      await db.insert(
        LocalDb.schedulesTable,
        {
          'id': 101,
          'patient_user_id': 'patient-uuid-001',
          'user_medication_id': 201,
          'medication_id': 301,
          'medication_name': 'Panadol Extra',
          'strength_text': '500mg',
          'dosage_form': 'Viên nén',
          'quantity_per_dose': '1',
          'doses_per_day': 1,
          'intake_time': '08:00:00',
          'days_of_week': '1,2,3,4,5,6,7',
          'reminder_enabled': 1,
          'effective_from': '2026-10-01T00:00:00.000Z',
          'ended_at': null,
          'server_synced_at': '2026-10-01T00:00:00.000Z',
        },
      );

      outbox = SqliteDoseOutbox(getDatabase: () async => db);
      localStore = SqliteLocalMedicationStore(_TestLocalDb(db));
      connectivity = FakeConnectivityMonitor(initialOnline: false);
      remoteDataSource = MockDoseRemoteDataSource();
      syncEngine = DoseOutboxSyncEngine(
        localStore: localStore,
        outbox: outbox,
        remoteDataSource: remoteDataSource,
        connectivityMonitor: connectivity,
      );
      scheduler = _MockReminderScheduler();
    });

    tearDown(() async {
      await outbox.dispose();
      await syncEngine.dispose();
      await db.close();
    });

    test(
        'Offline: Bấm Đã uống -> Outbox lưu pending_upload -> Có mạng -> SyncEngine đồng bộ thành synced',
        () async {
      final clockTime = DateTime.utc(2026, 10, 29, 8, 0, 0);
      final controller = DoseReminderController(
        group: group,
        outbox: outbox,
        scheduler: scheduler,
        clock: () => clockTime,
      );

      // 1. Giả lập thiết bị ngoại tuyến (chặn cuộc gọi HTTP)
      expect(await connectivity.isOnline, isFalse);

      // 2. Gọi hành động xác nhận liều qua DoseReminderController
      final confirmed = await controller.confirmItem(item);
      expect(confirmed, isTrue);
      expect(controller.statusOf(item), DoseReminderItemStatus.confirmed);

      // 3. Xác minh: Bảng SQLite local_dose_logs có dòng mới với client_uuid hợp lệ và sync_state == 'pending_upload'
      final offlineRows = await db.query(LocalDb.doseLogsTable);
      expect(offlineRows.length, 1);
      final offlineLog = offlineRows.first;

      expect(offlineLog['medication_schedule_id'], 101);
      expect(offlineLog['scheduled_at'], scheduledAt.toIso8601String());
      expect(offlineLog['status'], DoseLogStatus.taken.serverValue);
      expect(offlineLog['sync_state'], 'pending_upload');

      final clientUuid = offlineLog['client_uuid'] as String;
      expect(clientUuid, isNotEmpty);
      expect(
        RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(clientUuid),
        isTrue,
        reason: 'client_uuid phải đúng chuẩn UUID v4 format',
      );

      // Chưa có cuộc gọi đẩy lên server
      expect(remoteDataSource.uploadCalls, isEmpty);

      // 4. Giả lập có mạng trở lại: Kích hoạt SyncEngine.syncPendingDoses()
      connectivity.setOnline(true);
      expect(await connectivity.isOnline, isTrue);

      await syncEngine.syncPendingDoses();

      // Đã gửi lô thuốc lên server
      expect(remoteDataSource.uploadCalls.length, 1);
      expect(remoteDataSource.uploadCalls.first.length, 1);
      expect(remoteDataSource.uploadCalls.first.first.clientUuid, clientUuid);

      // 5. Xác minh: Dòng dữ liệu chuyển trạng thái thành 'synced'
      final syncedRows = await db.query(LocalDb.doseLogsTable);
      expect(syncedRows.length, 1);
      final syncedLog = syncedRows.first;

      expect(syncedLog['client_uuid'], clientUuid);
      expect(syncedLog['sync_state'], 'synced');
      expect(syncedLog['id'], 999);
      expect(syncedLog['synced_at'], isNotNull);
      expect(syncedLog['last_error'], isNull);

      // 6. Kiểm tra Idempotency: xác nhận lại không tạo bản ghi thứ hai
      final reconfirm = await controller.confirmItem(item);
      expect(reconfirm, isTrue);

      final postCheckRows = await db.query(LocalDb.doseLogsTable);
      expect(postCheckRows.length, 1);
    });
  });
}
