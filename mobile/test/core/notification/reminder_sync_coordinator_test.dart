import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:drugtime_mobile/core/notification/notification_id.dart';
import 'package:drugtime_mobile/core/notification/notification_service.dart';
import 'package:drugtime_mobile/core/notification/reminder_notification_scheduler.dart';
import 'package:drugtime_mobile/core/notification/reminder_sync_coordinator.dart';
import 'package:drugtime_mobile/core/storage/local_db/local_medication_store.dart';
import 'package:drugtime_mobile/core/storage/local_db/local_models.dart';
import 'package:drugtime_mobile/core/sync/schedule_sync_service.dart';

import 'reminder_notification_scheduler_test.dart'
    show MockReminderNotificationPlatform;

// 07:00 giờ Việt Nam, trước giờ uống 08:00 cùng ngày.
final _now = DateTime.utc(2026, 11, 12, 0, 0);

void main() {
  late tz.Location vn;
  late MockReminderNotificationPlatform platform;
  late _MemoryStore store;
  late _Remote remote;
  late List<String> logs;
  late ReminderSyncCoordinator coordinator;

  setUpAll(() {
    tz_data.initializeTimeZones();
    vn = tz.getLocation('Asia/Ho_Chi_Minh');
  });

  setUp(() {
    platform = MockReminderNotificationPlatform();
    store = _MemoryStore();
    remote = _Remote();
    logs = [];
    coordinator = ReminderSyncCoordinator(
      syncService:
          ScheduleSyncService(remoteDataSource: remote, localStore: store),
      localStore: store,
      scheduler: ReminderNotificationScheduler(
        platform: platform,
        location: vn,
        clockProvider: () => _now,
        targetPlatform: TargetPlatform.android,
      ),
      clock: () => _now,
      onLog: logs.add,
    );
  });

  test(
      'refresh schedules full-screen reminders for schedules fetched from the API (regression)',
      () async {
    remote.schedules = [_schedule(1)];

    await coordinator.refresh('patient-1');

    expect(remote.lastPatientId, 'patient-1');
    expect(platform.zonedScheduleCalls, isNotEmpty);
    final first = platform.zonedScheduleCalls.first;
    expect(first.scheduledDate.toUtc(), DateTime.utc(2026, 11, 12, 1, 0));
    final android = first.notificationDetails.android!;
    expect(android.fullScreenIntent, isTrue);
    expect(android.channelId, NotificationService.reminderChannelId);
    expect(first.title, ReminderNotificationScheduler.defaultTitle);
    expect(first.body, isNot(contains('Paracetamol')));
    expect(
      platform.zonedScheduleCalls.every((c) => c.scheduledDate
          .toUtc()
          .isBefore(_now.add(const Duration(days: 7)))),
      isTrue,
    );
  });

  test('refresh cancels reminders of a schedule removed on the server',
      () async {
    remote.schedules = [_schedule(1)];
    await coordinator.refresh('patient-1');
    final oldIds = platform.zonedScheduleCalls.map((c) => c.id).toList();
    platform.pendingRequests = platform.zonedScheduleCalls
        .map((c) => PendingNotificationRequest(c.id, c.title, c.body, c.payload))
        .toList();
    platform.zonedScheduleCalls.clear();

    remote.schedules = [];
    await coordinator.refresh('patient-1');

    expect(platform.cancelCalls, containsAll(oldIds));
    expect(platform.zonedScheduleCalls, isEmpty);
  });

  test('refresh still schedules from local data when the API fails', () async {
    remote.schedules = [_schedule(1)];
    await coordinator.refresh('patient-1');
    platform.zonedScheduleCalls.clear();

    remote.error = Exception('offline');
    await coordinator.refresh('patient-1');

    expect(platform.zonedScheduleCalls, isNotEmpty);
    expect(logs.any((m) => m.contains('offline')), isTrue);
  });

  test('refresh skips schedules with reminders disabled', () async {
    remote.schedules = [_schedule(1, reminderEnabled: false)];

    await coordinator.refresh('patient-1');

    expect(platform.zonedScheduleCalls, isEmpty);
  });

  test('refresh keeps a snoozed reminder; clear still cancels it (regression)',
      () async {
    remote.schedules = [_schedule(1)];
    // Liều 06:30 VN (đã qua) được hoãn tới 07:10 VN: payload giữ giờ gốc.
    final snoozed = NotificationPayload(
      medicationScheduleId: 1,
      scheduledAt: DateTime.utc(2026, 11, 11, 23, 30),
    );
    final snoozedId =
        notificationIdFor(snoozed.medicationScheduleId, snoozed.scheduledAt);
    final future = NotificationPayload(
      medicationScheduleId: 1,
      scheduledAt: DateTime.utc(2026, 11, 12, 1, 0),
    );
    final futureId =
        notificationIdFor(future.medicationScheduleId, future.scheduledAt);
    platform.pendingRequests = [
      PendingNotificationRequest(snoozedId, 't', 'b', snoozed.serialize()),
      PendingNotificationRequest(futureId, 't', 'b', future.serialize()),
    ];

    await coordinator.refresh('patient-1');

    expect(platform.cancelCalls, isNot(contains(snoozedId)));
    expect(platform.cancelCalls, contains(futureId));

    platform.cancelCalls.clear();
    await coordinator.clear();
    expect(platform.cancelCalls, containsAll([snoozedId, futureId]));
  });

  test('refresh skips occurrences already recorded in the dose log', () async {
    remote.schedules = [_schedule(1)];
    store.recorded.add('1@${DateTime.utc(2026, 11, 12, 1, 0).toIso8601String()}');

    await coordinator.refresh('patient-1');

    final dates = platform.zonedScheduleCalls.map((c) =>
        DateTime.fromMillisecondsSinceEpoch(
            c.scheduledDate.millisecondsSinceEpoch,
            isUtc: true));
    expect(dates, isNot(contains(DateTime.utc(2026, 11, 12, 1, 0))));
    expect(dates, contains(DateTime.utc(2026, 11, 13, 1, 0)));
  });

  test('clear cancels medication reminders only', () async {
    final reminderPayload = NotificationPayload(
      medicationScheduleId: 1,
      scheduledAt: DateTime.utc(2026, 11, 12, 1),
    ).serialize();
    platform.pendingRequests = [
      PendingNotificationRequest(11, 't', 'b', reminderPayload),
      const PendingNotificationRequest(22, 't', 'b', 'family:5'),
      const PendingNotificationRequest(33, 't', 'b', null),
    ];

    await coordinator.clear();

    expect(platform.cancelCalls, [11]);
  });
}

LocalMedicationSchedule _schedule(int id, {bool reminderEnabled = true}) =>
    LocalMedicationSchedule(
      id: id,
      patientUserId: 'patient-1',
      userMedicationId: 10 + id,
      medicationId: 100 + id,
      medicationName: 'Paracetamol',
      quantityPerDose: '1',
      dosesPerDay: 1,
      intakeTime: '08:00:00',
      daysOfWeek: const [1, 2, 3, 4, 5, 6, 7],
      reminderEnabled: reminderEnabled,
      effectiveFrom: DateTime.utc(2026, 1, 1),
      serverSyncedAt: DateTime.utc(2026, 11, 1),
    );

class _Remote implements ScheduleRemoteDataSource {
  List<LocalMedicationSchedule> schedules = [];
  Exception? error;
  String? lastPatientId;

  @override
  Future<List<LocalMedicationSchedule>> fetchSchedules({
    required String patientId,
  }) async {
    lastPatientId = patientId;
    final e = error;
    if (e != null) throw e;
    return schedules;
  }
}

class _MemoryStore implements LocalMedicationStore {
  final Map<String, List<LocalMedicationSchedule>> _byPatient = {};
  final Map<String, String> _meta = {};
  final Set<String> recorded = {};

  @override
  Future<bool> hasDoseLog({
    required int medicationScheduleId,
    required DateTime scheduledAt,
  }) async =>
      recorded.contains(
          '$medicationScheduleId@${scheduledAt.toUtc().toIso8601String()}');

  @override
  Future<void> replaceSchedules({
    required String patientId,
    required List<LocalMedicationSchedule> schedules,
  }) async =>
      _byPatient[patientId] = List.of(schedules);

  @override
  Future<List<LocalMedicationSchedule>> getActiveSchedules({
    String? patientId,
  }) async =>
      (_byPatient[patientId] ?? const <LocalMedicationSchedule>[])
          .where((s) => s.isActive)
          .toList();

  @override
  Future<void> setMeta(String key, String value) async => _meta[key] = value;

  @override
  Future<String?> getMeta(String key) async => _meta[key];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}
