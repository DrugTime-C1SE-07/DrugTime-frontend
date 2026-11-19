import 'package:flutter_test/flutter_test.dart';
import '../../../lib/core/storage/local_db/local_models.dart';
import '../../../lib/features/adherence_history/domain/schedule_occurrences.dart';

void main() {
  test('shows both future doses on the day medication is saved', () {
    final day = DateTime.utc(2026, 11, 15);
    final savedAt = DateTime.parse('2026-11-15T08:36:00+07:00');
    LocalMedicationSchedule schedule(int id, String time, {DateTime? end}) =>
        LocalMedicationSchedule(
          id: id,
          patientUserId: 'patient',
          userMedicationId: 1,
          medicationId: 1,
          medicationName: 'Thuốc thử nghiệm',
          quantityPerDose: '1',
          dosesPerDay: 2,
          intakeTime: time,
          daysOfWeek: [day.weekday],
          reminderEnabled: false,
          effectiveFrom: savedAt,
          endedAt: end,
          serverSyncedAt: savedAt,
        );

    final groups = mergeUpcomingDoses(
      schedules: [
        schedule(1, '20:00:00'),
        schedule(2, '13:00:00'),
        schedule(3, '07:00:00'),
        schedule(4, '13:00:00', end: DateTime.utc(2026, 11, 15, 6)),
      ],
      history: [],
      firstDay: day,
      lastDay: day,
      now: savedAt,
    );

    expect(groups[day]!.doses.map((dose) => dose.scheduleId), [2, 1]);
    expect(groups[day]!.summary.pending, 2);
  });
}
