/// Boundary between the reminder UI and the platform notification adapter.
///
/// Task 2.11 only needs snoozing. Task 2.07 provides the concrete Android/iOS
/// implementation that schedules the local notification.
abstract interface class ReminderScheduler {
  Future<void> snooze({
    required int medicationScheduleId,
    required DateTime scheduledAt,
    required DateTime remindAt,
  });
}
