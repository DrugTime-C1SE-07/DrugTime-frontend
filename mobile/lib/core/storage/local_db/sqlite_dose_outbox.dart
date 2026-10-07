import 'dart:async';

import 'package:sqflite_sqlcipher/sqflite.dart';

import '../../contracts/dose_outbox.dart';
import 'client_uuid.dart';
import 'local_db.dart';
import 'local_models.dart';

class SqliteDoseOutbox implements DoseOutbox {
  SqliteDoseOutbox({
    required Future<Database> Function() getDatabase,
  }) : _getDatabase = getDatabase;

  factory SqliteDoseOutbox.fromLocalDb(LocalDb localDb) {
    return SqliteDoseOutbox(getDatabase: () => localDb.database);
  }

  final Future<Database> Function() _getDatabase;
  final _eventsController =
      StreamController<MapEntry<String, DoseLogSyncState>>.broadcast();
  bool _disposed = false;

  @override
  Future<LocalDoseLog> enqueue({
    required int medicationScheduleId,
    required DateTime scheduledAt,
    required DateTime takenAt,
  }) async {
    final db = await _getDatabase();
    final utcScheduledAt = scheduledAt.toUtc().toIso8601String();
    final utcTakenAt = takenAt.toUtc().toIso8601String();
    final clientUuid = createClientUuid();
    final nowIso = DateTime.now().toUtc().toIso8601String();

    await db.rawInsert('''
      INSERT OR IGNORE INTO ${LocalDb.doseLogsTable} (
        client_uuid,
        medication_schedule_id,
        scheduled_at,
        taken_at,
        status,
        sync_state,
        local_updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?)
    ''', [
      clientUuid,
      medicationScheduleId,
      utcScheduledAt,
      utcTakenAt,
      DoseLogStatus.taken.serverValue,
      DoseLogSyncState.pendingUpload.value,
      nowIso,
    ]);

    final rows = await db.query(
      LocalDb.doseLogsTable,
      where: 'medication_schedule_id = ? AND scheduled_at = ?',
      whereArgs: [medicationScheduleId, utcScheduledAt],
      limit: 1,
    );

    if (rows.isEmpty) {
      throw StateError(
        'Failed to insert or retrieve dose log for schedule $medicationScheduleId at $utcScheduledAt',
      );
    }

    return LocalDoseLog.fromDbMap(rows.first);
  }

  @override
  Future<List<LocalDoseLog>> getPendingLogs() async {
    final db = await _getDatabase();
    final rows = await db.query(
      LocalDb.doseLogsTable,
      where: 'sync_state = ?',
      whereArgs: [DoseLogSyncState.pendingUpload.value],
      orderBy: 'scheduled_at ASC',
    );

    return rows.map(LocalDoseLog.fromDbMap).toList(growable: false);
  }

  @override
  Future<void> markSynced({
    required String clientUuid,
    required int? serverId,
    required DateTime syncedAt,
  }) async {
    final db = await _getDatabase();
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final syncedAtIso = syncedAt.toUtc().toIso8601String();

    final count = await db.rawUpdate('''
      UPDATE ${LocalDb.doseLogsTable}
      SET sync_state = ?, id = COALESCE(?, id), synced_at = ?, last_error = NULL, local_updated_at = ?
      WHERE client_uuid = ? AND sync_state <> ?
    ''', [
      DoseLogSyncState.synced.value,
      serverId,
      syncedAtIso,
      nowIso,
      clientUuid,
      DoseLogSyncState.synced.value,
    ]);

    if (count > 0 && !_disposed && !_eventsController.isClosed) {
      _eventsController.add(MapEntry(clientUuid, DoseLogSyncState.synced));
    }
  }

  @override
  Future<void> markFailed({
    required String clientUuid,
    required String errorMessage,
  }) async {
    final db = await _getDatabase();
    final nowIso = DateTime.now().toUtc().toIso8601String();

    final count = await db.rawUpdate('''
      UPDATE ${LocalDb.doseLogsTable}
      SET sync_state = ?, last_error = ?, local_updated_at = ?
      WHERE client_uuid = ? AND sync_state = ?
    ''', [
      DoseLogSyncState.failed.value,
      errorMessage,
      nowIso,
      clientUuid,
      DoseLogSyncState.pendingUpload.value,
    ]);

    if (count > 0 && !_disposed && !_eventsController.isClosed) {
      _eventsController.add(MapEntry(clientUuid, DoseLogSyncState.failed));
    }
  }

  @override
  Stream<DoseLogSyncState?> watchStatus(String clientUuid) {
    if (_disposed) {
      return Stream.value(null);
    }

    late StreamController<DoseLogSyncState?> controller;
    StreamSubscription<MapEntry<String, DoseLogSyncState>>? sub;
    var eventReceived = false;

    controller = StreamController<DoseLogSyncState?>(
      onListen: () async {
        sub = _eventsController.stream
            .where((entry) => entry.key == clientUuid)
            .listen((entry) {
          eventReceived = true;
          if (!controller.isClosed) {
            controller.add(entry.value);
          }
        });

        try {
          final db = await _getDatabase();
          final rows = await db.query(
            LocalDb.doseLogsTable,
            columns: ['sync_state'],
            where: 'client_uuid = ?',
            whereArgs: [clientUuid],
            limit: 1,
          );

          if (!eventReceived && !controller.isClosed) {
            if (rows.isEmpty) {
              controller.add(null);
            } else {
              controller.add(
                DoseLogSyncState.fromValue(rows.first['sync_state'] as String),
              );
            }
          }
        } catch (_) {
          if (!eventReceived && !controller.isClosed) {
            controller.add(null);
          }
        }
      },
      onCancel: () async {
        await sub?.cancel();
        sub = null;
        await controller.close();
      },
    );

    return controller.stream.distinct();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _eventsController.close();
  }
}
