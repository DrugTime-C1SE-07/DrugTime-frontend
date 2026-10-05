import 'package:sqflite_sqlcipher/sqflite.dart';

import 'local_db.dart';
import 'local_models.dart';

abstract class LocalMedicationStore {
  Future<void> replaceSchedules({
    required String patientId,
    required List<LocalMedicationSchedule> schedules,
  });
  Future<List<LocalMedicationSchedule>> getActiveSchedules({
    required String patientId,
  });
  Future<LocalMedicationSchedule?> getScheduleById(int scheduleId);

  Future<void> upsertDoseLog(LocalDoseLog doseLog);
  Future<List<LocalDoseLog>> getPendingDoseLogs();
  Future<void> markDoseLogSynced({
    required String clientUuid,
    required int? serverId,
    required DateTime syncedAt,
  });
  Future<void> markDoseLogFailed({
    required String clientUuid,
    required String errorMessage,
  });

  Future<String?> getMeta(String key);
  Future<void> setMeta(String key, String value);
}

class SqliteLocalMedicationStore implements LocalMedicationStore {
  SqliteLocalMedicationStore(this._localDb);

  final LocalDb _localDb;

  @override
  Future<void> replaceSchedules({
    required String patientId,
    required List<LocalMedicationSchedule> schedules,
  }) async {
    final db = await _localDb.database;

    await db.transaction((txn) async {
      // Schedules are server-owned, so local copy is replaced by the latest
      // successful pull from the server.
      await txn.delete(
        LocalDb.schedulesTable,
        where: 'patient_user_id = ?',
        whereArgs: [patientId],
      );

      for (final schedule in schedules) {
        await txn.insert(
          LocalDb.schedulesTable,
          schedule.toDbMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  @override
  Future<List<LocalMedicationSchedule>> getActiveSchedules({
    required String patientId,
  }) async {
    final db = await _localDb.database;
    final rows = await db.query(
      LocalDb.schedulesTable,
      where:
          'patient_user_id = ? AND reminder_enabled = 1 AND ended_at IS NULL',
      whereArgs: [patientId],
      orderBy: 'intake_time ASC',
    );

    return rows.map(LocalMedicationSchedule.fromDbMap).toList(growable: false);
  }

  @override
  Future<LocalMedicationSchedule?> getScheduleById(int scheduleId) async {
    final db = await _localDb.database;
    final rows = await db.query(
      LocalDb.schedulesTable,
      where: 'id = ?',
      whereArgs: [scheduleId],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return LocalMedicationSchedule.fromDbMap(rows.first);
  }

  @override
  Future<void> upsertDoseLog(LocalDoseLog doseLog) async {
    final db = await _localDb.database;

    await db.transaction((txn) async {
      final existingRows = await txn.query(
        LocalDb.doseLogsTable,
        columns: ['client_uuid'],
        where: 'medication_schedule_id = ? AND scheduled_at = ?',
        whereArgs: [
          doseLog.medicationScheduleId,
          doseLog.scheduledAt.toUtc().toIso8601String(),
        ],
        limit: 1,
      );

      if (existingRows.isEmpty) {
        await txn.insert(LocalDb.doseLogsTable, doseLog.toDbMap());
        return;
      }

      final existingClientUuid = existingRows.first['client_uuid'] as String;
      await txn.update(
        LocalDb.doseLogsTable,
        doseLog.toDbMap()..['client_uuid'] = existingClientUuid,
        where: 'client_uuid = ?',
        whereArgs: [existingClientUuid],
      );
    });
  }

  @override
  Future<List<LocalDoseLog>> getPendingDoseLogs() async {
    final db = await _localDb.database;
    final rows = await db.query(
      LocalDb.doseLogsTable,
      where: 'sync_state = ?',
      whereArgs: [DoseLogSyncState.pendingUpload.value],
      orderBy: 'scheduled_at ASC',
    );

    return rows.map(LocalDoseLog.fromDbMap).toList(growable: false);
  }

  @override
  Future<void> markDoseLogSynced({
    required String clientUuid,
    required int? serverId,
    required DateTime syncedAt,
  }) async {
    final db = await _localDb.database;

    await db.update(
      LocalDb.doseLogsTable,
      {
        'id': serverId,
        'sync_state': DoseLogSyncState.synced.value,
        'synced_at': syncedAt.toUtc().toIso8601String(),
        'last_error': null,
      },
      where: 'client_uuid = ?',
      whereArgs: [clientUuid],
    );
  }

  @override
  Future<void> markDoseLogFailed({
    required String clientUuid,
    required String errorMessage,
  }) async {
    final db = await _localDb.database;

    await db.update(
      LocalDb.doseLogsTable,
      {
        'sync_state': DoseLogSyncState.failed.value,
        'last_error': errorMessage,
      },
      where: 'client_uuid = ?',
      whereArgs: [clientUuid],
    );
  }

  @override
  Future<String?> getMeta(String key) async {
    final db = await _localDb.database;
    final rows = await db.query(
      LocalDb.syncMetaTable,
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return rows.first['value'] as String;
  }

  @override
  Future<void> setMeta(String key, String value) async {
    final db = await _localDb.database;

    await db.insert(
      LocalDb.syncMetaTable,
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
