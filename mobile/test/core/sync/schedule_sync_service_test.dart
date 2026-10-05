import 'package:drugtime_mobile/core/storage/local_db/local_medication_store.dart';
import 'package:drugtime_mobile/core/storage/local_db/local_models.dart';
import 'package:drugtime_mobile/core/sync/schedule_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('syncSchedulesFromServer replaces local schedules and records sync time',
      () async {
    final schedule = _schedule();
    final remote = _FakeScheduleRemoteDataSource([schedule]);
    final localStore = _FakeLocalMedicationStore();
    final service = ScheduleSyncService(
      remoteDataSource: remote,
      localStore: localStore,
    );

    await service.syncSchedulesFromServer(patientId: 'patient-1');

    expect(remote.lastPatientId, 'patient-1');
    expect(localStore.replacedPatientId, 'patient-1');
    expect(localStore.replacedSchedules, [schedule]);
    expect(
      localStore.meta[ScheduleSyncService.lastSchedulePullAtKey],
      isNotNull,
    );
  });

  test('syncSchedulesFromServer supports empty server response', () async {
    final remote = _FakeScheduleRemoteDataSource(const []);
    final localStore = _FakeLocalMedicationStore();
    final service = ScheduleSyncService(
      remoteDataSource: remote,
      localStore: localStore,
    );

    await service.syncSchedulesFromServer(patientId: 'patient-1');

    expect(localStore.replacedPatientId, 'patient-1');
    expect(localStore.replacedSchedules, isEmpty);
    expect(
      localStore.meta[ScheduleSyncService.lastSchedulePullAtKey],
      isNotNull,
    );
  });

  test('syncSchedulesFromServer does not write local data when remote fails',
      () async {
    final remote = _ThrowingScheduleRemoteDataSource();
    final localStore = _FakeLocalMedicationStore();
    final service = ScheduleSyncService(
      remoteDataSource: remote,
      localStore: localStore,
    );

    await expectLater(
      service.syncSchedulesFromServer(patientId: 'patient-1'),
      throwsA(isA<Exception>()),
    );
    expect(localStore.replaceCallCount, 0);
    expect(localStore.meta, isEmpty);
  });

  test('syncSchedulesFromServer does not record sync time when replace fails',
      () async {
    final remote = _FakeScheduleRemoteDataSource([_schedule()]);
    final localStore = _FakeLocalMedicationStore(throwOnReplace: true);
    final service = ScheduleSyncService(
      remoteDataSource: remote,
      localStore: localStore,
    );

    await expectLater(
      service.syncSchedulesFromServer(patientId: 'patient-1'),
      throwsA(isA<Exception>()),
    );
    expect(localStore.replaceCallCount, 1);
    expect(localStore.meta, isEmpty);
  });
}

class _FakeScheduleRemoteDataSource implements ScheduleRemoteDataSource {
  _FakeScheduleRemoteDataSource(this.schedules);

  final List<LocalMedicationSchedule> schedules;
  String? lastPatientId;

  @override
  Future<List<LocalMedicationSchedule>> fetchSchedules({
    required String patientId,
  }) async {
    lastPatientId = patientId;
    return schedules;
  }
}

class _FakeLocalMedicationStore implements LocalMedicationStore {
  _FakeLocalMedicationStore({this.throwOnReplace = false});

  final bool throwOnReplace;
  String? replacedPatientId;
  List<LocalMedicationSchedule>? replacedSchedules;
  int replaceCallCount = 0;
  final Map<String, String> meta = {};

  @override
  Future<void> replaceSchedules({
    required String patientId,
    required List<LocalMedicationSchedule> schedules,
  }) async {
    replaceCallCount++;
    if (throwOnReplace) {
      throw Exception('Local replace failed');
    }

    replacedPatientId = patientId;
    replacedSchedules = schedules;
  }

  @override
  Future<void> setMeta(String key, String value) async {
    meta[key] = value;
  }

  @override
  Future<List<LocalMedicationSchedule>> getActiveSchedules({
    required String patientId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<String?> getMeta(String key) {
    throw UnimplementedError();
  }

  @override
  Future<List<LocalDoseLog>> getPendingDoseLogs() {
    throw UnimplementedError();
  }

  @override
  Future<LocalMedicationSchedule?> getScheduleById(int scheduleId) {
    throw UnimplementedError();
  }

  @override
  Future<void> markDoseLogFailed({
    required String clientUuid,
    required String errorMessage,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> markDoseLogSynced({
    required String clientUuid,
    required int? serverId,
    required DateTime syncedAt,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> upsertDoseLog(LocalDoseLog doseLog) {
    throw UnimplementedError();
  }
}

class _ThrowingScheduleRemoteDataSource implements ScheduleRemoteDataSource {
  @override
  Future<List<LocalMedicationSchedule>> fetchSchedules({
    required String patientId,
  }) async {
    throw Exception('Server unavailable');
  }
}

LocalMedicationSchedule _schedule() {
  return LocalMedicationSchedule(
    id: 12,
    patientUserId: 'patient-1',
    userMedicationId: 5,
    medicationId: 99,
    medicationName: 'Amlodipine',
    quantityPerDose: '1',
    dosesPerDay: 1,
    intakeTime: '08:00:00',
    daysOfWeek: const [1, 2, 3, 4, 5, 6, 7],
    reminderEnabled: true,
    effectiveFrom: DateTime.utc(2026, 9, 29, 1),
    serverSyncedAt: DateTime.utc(2026, 9, 29, 2),
  );
}
