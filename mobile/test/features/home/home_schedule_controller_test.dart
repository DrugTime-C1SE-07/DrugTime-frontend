import 'dart:async';

import 'package:drugtime_mobile/core/storage/local_db/local_models.dart';
import 'package:drugtime_mobile/core/sync/schedule_sync_service.dart';
import 'package:drugtime_mobile/features/adherence_history/domain/entities/adherence_history.dart';
import 'package:drugtime_mobile/features/adherence_history/domain/repositories/adherence_history_repository.dart';
import 'package:drugtime_mobile/features/home/presentation/home_schedule_controller.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime.utc(2026, 11, 16, 5);
final _today = DateTime.utc(2026, 11, 16);
const _empty = AdherenceSummary(
    total: 0, taken: 0, late: 0, missed: 0, pending: 0, counted: 0, rate: null);

class _History implements AdherenceHistoryRepository {
  Completer<void>? waiting;

  @override
  Future<AdherenceHistory> fetch(
      {required DateTime from,
      required DateTime to,
      required HistoryMode mode}) async {
    await waiting?.future;
    return AdherenceHistory(
        patientId: 'p1',
        from: from,
        to: to,
        asOf: _now,
        mode: mode,
        summary: _empty);
  }
}

class _Schedules implements ScheduleRemoteDataSource {
  @override
  Future<List<LocalMedicationSchedule>> fetchSchedules(
          {required String patientId}) async =>
      [
        LocalMedicationSchedule(
            id: 1,
            patientUserId: patientId,
            userMedicationId: 2,
            medicationId: 3,
            medicationName: 'Thuốc kiểm thử',
            quantityPerDose: '1',
            dosesPerDay: 1,
            intakeTime: '12:30:00',
            daysOfWeek: [_today.weekday],
            reminderEnabled: true,
            effectiveFrom: _today.subtract(const Duration(days: 1)),
            serverSyncedAt: _now),
      ];
}

void main() {
  test('projects a future dose and prevents duplicate offline confirmation',
      () async {
    var calls = 0;
    final response = Completer<HomeConfirmation>();
    final controller = HomeScheduleController(_History(), _Schedules(), (_, __) {
      calls++;
      return response.future;
    }, clock: () => _now);
    addTearDown(controller.dispose);
    controller.setAccess('p1', true);
    await controller.load();
    final dose = controller.day!.doses.single;
    expect(dose.scheduledAt, DateTime.utc(2026, 11, 16, 5, 30));
    expect(dose.status, HistoryDoseStatus.pending);
    final saving = controller.confirm(dose);
    await controller.confirm(dose);
    response.complete(HomeConfirmation.pending);
    await saving;
    await controller.confirm(dose);
    expect(calls, 1);
    expect(controller.message, 'Đang chờ đồng bộ');
    expect(dose.takenAt, isNull);
  });

  test('revocation discards a history response already in flight', () async {
    final history = _History()..waiting = Completer<void>();
    final controller = HomeScheduleController(
        history, _Schedules(), (_, __) async => HomeConfirmation.failed,
        clock: () => _now);
    addTearDown(controller.dispose);
    controller.setAccess('p1', true);
    final loading = controller.load();
    controller.setAccess('p1', false);
    history.waiting!.complete();
    await loading;
    expect(controller.day, isNull);
    expect(controller.failed, isTrue);
    expect(controller.loading, isFalse);
  });
}
