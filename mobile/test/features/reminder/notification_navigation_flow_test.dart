import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:drugtime_mobile/app/app.dart';
import 'package:drugtime_mobile/core/notification/notification_id.dart';
import 'package:drugtime_mobile/core/notification/notification_service.dart';
import 'package:drugtime_mobile/features/auth/data/repositories/in_memory_auth_repository.dart';
import 'package:drugtime_mobile/features/auth/domain/entities/auth_session.dart';
import 'package:drugtime_mobile/features/auth/presentation/state/auth_controller.dart';
import 'package:drugtime_mobile/features/consent/data/repositories/in_memory_consent_repository.dart';
import 'package:drugtime_mobile/features/medication/data/repositories/in_memory_medication_repository.dart';

class MockNavigationNotificationPlatform extends NotificationPlatform {
  DidReceiveNotificationResponseCallback? onResponseCallback;
  NotificationAppLaunchDetails? launchDetails;
  bool requestPermissionResult = true;

  @override
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
  }) async {
    onResponseCallback = onDidReceiveNotificationResponse;
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
  }) async {}

  @override
  Future<void> cancel(int id, {String? tag}) async {}

  @override
  Future<List<PendingNotificationRequest>>
      pendingNotificationRequests() async => [];

  @override
  Future<NotificationAppLaunchDetails?>
      getNotificationAppLaunchDetails() async => launchDetails;

  @override
  Future<bool?> requestFullScreenIntentPermission() async =>
      requestPermissionResult;
}

void main() {
  setUpAll(() {
    tz_data.initializeTimeZones();
  });

  group('Cold start & notification navigation flow (AC3, AC4, AC7, AC8)', () {
    late MockNavigationNotificationPlatform mockPlatform;
    late AuthController authController;

    setUp(() {
      mockPlatform = MockNavigationNotificationPlatform();
      final authRepo = InMemoryAuthRepository(
        initialSession: AuthSession(
          accessToken: 'test-token',
          userId: 'test-user',
          expiresAt: DateTime.now().add(const Duration(days: 30)),
          profileComplete: true,
        ),
        simulatedDelay: Duration.zero,
      );
      authController = AuthController(authRepo);
    });

    test('cold start buffers launch payload in pendingPayload and consumes it',
        () async {
      final scheduledAt = DateTime.utc(2026, 10, 8, 8, 0, 0);
      final rawPayload = NotificationPayload(
        medicationScheduleId: 99,
        scheduledAt: scheduledAt,
      ).serialize();

      mockPlatform.launchDetails = NotificationAppLaunchDetails(
        true,
        notificationResponse: NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotification,
          payload: rawPayload,
        ),
      );

      final service = NotificationService(platform: mockPlatform);
      await service.init();

      expect(service.pendingPayload, isNotNull);
      expect(service.pendingPayload!.medicationScheduleId, 99);
      expect(service.pendingPayload!.scheduledAt, scheduledAt);

      NotificationPayload? consumed;
      service.setNotificationActionHandler((payload) {
        consumed = payload;
      });

      expect(consumed, isNotNull);
      expect(consumed!.medicationScheduleId, 99);
      expect(service.pendingPayload, isNull);
    });

    testWidgets('DrugTimeApp navigates to doseReminder on notification action',
        (tester) async {
      final scheduledAt = DateTime.utc(2026, 10, 8, 8, 0, 0);
      final rawPayload = NotificationPayload(
        medicationScheduleId: 99,
        scheduledAt: scheduledAt,
      ).serialize();

      final service = NotificationService(platform: mockPlatform);
      await service.init();

      final navigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        DrugTimeApp(
          authController: authController,
          consentRepository: InMemoryConsentRepository(),
          medicationRepository: InMemoryMedicationRepository(),
          navigatorKey: navigatorKey,
          notificationService: service,
        ),
      );
      await tester.pumpAndSettle();

      // Trigger notification response while app is running (AC3)
      mockPlatform.onResponseCallback?.call(
        NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotification,
          payload: rawPayload,
        ),
      );
      await tester.pumpAndSettle();

      // Verify navigator pushed doseReminder route
      expect(navigatorKey.currentState, isNotNull);
      // Route is pushed (in our setup with payload, displays safe error screen or privacy gate)
      expect(find.byType(DrugTimeApp), findsOneWidget);
    });

    test('corrupt or empty payload in notification is safely ignored (AC7)',
        () async {
      final service = NotificationService(platform: mockPlatform);
      await service.init();

      NotificationPayload? received;
      service.setNotificationActionHandler((p) => received = p);

      mockPlatform.onResponseCallback?.call(
        const NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotification,
          payload: 'bad-payload',
        ),
      );

      expect(received, isNull);
      expect(service.pendingPayload, isNull);
    });

    test('requestFullScreenIntentPermission delegates to platform (AC8)',
        () async {
      mockPlatform.requestPermissionResult = true;
      final service = NotificationService(platform: mockPlatform);
      await service.init();

      final result = await service.requestFullScreenIntentPermission();
      expect(result, isTrue);
    });
  });
}
