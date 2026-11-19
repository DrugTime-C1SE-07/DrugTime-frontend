import '../../adherence/domain/entities/adherence_history.dart';
import '../../adherence_history/domain/schedule_occurrences.dart';
import '../../medication/domain/entities/medication.dart';

DateTime monitorDay(DateTime now) {
  final vn = vietnamWallTime(now);
  return DateTime.utc(vn.year, vn.month, vn.day);
}

String monitorTime(DateTime instant) {
  final vn = vietnamWallTime(instant);
  return '${vn.hour.toString().padLeft(2, '0')}:${vn.minute.toString().padLeft(2, '0')}';
}

class MonitorHistory {
  const MonitorHistory(this.history, this.checkpoint);
  final AdherenceHistory history;
  final DateTime? checkpoint;
}

class MonitorSchedule {
  MonitorSchedule(this.id, this.medicationId, this.name, this.time, this.days,
      this.effectiveFrom, this.endedAt);
  final int id, medicationId;
  final String name, time;
  final List<int> days;
  final DateTime effectiveFrom;
  final DateTime? endedAt;

  factory MonitorSchedule.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as int;
    if (id <= 0) throw const FormatException('Invalid schedule ID');
    return MonitorSchedule(
        id,
        json['medication']['id'] as int,
        json['medication']['name'] as String,
        json['intake_time'] as String,
        (json['days_of_week'] as List).cast<int>(),
        DateTime.parse(json['effective_from'] as String).toUtc(),
        json['ended_at'] == null
            ? null
            : DateTime.parse(json['ended_at'] as String).toUtc());
  }
}

class MonitorSnapshot {
  MonitorSnapshot(this.patientId, Iterable<MonitorSchedule> schedules,
      this.report, Iterable<Medication> medications)
      : schedules = List.unmodifiable(schedules),
        medications = List.unmodifiable(medications);
  final String patientId;
  final List<MonitorSchedule> schedules;
  final MonitorHistory report;
  final List<Medication> medications;

  List<AdherenceDose> dosesForDay(DateTime now) {
    final day = monitorDay(now);
    final history = report.history;
    final values = <(int, DateTime), AdherenceDose>{
      for (final group
          in history.groups.where((g) => sameCalendarDate(g.date, day)))
        for (final dose in group.doses)
          (dose.scheduleId, dose.scheduledAt.toUtc()): dose,
    };
    for (final schedule in schedules) {
      if (!schedule.days.contains(day.weekday)) continue;
      final at = scheduleInstant(day, schedule.time);
      if (at.isBefore(schedule.effectiveFrom) ||
          (schedule.endedAt != null && !at.isBefore(schedule.endedAt!))) {
        continue;
      }
      // Only future keys are inferred; past statuses always come from the server.
      if (!at.isAfter(history.asOf)) continue;
      values.putIfAbsent(
          (schedule.id, at),
          () => AdherenceDose(
              medicationId: schedule.medicationId,
              medicationName: schedule.name,
              scheduleId: schedule.id,
              scheduledAt: at,
              takenAt: null,
              status: AdherenceDoseStatus.pending));
    }
    return values.values.toList()
      ..sort((a, b) {
        final time = a.scheduledAt.compareTo(b.scheduledAt);
        return time == 0 ? a.scheduleId.compareTo(b.scheduleId) : time;
      });
  }
}
