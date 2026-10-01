import 'package:drugtime_mobile/core/storage/local_db/client_uuid.dart';
import 'package:drugtime_mobile/core/storage/local_db/local_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalMedicationSchedule', () {
    test('converts to and from database map', () {
      final schedule = _schedule();

      final restored = LocalMedicationSchedule.fromDbMap(schedule.toDbMap());

      expect(restored.id, schedule.id);
      expect(restored.patientUserId, schedule.patientUserId);
      expect(restored.medicationName, schedule.medicationName);
      expect(restored.intakeTime, schedule.intakeTime);
      expect(restored.daysOfWeek, schedule.daysOfWeek);
      expect(restored.isActive, isTrue);
    });

    test('keeps optional display fields nullable', () {
      final schedule = _schedule(strengthText: null, dosageForm: null);

      final restored = LocalMedicationSchedule.fromDbMap(schedule.toDbMap());

      expect(restored.strengthText, isNull);
      expect(restored.dosageForm, isNull);
    });

    test('is inactive when reminder is disabled', () {
      final schedule = _schedule(reminderEnabled: false);

      expect(schedule.isActive, isFalse);
    });

    test('is inactive when schedule has ended', () {
      final schedule = _schedule(
        endedAt: DateTime.utc(2026, 10),
      );

      expect(schedule.isActive, isFalse);
    });

    test('supports boundary days of week from 1 to 7', () {
      final schedule = _schedule(daysOfWeek: const [1, 7]);

      final restored = LocalMedicationSchedule.fromDbMap(schedule.toDbMap());

      expect(restored.daysOfWeek, const [1, 7]);
    });

    test('stores DateTime values as UTC ISO strings', () {
      final schedule = _schedule(
        effectiveFrom: DateTime(2026, 9, 29, 8),
      );

      final dbMap = schedule.toDbMap();

      expect(dbMap['effective_from'], endsWith('Z'));
    });
  });

  group('LocalDoseLog', () {
    test('converts to and from database map', () {
      final doseLog = _doseLog();

      final restored = LocalDoseLog.fromDbMap(doseLog.toDbMap());

      expect(restored.clientUuid, doseLog.clientUuid);
      expect(restored.medicationScheduleId, doseLog.medicationScheduleId);
      expect(restored.status, DoseLogStatus.taken);
      expect(restored.syncState, DoseLogSyncState.pendingUpload);
      expect(restored.takenAt, doseLog.takenAt);
    });

    test('supports missed dose without takenAt', () {
      final doseLog = _doseLog(
        status: DoseLogStatus.missed,
        includeTakenAt: false,
      );

      final restored = LocalDoseLog.fromDbMap(doseLog.toDbMap());

      expect(restored.status, DoseLogStatus.missed);
      expect(restored.takenAt, isNull);
    });

    test('supports late dose status', () {
      final doseLog = _doseLog(status: DoseLogStatus.late);

      final restored = LocalDoseLog.fromDbMap(doseLog.toDbMap());

      expect(restored.status, DoseLogStatus.late);
    });

    test('supports failed sync state with error message', () {
      final doseLog = _doseLog(
        syncState: DoseLogSyncState.failed,
        lastError: 'Network unavailable',
      );

      final restored = LocalDoseLog.fromDbMap(doseLog.toDbMap());

      expect(restored.syncState, DoseLogSyncState.failed);
      expect(restored.lastError, 'Network unavailable');
    });

    test('supports synced state with server id and syncedAt', () {
      final doseLog = _doseLog(
        id: 9001,
        syncState: DoseLogSyncState.synced,
        syncedAt: DateTime.utc(2026, 9, 29, 2),
      );

      final restored = LocalDoseLog.fromDbMap(doseLog.toDbMap());

      expect(restored.id, 9001);
      expect(restored.syncState, DoseLogSyncState.synced);
      expect(restored.syncedAt, DateTime.utc(2026, 9, 29, 2));
    });

    test('throws when database map has unknown dose status', () {
      final dbMap = _doseLog().toDbMap()..['status'] = 'unknown_status';

      expect(
        () => LocalDoseLog.fromDbMap(dbMap),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws when database map has unknown sync state', () {
      final dbMap = _doseLog().toDbMap()..['sync_state'] = 'unknown_state';

      expect(
        () => LocalDoseLog.fromDbMap(dbMap),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('createClientUuid', () {
    test('creates an RFC 4122 version 4 UUID string', () {
      final clientUuid = createClientUuid();

      expect(
        clientUuid,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
    });

    test('creates unique UUIDs across many attempts', () {
      final ids = List.generate(100, (_) => createClientUuid()).toSet();

      expect(ids, hasLength(100));
    });
  });
}

LocalMedicationSchedule _schedule({
  String? strengthText = '5mg',
  String? dosageForm = 'tablet',
  List<int> daysOfWeek = const [1, 2, 3, 4, 5, 6, 7],
  bool reminderEnabled = true,
  DateTime? effectiveFrom,
  DateTime? endedAt,
}) {
  return LocalMedicationSchedule(
    id: 12,
    patientUserId: 'patient-1',
    userMedicationId: 5,
    medicationId: 99,
    medicationName: 'Amlodipine',
    strengthText: strengthText,
    dosageForm: dosageForm,
    quantityPerDose: '1',
    dosesPerDay: 1,
    intakeTime: '08:00:00',
    daysOfWeek: daysOfWeek,
    reminderEnabled: reminderEnabled,
    effectiveFrom: effectiveFrom ?? DateTime.utc(2026, 9, 29, 1),
    endedAt: endedAt,
    serverSyncedAt: DateTime.utc(2026, 9, 29, 2),
  );
}

LocalDoseLog _doseLog({
  int? id,
  DateTime? takenAt,
  bool includeTakenAt = true,
  DoseLogStatus status = DoseLogStatus.taken,
  DoseLogSyncState syncState = DoseLogSyncState.pendingUpload,
  DateTime? syncedAt,
  String? lastError,
}) {
  return LocalDoseLog(
    id: id,
    clientUuid: '11111111-1111-4111-8111-111111111111',
    medicationScheduleId: 12,
    scheduledAt: DateTime.utc(2026, 9, 29, 1),
    takenAt: includeTakenAt ? takenAt ?? DateTime.utc(2026, 9, 29, 1, 5) : null,
    status: status,
    syncState: syncState,
    syncedAt: syncedAt,
    lastError: lastError,
    localUpdatedAt: DateTime.utc(2026, 9, 29, 1, 5),
  );
}
