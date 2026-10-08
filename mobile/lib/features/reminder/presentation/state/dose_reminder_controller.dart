import 'package:flutter/foundation.dart';

import '../../../../core/contracts/dose_outbox.dart';
import '../../../../core/notification/reminder_scheduler.dart';
import '../../../../core/storage/local_db/local_models.dart';
import '../../domain/entities/dose_reminder.dart';

enum DoseReminderItemStatus { pending, saving, confirmed, failed }

/// Coordinates local-first confirmation, retry, snooze, and skip actions.
///
/// Confirmation state is tracked per occurrence so a partial group failure can
/// retry only the medicines that were not persisted successfully.
class DoseReminderController extends ChangeNotifier {
  DoseReminderController({
    required this.group,
    required DoseOutbox outbox,
    required ReminderScheduler scheduler,
    ReminderClock? clock,
  })  : _outbox = outbox,
        _scheduler = scheduler,
        _clock = clock ?? DateTime.now {
    for (final item in group.items) {
      _statuses[item.occurrenceKey] = DoseReminderItemStatus.pending;
    }
  }

  final DoseReminderGroup group;
  final DoseOutbox _outbox;
  final ReminderScheduler _scheduler;
  final ReminderClock _clock;
  final Map<String, DoseReminderItemStatus> _statuses = {};
  final Map<String, LocalDoseLog> _records = {};

  bool _confirmingGroup = false;
  bool _snoozing = false;
  bool _disposed = false;
  String? _message;

  DoseReminderItemStatus statusOf(DoseReminderItem item) =>
      _statuses[item.occurrenceKey] ?? DoseReminderItemStatus.pending;

  LocalDoseLog? recordOf(DoseReminderItem item) => _records[item.occurrenceKey];
  String? get message => _message;
  bool get isConfirmingGroup => _confirmingGroup;
  bool get isSnoozing => _snoozing;
  bool get isConfirming =>
      _confirmingGroup ||
      _statuses.values.contains(DoseReminderItemStatus.saving);
  bool get isBusy => isConfirming || _snoozing;
  bool get allConfirmed => group.items.every(
        (item) => statusOf(item) == DoseReminderItemStatus.confirmed,
      );

  /// Persists one occurrence unless it is already saving or confirmed.
  Future<bool> confirmItem(DoseReminderItem item) {
    if (isBusy) return Future.value(false);
    return _confirm(item);
  }

  Future<bool> _confirm(DoseReminderItem item) async {
    final current = statusOf(item);
    if (current == DoseReminderItemStatus.saving ||
        current == DoseReminderItemStatus.confirmed) {
      return current == DoseReminderItemStatus.confirmed;
    }

    _statuses[item.occurrenceKey] = DoseReminderItemStatus.saving;
    _message = null;
    _notify();

    try {
      final record = await _outbox.enqueue(
        medicationScheduleId: item.medicationScheduleId,
        scheduledAt: item.scheduledAt,
        takenAt: _clock().toUtc(),
      );
      _records[item.occurrenceKey] = record;
      _statuses[item.occurrenceKey] = DoseReminderItemStatus.confirmed;
      _notify();
      return true;
    } catch (_) {
      _statuses[item.occurrenceKey] = DoseReminderItemStatus.failed;
      _message = 'Không thể lưu xác nhận. Vui lòng thử lại.';
      _notify();
      return false;
    }
  }

  /// Confirms every unconfirmed occurrence and preserves partial successes.
  Future<bool> confirmAll() async {
    if (isBusy) return false;
    _confirmingGroup = true;
    _message = null;
    _notify();

    var succeeded = true;
    try {
      for (final item in group.items) {
        if (statusOf(item) == DoseReminderItemStatus.confirmed) continue;
        if (!await _confirm(item)) succeeded = false;
      }
      if (!succeeded) {
        _message = 'Một số thuốc chưa được xác nhận. Hãy thử lại.';
      }
      return succeeded && allConfirmed;
    } finally {
      _confirmingGroup = false;
      _notify();
    }
  }

  /// Schedules every occurrence in the group ten minutes from the injected clock.
  Future<bool> snooze() async {
    if (isBusy) return false;
    _snoozing = true;
    _message = null;
    _notify();

    final remindAt = _clock().toUtc().add(const Duration(minutes: 10));
    try {
      for (final item in group.items) {
        await _scheduler.snooze(
          medicationScheduleId: item.medicationScheduleId,
          scheduledAt: item.scheduledAt,
          remindAt: remindAt,
        );
      }
      return true;
    } catch (_) {
      _message = 'Không thể đặt nhắc lại. Vui lòng thử lại.';
      return false;
    } finally {
      _snoozing = false;
      _notify();
    }
  }

  /// Closes the reminder without writing a taken or missed dose.
  DoseReminderResult? skip() => isBusy ? null : DoseReminderResult.skipped;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
