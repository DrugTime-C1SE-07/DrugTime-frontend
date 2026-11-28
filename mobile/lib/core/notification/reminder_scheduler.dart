import 'package:flutter/widgets.dart';

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

  Future<void> cancelOccurrence({
    int? scheduleId,
    int? medicationScheduleId,
    required DateTime scheduledAt,
  });

  Future<void> cancelAllForSchedule(int scheduleId);
}

/// Truyền [ReminderScheduler] xuống cây widget để màn chi tiết/sửa thuốc hủy lịch chờ.
class ReminderSchedulerScope extends InheritedWidget {
  const ReminderSchedulerScope({
    super.key,
    required this.scheduler,
    required super.child,
  });

  final ReminderScheduler? scheduler;

  static ReminderScheduler? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<ReminderSchedulerScope>()
      ?.scheduler;

  @override
  bool updateShouldNotify(ReminderSchedulerScope oldWidget) =>
      scheduler != oldWidget.scheduler;
}
