import 'package:drugtime_mobile/core/storage/local_db/client_uuid.dart';
import 'package:drugtime_mobile/core/storage/local_db/local_db.dart';
import 'package:drugtime_mobile/core/storage/local_db/local_medication_store.dart';
import 'package:drugtime_mobile/core/storage/local_db/local_models.dart';
import 'package:drugtime_mobile/core/storage/secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late LocalDb localDb;
  late LocalMedicationStore localStore;

  setUp(() async {
    localDb = LocalDb(SecureStorage());
    localStore = SqliteLocalMedicationStore(localDb);

    final db = await localDb.database;
    await _clearLocalStore(db);
  });

  tearDown(() async {
    final db = await localDb.database;
    await _clearLocalStore(db);
    await localDb.close();
  });

  testWidgets('manual local store flow works on real encrypted database', (
    tester,
  ) async {
    const patientId = 'patient-manual-test';
    final schedule = LocalMedicationSchedule(
      id: 1001,
      patientUserId: patientId,
      userMedicationId: 2001,
      medicationId: 3001,
      medicationName: 'Amlodipine',
      strengthText: '5mg',
      dosageForm: 'tablet',
      quantityPerDose: '1',
      dosesPerDay: 1,
      intakeTime: '08:00:00',
      daysOfWeek: const [1, 2, 3, 4, 5, 6, 7],
      reminderEnabled: true,
      effectiveFrom: DateTime.utc(2026, 9, 29),
      serverSyncedAt: DateTime.now().toUtc(),
    );

    await localStore.replaceSchedules(
      patientId: patientId,
      schedules: [schedule],
    );

    final activeSchedules = await localStore.getActiveSchedules(
      patientId: patientId,
    );

    expect(activeSchedules, hasLength(1));
    expect(activeSchedules.single.medicationName, 'Amlodipine');
    expect(activeSchedules.single.intakeTime, '08:00:00');

    final doseLog = LocalDoseLog(
      clientUuid: createClientUuid(),
      medicationScheduleId: schedule.id,
      scheduledAt: DateTime.utc(2026, 9, 29, 1),
      takenAt: DateTime.utc(2026, 9, 29, 1, 5),
      status: DoseLogStatus.taken,
      syncState: DoseLogSyncState.pendingUpload,
      localUpdatedAt: DateTime.now().toUtc(),
    );

    await localStore.upsertDoseLog(doseLog);

    final pendingLogs = await localStore.getPendingDoseLogs();

    expect(pendingLogs, hasLength(1));
    expect(pendingLogs.single.medicationScheduleId, schedule.id);
    expect(pendingLogs.single.status, DoseLogStatus.taken);

    await localStore.markDoseLogSynced(
      clientUuid: doseLog.clientUuid,
      serverId: 9001,
      syncedAt: DateTime.now().toUtc(),
    );

    final pendingAfterSync = await localStore.getPendingDoseLogs();

    expect(pendingAfterSync, isEmpty);
  });
}

Future<void> _clearLocalStore(Database db) async {
  await db.delete(LocalDb.doseLogsTable);
  await db.delete(LocalDb.schedulesTable);
  await db.delete(LocalDb.syncMetaTable);
}
