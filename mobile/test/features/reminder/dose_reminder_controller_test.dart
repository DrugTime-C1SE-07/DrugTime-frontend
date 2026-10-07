import 'dart:async';

import 'package:drugtime_mobile/core/contracts/dose_outbox.dart';
import 'package:drugtime_mobile/core/notification/reminder_scheduler.dart';
import 'package:drugtime_mobile/core/storage/local_db/local_models.dart';
import 'package:drugtime_mobile/features/reminder/domain/entities/dose_reminder.dart';
import 'package:drugtime_mobile/features/reminder/presentation/state/dose_reminder_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('confirm single enqueues occurrence and updates state', () async {
    final outbox = _FakeDoseOutbox();
    final item = _item(1);
    final controller = _controller(items: [item], outbox: outbox);

    expect(await controller.confirmItem(item), isTrue);

    expect(outbox.calls, hasLength(1));
    expect(outbox.calls.single.scheduleId, 1);
    expect(outbox.calls.single.scheduledAt, item.scheduledAt);
    expect(outbox.calls.single.takenAt, DateTime.utc(2026, 10, 7, 13, 5));
    expect(controller.statusOf(item), DoseReminderItemStatus.confirmed);
    expect(controller.recordOf(item)?.clientUuid, 'uuid-1');
  });

  test('double confirm while saving calls outbox once', () async {
    final completer = Completer<LocalDoseLog>();
    final outbox = _FakeDoseOutbox(completer: completer);
    final item = _item(1);
    final controller = _controller(items: [item], outbox: outbox);

    final first = controller.confirmItem(item);
    final second = controller.confirmItem(item);

    expect(await second, isFalse);
    expect(outbox.calls, hasLength(1));
    completer.complete(_record(item, 'same-uuid'));
    expect(await first, isTrue);
    expect(outbox.calls, hasLength(1));
  });

  test('outbox failure keeps item retryable', () async {
    final outbox = _FakeDoseOutbox(failOnceFor: {1});
    final item = _item(1);
    final controller = _controller(items: [item], outbox: outbox);

    expect(await controller.confirmItem(item), isFalse);
    expect(controller.statusOf(item), DoseReminderItemStatus.failed);
    expect(controller.message, contains('thử lại'));

    expect(await controller.confirmItem(item), isTrue);
    expect(controller.statusOf(item), DoseReminderItemStatus.confirmed);
    expect(outbox.calls, hasLength(2));
  });

  test('confirm one item does not change siblings', () async {
    final outbox = _FakeDoseOutbox();
    final first = _item(1);
    final second = _item(2);
    final controller = _controller(items: [first, second], outbox: outbox);

    await controller.confirmItem(first);

    expect(controller.statusOf(first), DoseReminderItemStatus.confirmed);
    expect(controller.statusOf(second), DoseReminderItemStatus.pending);
  });

  test('confirm group enqueues every occurrence', () async {
    final outbox = _FakeDoseOutbox();
    final items = [_item(1), _item(2), _item(3)];
    final controller = _controller(items: items, outbox: outbox);

    expect(await controller.confirmAll(), isTrue);

    expect(outbox.calls.map((call) => call.scheduleId), [1, 2, 3]);
    expect(controller.allConfirmed, isTrue);
  });

  test('partial group failure retries only unconfirmed items', () async {
    final outbox = _FakeDoseOutbox(failOnceFor: {2});
    final items = [_item(1), _item(2), _item(3)];
    final controller = _controller(items: items, outbox: outbox);

    expect(await controller.confirmAll(), isFalse);
    expect(controller.statusOf(items[0]), DoseReminderItemStatus.confirmed);
    expect(controller.statusOf(items[1]), DoseReminderItemStatus.failed);
    expect(controller.statusOf(items[2]), DoseReminderItemStatus.confirmed);

    expect(await controller.confirmAll(), isTrue);
    expect(outbox.calls.map((call) => call.scheduleId), [1, 2, 3, 2]);
  });

  test('snooze schedules each original occurrence ten minutes later', () async {
    final scheduler = _FakeReminderScheduler();
    final items = [_item(1), _item(2)];
    final outbox = _FakeDoseOutbox();
    final controller = _controller(
      items: items,
      outbox: outbox,
      scheduler: scheduler,
    );

    expect(await controller.snooze(), isTrue);

    expect(outbox.calls, isEmpty);
    expect(scheduler.calls, hasLength(2));
    expect(scheduler.calls.first.scheduledAt, items.first.scheduledAt);
    expect(scheduler.calls.first.remindAt, DateTime.utc(2026, 10, 7, 13, 15));
  });

  test('skip returns result without enqueue', () {
    final outbox = _FakeDoseOutbox();
    final controller = _controller(items: [_item(1)], outbox: outbox);

    expect(controller.skip(), DoseReminderResult.skipped);
    expect(outbox.calls, isEmpty);
  });
}

DoseReminderController _controller({
  required List<DoseReminderItem> items,
  required _FakeDoseOutbox outbox,
  _FakeReminderScheduler? scheduler,
}) {
  return DoseReminderController(
    group: DoseReminderGroup(items),
    outbox: outbox,
    scheduler: scheduler ?? _FakeReminderScheduler(),
    clock: () => DateTime.utc(2026, 10, 7, 13, 5),
  );
}

DoseReminderItem _item(int scheduleId) {
  return DoseReminderItem(
    medicationScheduleId: scheduleId,
    scheduledAt: DateTime.utc(2026, 10, 7, 13),
    medicationName: 'Thuốc $scheduleId',
    dosageText: '1 viên',
    instruction: 'Sau ăn tối',
  );
}

LocalDoseLog _record(DoseReminderItem item, String uuid) {
  return LocalDoseLog(
    clientUuid: uuid,
    medicationScheduleId: item.medicationScheduleId,
    scheduledAt: item.scheduledAt,
    takenAt: DateTime.utc(2026, 10, 7, 13, 5),
    status: DoseLogStatus.taken,
    syncState: DoseLogSyncState.pendingUpload,
    localUpdatedAt: DateTime.utc(2026, 10, 7, 13, 5),
  );
}

class _EnqueueCall {
  const _EnqueueCall(this.scheduleId, this.scheduledAt, this.takenAt);

  final int scheduleId;
  final DateTime scheduledAt;
  final DateTime takenAt;
}

class _FakeDoseOutbox implements DoseOutbox {
  _FakeDoseOutbox({this.completer, Set<int>? failOnceFor})
      : _failOnceFor = failOnceFor ?? {};

  final Completer<LocalDoseLog>? completer;
  final Set<int> _failOnceFor;
  final List<_EnqueueCall> calls = [];

  @override
  Future<LocalDoseLog> enqueue({
    required int medicationScheduleId,
    required DateTime scheduledAt,
    required DateTime takenAt,
  }) async {
    calls.add(_EnqueueCall(medicationScheduleId, scheduledAt, takenAt));
    if (_failOnceFor.remove(medicationScheduleId)) {
      throw StateError('local write failed');
    }
    if (completer case final pending?) return pending.future;
    return _record(
      _item(medicationScheduleId),
      'uuid-$medicationScheduleId',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SnoozeCall {
  const _SnoozeCall(this.scheduleId, this.scheduledAt, this.remindAt);

  final int scheduleId;
  final DateTime scheduledAt;
  final DateTime remindAt;
}

class _FakeReminderScheduler implements ReminderScheduler {
  final List<_SnoozeCall> calls = [];

  @override
  Future<void> snooze({
    required int medicationScheduleId,
    required DateTime scheduledAt,
    required DateTime remindAt,
  }) async {
    calls.add(_SnoozeCall(medicationScheduleId, scheduledAt, remindAt));
  }
}
