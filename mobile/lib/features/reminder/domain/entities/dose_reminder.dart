import '../../../../core/contracts/dose_outbox.dart';
import '../../../../core/notification/reminder_scheduler.dart';

/// One scheduled medicine occurrence displayed by the dose reminder screen.
///
/// [scheduledAt] stays in UTC because it is part of the outbox idempotency key.
class DoseReminderItem {
  DoseReminderItem({
    required this.medicationScheduleId,
    required this.scheduledAt,
    required this.medicationName,
    required this.dosageText,
    required this.instruction,
  }) {
    if (!scheduledAt.isUtc) {
      throw ArgumentError.value(
        scheduledAt,
        'scheduledAt',
        'Reminder occurrences must use UTC.',
      );
    }
  }

  final int medicationScheduleId;
  final DateTime scheduledAt;
  final String medicationName;
  final String dosageText;
  final String instruction;

  /// Stable in-memory key matching the persisted occurrence identity.
  String get occurrenceKey =>
      '$medicationScheduleId:${scheduledAt.microsecondsSinceEpoch}';
}

/// Medicines that share one scheduled time and are presented as one reminder.
class DoseReminderGroup {
  DoseReminderGroup(Iterable<DoseReminderItem> items)
      : items = List.unmodifiable(items) {
    if (this.items.isEmpty) {
      throw ArgumentError.value(
          items, 'items', 'A reminder group cannot be empty.');
    }

    final firstTime = this.items.first.scheduledAt;
    if (this
        .items
        .any((item) => !item.scheduledAt.isAtSameMomentAs(firstTime))) {
      throw ArgumentError.value(
        items,
        'items',
        'All medicines in a reminder group must share the same scheduled time.',
      );
    }
  }

  final List<DoseReminderItem> items;

  DateTime get scheduledAt => items.first.scheduledAt;
  bool get hasMultipleItems => items.length > 1;
}

typedef ReminderClock = DateTime Function();

/// Typed dependencies passed from the notification entry point to the route.
class DoseReminderRouteArguments {
  const DoseReminderRouteArguments({
    required this.group,
    required this.outbox,
    required this.scheduler,
    this.clock,
  });

  final DoseReminderGroup group;
  final DoseOutbox outbox;
  final ReminderScheduler scheduler;
  final ReminderClock? clock;
}

enum DoseReminderResult { confirmed, snoozed, skipped }
