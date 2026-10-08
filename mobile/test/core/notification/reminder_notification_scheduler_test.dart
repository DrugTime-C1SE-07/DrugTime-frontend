import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:drugtime_mobile/core/notification/notification_id.dart';
import 'package:drugtime_mobile/core/notification/notification_service.dart';
import 'package:drugtime_mobile/core/notification/reminder_notification_scheduler.dart';
import 'package:drugtime_mobile/core/notification/reminder_occurrence_generator.dart';

class ScheduledCallRecord {
  ScheduledCallRecord({
    required this.id,
    required this.title,
    required this.body,
    required this.scheduledDate,
    required this.notificationDetails,
    required this.androidScheduleMode,
    required this.uiLocalNotificationDateInterpretation,
    this.payload,
    this.matchDateTimeComponents,
  });

  final int id;
  final String? title;
  final String? body;
  final tz.TZDateTime scheduledDate;
  final NotificationDetails notificationDetails;
  final AndroidScheduleMode androidScheduleMode;
  final UILocalNotificationDateInterpretation
      uiLocalNotificationDateInterpretation;
  final String? payload;
  final DateTimeComponents? matchDateTimeComponents;
}

class MockReminderNotificationPlatform implements NotificationPlatform {
  final List<ScheduledCallRecord> zonedScheduleCalls = [];
  final List<int> cancelCalls = [];
  List<PendingNotificationRequest> pendingRequests = [];
  bool shouldThrowOnExactAlarm = false;

  @override
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
  }) async {
    return true;
  }

  @override
  Future<void> createNotificationChannel(
      AndroidNotificationChannel channel) async {}

  @override
  Future<void> zonedSchedule(
    int id,
    String? title,
    String? body,
    tz.TZDateTime scheduledDate,
    NotificationDetails notificationDetails, {
    required AndroidScheduleMode androidScheduleMode,
    required UILocalNotificationDateInterpretation
        uiLocalNotificationDateInterpretation,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    if (shouldThrowOnExactAlarm &&
        androidScheduleMode == AndroidScheduleMode.exactAllowWhileIdle) {
      throw Exception('exact_alarms_not_permitted');
    }

    zonedScheduleCalls.add(
      ScheduledCallRecord(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: notificationDetails,
        androidScheduleMode: androidScheduleMode,
        uiLocalNotificationDateInterpretation:
            uiLocalNotificationDateInterpretation,
        payload: payload,
        matchDateTimeComponents: matchDateTimeComponents,
      ),
    );
  }

  @override
  Future<void> cancel(int id, {String? tag}) async {
    cancelCalls.add(id);
  }

  @override
  Future<List<PendingNotificationRequest>> pendingNotificationRequests() async {
    return pendingRequests;
  }
}

void main() {
  late tz.Location vnLocation;
  late MockReminderNotificationPlatform mockPlatform;

  setUpAll(() {
    tz_data.initializeTimeZones();
    vnLocation = tz.getLocation('Asia/Ho_Chi_Minh');
  });

  setUp(() {
    mockPlatform = MockReminderNotificationPlatform();
  });

  group(
      'ReminderNotificationScheduler.scheduleOccurrences (AC1, AC2, AC3, AC7)',
      () {
    test(
        'AC1: schedules N future occurrences via zonedSchedule with exactAllowWhileIdle, correct ID, payload, Vietnam timezone, channel and action button',
        () async {
      // Giả lập đồng hồ hiện tại là 07:00 UTC ngày 2026-10-08
      final nowUtc = DateTime.utc(2026, 10, 8, 7, 0, 0);
      final scheduler = ReminderNotificationScheduler(
        platform: mockPlatform,
        location: vnLocation,
        clockProvider: () => nowUtc,
      );

      // 08:00 VN ngày 2026-10-09 là 01:00 UTC (tương lai)
      final occ1 = ReminderOccurrence(
        medicationScheduleId: 10,
        scheduledAt: DateTime.utc(2026, 10, 9, 1, 0, 0),
      );
      // 12:00 VN ngày 2026-10-09 là 05:00 UTC (tương lai)
      final occ2 = ReminderOccurrence(
        medicationScheduleId: 11,
        scheduledAt: DateTime.utc(2026, 10, 9, 5, 0, 0),
      );

      await scheduler.scheduleOccurrences([occ1, occ2]);

      expect(mockPlatform.zonedScheduleCalls.length, 2);

      // Kiểm tra cuộc gọi 1
      final call1 = mockPlatform.zonedScheduleCalls[0];
      final expectedId1 = notificationIdFor(10, occ1.scheduledAt);
      expect(call1.id, expectedId1);
      expect(call1.title, 'Nhắc uống thuốc');
      // NT-02: Không chứa tên thuốc trên màn khóa
      expect(call1.body, contains('Đã đến giờ uống thuốc'));
      expect(call1.body, isNot(contains('Paracetamol')));

      // Thời gian chuyển sang Asia/Ho_Chi_Minh (+7)
      expect(call1.scheduledDate.location.name, 'Asia/Ho_Chi_Minh');
      expect(call1.scheduledDate.year, 2026);
      expect(call1.scheduledDate.month, 10);
      expect(call1.scheduledDate.day, 9);
      expect(call1.scheduledDate.hour, 8); // 01:00 UTC + 7 = 08:00 VN
      expect(call1.scheduledDate.minute, 0);

      // Payload JSON hợp lệ
      final parsedPayload1 = NotificationPayload.tryParse(call1.payload);
      expect(parsedPayload1, isNotNull);
      expect(parsedPayload1!.medicationScheduleId, 10);
      expect(parsedPayload1.scheduledAt, occ1.scheduledAt);

      // Channel details và Nút action "Đã uống"
      final androidDetails = call1.notificationDetails.android;
      expect(androidDetails, isNotNull);
      expect(androidDetails!.channelId, NotificationService.reminderChannelId);
      expect(
          call1.androidScheduleMode, AndroidScheduleMode.exactAllowWhileIdle);
      expect(call1.uiLocalNotificationDateInterpretation,
          UILocalNotificationDateInterpretation.absoluteTime);

      final actions = androidDetails.actions;
      expect(actions, isNotNull);
      expect(actions!.length, 1);
      final takeDoseAction = actions.first;
      expect(takeDoseAction.id, 'take_dose');
      expect(takeDoseAction.title, 'Đã uống');
      expect(takeDoseAction.showsUserInterface, isFalse);
      expect(takeDoseAction.cancelNotification, isTrue);

      // Kiểm tra cuộc gọi 2
      final call2 = mockPlatform.zonedScheduleCalls[1];
      expect(call2.id, notificationIdFor(11, occ2.scheduledAt));
      expect(call2.scheduledDate.hour, 12);
    });

    test(
        'AC2: skips occurrences scheduled in the past or at current clock time (scheduledAt <= now)',
        () async {
      final nowUtc = DateTime.utc(2026, 10, 8, 7, 0, 0);
      final scheduler = ReminderNotificationScheduler(
        platform: mockPlatform,
        location: vnLocation,
        clockProvider: () => nowUtc,
      );

      final pastOcc = ReminderOccurrence(
        medicationScheduleId: 10,
        scheduledAt: DateTime.utc(2026, 10, 8, 6, 59, 59),
      );
      final exactNowOcc = ReminderOccurrence(
        medicationScheduleId: 11,
        scheduledAt: DateTime.utc(2026, 10, 8, 7, 0, 0),
      );
      final futureOcc = ReminderOccurrence(
        medicationScheduleId: 12,
        scheduledAt: DateTime.utc(2026, 10, 8, 7, 0, 1),
      );

      await scheduler.scheduleOccurrences([pastOcc, exactNowOcc, futureOcc]);

      // Chỉ có 1 lượt tương lai duy nhất được lên lịch
      expect(mockPlatform.zonedScheduleCalls.length, 1);
      expect(mockPlatform.zonedScheduleCalls.first.id,
          notificationIdFor(12, futureOcc.scheduledAt));
    });

    test(
        'AC3: detects hash ID collisions, drops second colliding occurrence with log, keeps original scheduledAt',
        () async {
      final nowUtc = DateTime.utc(2026, 10, 8, 7, 0, 0);
      final logMessages = <String>[];
      final scheduler = ReminderNotificationScheduler(
        platform: mockPlatform,
        location: vnLocation,
        clockProvider: () => nowUtc,
        onLog: (msg) => logMessages.add(msg),
      );

      final scheduledAt = DateTime.utc(2026, 10, 9, 1, 0, 0);
      // 2 lượt có cùng scheduleId và cùng scheduledAt (hoặc va chạm băm)
      final occ1 = ReminderOccurrence(
        medicationScheduleId: 10,
        scheduledAt: scheduledAt,
      );
      final occ2 = ReminderOccurrence(
        medicationScheduleId: 10,
        scheduledAt: scheduledAt,
      );

      await scheduler.scheduleOccurrences([occ1, occ2]);

      // Bỏ qua lượt trùng thứ hai
      expect(mockPlatform.zonedScheduleCalls.length, 1);
      expect(logMessages.any((msg) => msg.contains('Va chạm ID thông báo')),
          isTrue);
      // Mốc thời gian giữ nguyên, không bị tịnh tiến
      expect(mockPlatform.zonedScheduleCalls.first.scheduledDate.hour, 8);
    });

    test(
        'AC7: falls back to inexactAllowWhileIdle and logs warning when exact alarm throws exception',
        () async {
      final nowUtc = DateTime.utc(2026, 10, 8, 7, 0, 0);
      final logMessages = <String>[];
      mockPlatform.shouldThrowOnExactAlarm = true;

      final scheduler = ReminderNotificationScheduler(
        platform: mockPlatform,
        location: vnLocation,
        clockProvider: () => nowUtc,
        onLog: (msg) => logMessages.add(msg),
      );

      final futureOcc = ReminderOccurrence(
        medicationScheduleId: 10,
        scheduledAt: DateTime.utc(2026, 10, 9, 1, 0, 0),
      );

      await scheduler.scheduleOccurrences([futureOcc]);

      // Cuộc gọi thành công sau fallback sang inexactAllowWhileIdle
      expect(mockPlatform.zonedScheduleCalls.length, 1);
      final call = mockPlatform.zonedScheduleCalls.first;
      expect(
          call.androidScheduleMode, AndroidScheduleMode.inexactAllowWhileIdle);
      expect(
        logMessages.any((msg) =>
            msg.contains('exact_alarms_not_permitted') ||
            msg.contains('inexactAllowWhileIdle')),
        isTrue,
      );
    });
  });

  group('ReminderNotificationScheduler.cancelOccurrence (AC4)', () {
    test('AC4: cancels exact notification ID idempotently', () async {
      final scheduler = ReminderNotificationScheduler(
        platform: mockPlatform,
        location: vnLocation,
      );

      final targetTime = DateTime.utc(2026, 10, 9, 1, 0, 0);
      await scheduler.cancelOccurrence(
        medicationScheduleId: 42,
        scheduledAt: targetTime,
      );

      final expectedId = notificationIdFor(42, targetTime);
      expect(mockPlatform.cancelCalls, [expectedId]);

      // Gọi lần 2 vẫn không sinh lỗi (idempotent)
      await scheduler.cancelOccurrence(
        medicationScheduleId: 42,
        scheduledAt: targetTime,
      );
      expect(mockPlatform.cancelCalls, [expectedId, expectedId]);
    });
  });

  group('ReminderNotificationScheduler.cancelAllForSchedule (AC5)', () {
    test(
        'AC5: cancels only matching pending requests, ignores corrupt payloads',
        () async {
      final scheduler = ReminderNotificationScheduler(
        platform: mockPlatform,
        location: vnLocation,
      );

      final payloadMatching1 = NotificationPayload(
        medicationScheduleId: 88,
        scheduledAt: DateTime.utc(2026, 10, 9, 1, 0, 0),
      );
      final payloadMatching2 = NotificationPayload(
        medicationScheduleId: 88,
        scheduledAt: DateTime.utc(2026, 10, 9, 5, 0, 0),
      );
      final payloadOther = NotificationPayload(
        medicationScheduleId: 99,
        scheduledAt: DateTime.utc(2026, 10, 9, 1, 0, 0),
      );

      mockPlatform.pendingRequests = [
        PendingNotificationRequest(
          101,
          'Nhắc',
          'Đến giờ',
          payloadMatching1.serialize(),
        ),
        PendingNotificationRequest(
          102,
          'Nhắc',
          'Đến giờ',
          payloadOther.serialize(),
        ),
        PendingNotificationRequest(
          103,
          'Nhắc',
          'Đến giờ',
          payloadMatching2.serialize(),
        ),
        const PendingNotificationRequest(
          104,
          'Nhắc',
          'Đến giờ',
          'corrupt-json-string',
        ),
        const PendingNotificationRequest(
          105,
          'Nhắc',
          'Đến giờ',
          null,
        ),
      ];

      await scheduler.cancelAllForSchedule(88);

      // Chỉ hủy request 101 và 103 (khớp scheduleId 88)
      expect(mockPlatform.cancelCalls, [101, 103]);
    });
  });

  group('ReminderNotificationScheduler.handleNotificationResponse (AC6)', () {
    test('AC6: invokes onTakeDose callback and cancels notification', () async {
      NotificationPayload? receivedPayload;
      final scheduler = ReminderNotificationScheduler(
        platform: mockPlatform,
        location: vnLocation,
        onTakeDose: (payload) async {
          receivedPayload = payload;
        },
      );

      final scheduledAt = DateTime.utc(2026, 10, 9, 1, 0, 0);
      final payload = NotificationPayload(
        medicationScheduleId: 77,
        scheduledAt: scheduledAt,
      );

      final response = NotificationResponse(
        notificationResponseType:
            NotificationResponseType.selectedNotificationAction,
        actionId: 'take_dose',
        id: 555,
        payload: payload.serialize(),
      );

      await scheduler.handleNotificationResponse(response);

      expect(receivedPayload, isNotNull);
      expect(receivedPayload!.medicationScheduleId, 77);
      expect(receivedPayload!.scheduledAt, scheduledAt);
      expect(mockPlatform.cancelCalls, contains(555));
    });

    test('AC6: safely ignores corrupt payload or other action without error',
        () async {
      NotificationPayload? receivedPayload;
      final scheduler = ReminderNotificationScheduler(
        platform: mockPlatform,
        location: vnLocation,
        onTakeDose: (payload) async {
          receivedPayload = payload;
        },
      );

      // Action khác 'take_dose'
      await scheduler.handleNotificationResponse(
        const NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotificationAction,
          actionId: 'snooze',
          id: 556,
          payload: 'some-payload',
        ),
      );
      expect(receivedPayload, isNull);

      // Payload hỏng
      await scheduler.handleNotificationResponse(
        const NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotificationAction,
          actionId: 'take_dose',
          id: 557,
          payload: 'corrupt-json',
        ),
      );
      expect(receivedPayload, isNull);
    });
  });

  group('Static source code checks (AC8)', () {
    test('AC8: scheduler source does not reference forbidden APIs', () {
      final forbiddenTerms = [
        'tz.local',
        'flutter_timezone',
        'DateTime.now()',
        'toLocal()',
        'timeZoneOffset',
      ];

      final file =
          File('lib/core/notification/reminder_notification_scheduler.dart');
      expect(file.existsSync(), isTrue, reason: '${file.path} must exist');
      final content = file.readAsStringSync();
      for (final term in forbiddenTerms) {
        expect(
          content.contains(term),
          isFalse,
          reason: '${file.path} must not contain "$term"',
        );
      }
    });
  });
}
