import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:drugtime_mobile/core/notification/notification_id.dart';
import 'package:drugtime_mobile/core/notification/notification_service.dart';

class MockNotificationPlatform implements NotificationPlatform {
  int initializeCallCount = 0;
  InitializationSettings? lastSettings;
  DidReceiveNotificationResponseCallback? onResponseCallback;
  final List<AndroidNotificationChannel> createdChannels = [];

  @override
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
  }) async {
    initializeCallCount++;
    lastSettings = settings;
    onResponseCallback = onDidReceiveNotificationResponse;
    return true;
  }

  @override
  Future<void> createNotificationChannel(
      AndroidNotificationChannel channel) async {
    createdChannels.add(channel);
  }

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
  }) async {}

  @override
  Future<void> cancel(int id, {String? tag}) async {}

  @override
  Future<List<PendingNotificationRequest>>
      pendingNotificationRequests() async => [];

  @override
  Future<NotificationAppLaunchDetails?> getNotificationAppLaunchDetails() async =>
      null;

  @override
  Future<bool?> requestFullScreenIntentPermission() async => true;
}

void main() {
  group('NotificationService.init (AC7 & AC8)', () {
    late MockNotificationPlatform mockPlatform;

    setUp(() {
      mockPlatform = MockNotificationPlatform();
    });

    test(
        'AC7: initializes Asia/Ho_Chi_Minh and configures Android & Darwin channels',
        () async {
      final service = NotificationService(platform: mockPlatform);

      expect(service.isInitialized, isFalse);
      await service.init();
      expect(service.isInitialized, isTrue);

      // Verify timezone is loaded and points to Asia/Ho_Chi_Minh
      expect(service.location.name, 'Asia/Ho_Chi_Minh');
      final tzTime = tz.TZDateTime.from(
        DateTime.utc(2026, 10, 7, 1, 0, 0),
        service.location,
      );
      expect(tzTime.hour, 8); // UTC+7

      // Verify platform initialize settings
      expect(mockPlatform.initializeCallCount, 1);
      final settings = mockPlatform.lastSettings!;
      expect(settings.android?.defaultIcon, '@mipmap/ic_launcher');
      expect(settings.iOS?.requestAlertPermission, isFalse);
      expect(settings.iOS?.requestBadgePermission, isFalse);
      expect(settings.iOS?.requestSoundPermission, isFalse);

      // Verify Android notification channel
      expect(mockPlatform.createdChannels.length, 1);
      final channel = mockPlatform.createdChannels.first;
      expect(channel.id, 'drugtime_reminder_channel');
      expect(channel.name, 'Nhắc uống thuốc');
      expect(channel.importance, Importance.max);
    });

    test('AC8: is idempotent when called repeatedly', () async {
      final service = NotificationService(platform: mockPlatform);

      await service.init();
      expect(mockPlatform.initializeCallCount, 1);
      expect(mockPlatform.createdChannels.length, 1);

      // Call init again: must not duplicate calls or throw errors
      await service.init();
      expect(mockPlatform.initializeCallCount, 1);
      expect(mockPlatform.createdChannels.length, 1);
      expect(service.isInitialized, isTrue);
    });
  });

  group('NotificationService actions (AC9)', () {
    late MockNotificationPlatform mockPlatform;

    setUp(() {
      mockPlatform = MockNotificationPlatform();
    });

    test('AC9: forwards parsed NotificationPayload when action is received',
        () async {
      NotificationPayload? receivedPayload;
      final service = NotificationService(
        platform: mockPlatform,
        onNotificationAction: (payload) {
          receivedPayload = payload;
        },
      );

      await service.init();
      expect(mockPlatform.onResponseCallback, isNotNull);

      final scheduledAt = DateTime.utc(2026, 10, 7, 1, 0, 0);
      final payload = NotificationPayload(
        medicationScheduleId: 99,
        scheduledAt: scheduledAt,
      );

      // Simulate plugin response callback
      mockPlatform.onResponseCallback!(
        NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotification,
          payload: payload.serialize(),
        ),
      );

      expect(receivedPayload, isNotNull);
      expect(receivedPayload!.medicationScheduleId, 99);
      expect(receivedPayload!.scheduledAt, scheduledAt);
    });

    test('AC9: ignores corrupt or invalid payload safely without throwing',
        () async {
      NotificationPayload? receivedPayload;
      final service = NotificationService(
        platform: mockPlatform,
        onNotificationAction: (payload) {
          receivedPayload = payload;
        },
      );

      await service.init();

      // Simulate plugin callback with corrupt json payload
      mockPlatform.onResponseCallback!(
        const NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotification,
          payload: 'corrupt-string',
        ),
      );

      expect(receivedPayload, isNull);

      // Simulate plugin callback with null payload
      mockPlatform.onResponseCallback!(
        const NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotification,
          payload: null,
        ),
      );

      expect(receivedPayload, isNull);
    });
  });

  group('Static source code checks (AC10)', () {
    test('AC10: notification files do not reference forbidden APIs', () {
      final forbiddenTerms = [
        'tz.local',
        'flutter_timezone',
        'DateTime.now()',
        'toLocal()',
        'timeZoneOffset',
      ];

      final filesToCheck = [
        File('lib/core/notification/notification_id.dart'),
        File('lib/core/notification/notification_service.dart'),
      ];

      for (final file in filesToCheck) {
        expect(file.existsSync(), isTrue, reason: '${file.path} must exist');
        final content = file.readAsStringSync();
        for (final term in forbiddenTerms) {
          expect(
            content.contains(term),
            isFalse,
            reason: '${file.path} must not contain "$term"',
          );
        }
      }
    });
  });
}
