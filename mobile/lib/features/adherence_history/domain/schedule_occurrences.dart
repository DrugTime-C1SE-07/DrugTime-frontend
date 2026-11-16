import '../../../core/storage/local_db/local_models.dart';
import 'entities/adherence_history.dart';

/// Projects future doses within an inclusive range of Vietnam calendar dates.
Map<DateTime, DateHistoryGroup> mergeUpcomingDoses({
  required Iterable<LocalMedicationSchedule> schedules,
  required Iterable<DateHistoryGroup> history,
  required DateTime firstDay,
  required DateTime lastDay,
  required DateTime now,
}) {
  const vietnamOffset = Duration(hours: 7);
  final groups = {for (final group in history) group.date: group};
  final localNow = now.toUtc().add(vietnamOffset);
  final today = DateTime.utc(localNow.year, localNow.month, localNow.day);
  var day = firstDay.isBefore(today) ? today : firstDay;
  for (; !day.isAfter(lastDay); day = day.add(const Duration(days: 1))) {
    final group = groups[day];
    final doses = {
      for (final dose in group?.doses ?? const <HistoryDose>[])
        (dose.scheduleId, dose.scheduledAt.toUtc()): dose,
    };
    final before = doses.length;
    for (final schedule in schedules) {
      if (!schedule.daysOfWeek.contains(day.weekday)) continue;
      final parts = schedule.intakeTime.split(':').map(int.parse).toList();
      final at = day
          .add(Duration(
            hours: parts[0],
            minutes: parts[1],
            seconds: parts.length > 2 ? parts[2] : 0,
          ))
          .subtract(vietnamOffset);
      final endedAt = schedule.endedAt;
      if (!at.isAfter(now) ||
          at.isBefore(schedule.effectiveFrom) ||
          (endedAt != null && !at.isBefore(endedAt))) {
        continue;
      }
      doses.putIfAbsent(
        (schedule.id, at),
        () => HistoryDose(
          medicationId: schedule.medicationId,
          medicationName: schedule.medicationName,
          scheduleId: schedule.id,
          scheduledAt: at,
          takenAt: null,
          status: HistoryDoseStatus.pending,
          statusSource: 'inferred',
        ),
      );
    }
    final added = doses.length - before;
    if (added == 0) continue;
    final summary = group?.summary;
    groups[day] = DateHistoryGroup(
      day,
      AdherenceSummary(
        total: (summary?.total ?? 0) + added,
        taken: summary?.taken ?? 0,
        late: summary?.late ?? 0,
        missed: summary?.missed ?? 0,
        pending: (summary?.pending ?? 0) + added,
        unverified: summary?.unverified ?? 0,
        counted: summary?.counted ?? 0,
        rate: summary?.rate,
      ),
      doses.values.toList()
        ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt)),
    );
  }
  return groups;
}
