import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/features/adherence/domain/entities/adherence_history.dart';
import 'package:drugtime_mobile/features/patient_monitor/domain/monitor_models.dart';

void main() {
  test(
      'Vietnam calendar works outside device zone, merges individual occurrences without local storage',
      () {
    final asOf = DateTime.utc(2026, 11, 19, 0, 15);
    final schedules = [
      MonitorSchedule(1, 10, 'A', '06:30', [4], DateTime.utc(2026, 1), null),
      MonitorSchedule(2, 10, 'A', '08:00', [4], DateTime.utc(2026, 1), null),
      MonitorSchedule(3, 10, 'A', '09:00', [3], DateTime.utc(2026, 1), null),
      MonitorSchedule(4, 10, 'A', '10:00', [4], DateTime.utc(2026, 1),
          DateTime.utc(2026, 11, 19, 3)),
    ];
    final past = AdherenceDose(
        medicationId: 10,
        medicationName: 'A',
        scheduleId: 1,
        scheduledAt: DateTime.utc(2026, 11, 18, 23, 30),
        takenAt: null,
        status: AdherenceDoseStatus.unverified);
    const summary = AdherenceSummary(
        total: 1,
        taken: 0,
        late: 0,
        missed: 0,
        pending: 0,
        unverified: 1,
        counted: 0,
        rate: null);
    final day = DateTime.utc(2026, 11, 19);
    final snapshot = MonitorSnapshot(
        'mother',
        schedules,
        MonitorHistory(
            AdherenceHistory(
                patientId: 'mother',
                from: day,
                to: day,
                asOf: asOf,
                summary: summary,
                groups: [
                  AdherenceDateGroup(date: day, summary: summary, doses: [past])
                ]),
            null),
        []);
    final projected = snapshot.dosesForDay(asOf);
    expect(projected.map((d) => d.scheduleId), [1, 2]);
    expect(projected.first.status, AdherenceDoseStatus.unverified);
    expect(projected.last.scheduledAt, DateTime.utc(2026, 11, 19, 1));
    expect(snapshot.report.history.summary.rate, isNull);
  });
}
