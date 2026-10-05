import '../storage/local_db/local_medication_store.dart';
import '../storage/local_db/local_models.dart';

abstract class ScheduleRemoteDataSource {
  Future<List<LocalMedicationSchedule>> fetchSchedules({
    required String patientId,
  });
}

class ScheduleSyncService {
  ScheduleSyncService({
    required ScheduleRemoteDataSource remoteDataSource,
    required LocalMedicationStore localStore,
  })  : _remoteDataSource = remoteDataSource,
        _localStore = localStore;

  static const lastSchedulePullAtKey = 'last_schedule_pull_at';

  final ScheduleRemoteDataSource _remoteDataSource;
  final LocalMedicationStore _localStore;

  Future<void> syncSchedulesFromServer({required String patientId}) async {
    final schedules = await _remoteDataSource.fetchSchedules(
      patientId: patientId,
    );

    await _localStore.replaceSchedules(
      patientId: patientId,
      schedules: schedules,
    );
    await _localStore.setMeta(
      lastSchedulePullAtKey,
      DateTime.now().toUtc().toIso8601String(),
    );
  }
}
