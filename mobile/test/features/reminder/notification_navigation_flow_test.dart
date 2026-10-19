import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:drugtime_mobile/app/app.dart';
import 'package:drugtime_mobile/core/contracts/dose_outbox.dart';
import 'package:drugtime_mobile/core/notification/notification_id.dart';
import 'package:drugtime_mobile/core/notification/notification_service.dart';
import 'package:drugtime_mobile/core/notification/reminder_scheduler.dart';
import 'package:drugtime_mobile/core/platform/keyguard_service.dart';
import 'package:drugtime_mobile/core/storage/local_db/local_medication_store.dart';
import 'package:drugtime_mobile/core/storage/local_db/local_models.dart';
import 'package:drugtime_mobile/features/auth/data/repositories/in_memory_auth_repository.dart';
import 'package:drugtime_mobile/features/auth/domain/entities/auth_session.dart';
import 'package:drugtime_mobile/features/auth/presentation/state/auth_controller.dart';
import 'package:drugtime_mobile/features/consent/data/repositories/in_memory_consent_repository.dart';
import 'package:drugtime_mobile/features/medication/data/repositories/in_memory_medication_repository.dart';
import 'package:drugtime_mobile/features/reminder/presentation/screens/dose_reminder_screen.dart';

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

class FakeTestLocalMedicationStore implements LocalMedicationStore {
  final Map<int, LocalMedicationSchedule> schedules = {};
  final Set<String> recordedKeys = {};

  @override
  Future<LocalMedicationSchedule?> getScheduleById(int scheduleId) async =>
      schedules[scheduleId];

  @override
  Future<List<LocalMedicationSchedule>> getActiveSchedules({
    required String patientId,
  }) async {
    return schedules.values
        .where((s) => s.patientUserId == patientId && s.reminderEnabled)
        .toList();
  }

  @override
  Future<bool> hasDoseLog({
    required int medicationScheduleId,
    required DateTime scheduledAt,
  }) async {
    return recordedKeys.contains(
        '$medicationScheduleId:${scheduledAt.toUtc().toIso8601String()}');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeTestDoseOutbox implements DoseOutbox {
  final List<Map<String, dynamic>> enqueued = [];

  @override
  Future<LocalDoseLog> enqueue({
    required int medicationScheduleId,
    required DateTime scheduledAt,
    required DateTime takenAt,
  }) async {
    enqueued.add({
      'medicationScheduleId': medicationScheduleId,
      'scheduledAt': scheduledAt,
      'takenAt': takenAt,
    });
    return LocalDoseLog(
      clientUuid: 'test-uuid-${enqueued.length}',
      medicationScheduleId: medicationScheduleId,
      scheduledAt: scheduledAt,
      takenAt: takenAt,
      status: DoseLogStatus.taken,
      syncState: DoseLogSyncState.pendingUpload,
      localUpdatedAt: DateTime.now().toUtc(),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeTestReminderScheduler implements ReminderScheduler {
  @override
  Future<void> snooze({
    required int medicationScheduleId,
    required DateTime scheduledAt,
    required DateTime remindAt,
  }) async {}
}

class FakeTestKeyguardPlatform implements KeyguardPlatform {
  @override
  Future<bool> isKeyguardLocked() async => false;

  @override
  Future<bool> requestDismissKeyguard() async => true;
}

LocalMedicationSchedule _testSchedule({
  required int id,
  required String name,
  String intakeTime = '20:00',
  String patientId = 'test-user',
}) {
  return LocalMedicationSchedule(
    id: id,
    patientUserId: patientId,
    userMedicationId: id * 10,
    medicationId: id * 100,
    medicationName: name,
    strengthText: '50mg',
    dosageForm: 'Trước ăn tối',
    quantityPerDose: '1',
    dosesPerDay: 1,
    intakeTime: intakeTime,
    daysOfWeek: const [1, 2, 3, 4, 5, 6, 7],
    reminderEnabled: true,
    effectiveFrom: DateTime.utc(2026, 1, 1),
    serverSyncedAt: DateTime.utc(2026, 1, 1),
  );
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

    testWidgets(
        'lịch không còn tồn tại: hiện SnackBar thông báo, không push route lỗi',
        (tester) async {
      final scheduledAt = DateTime.utc(2026, 10, 8, 13, 0, 0); // 20:00 VN
      final rawPayload = NotificationPayload(
        medicationScheduleId: 999, // Không tồn tại
        scheduledAt: scheduledAt,
      ).serialize();

      final service = NotificationService(platform: mockPlatform);
      await service.init();

      final store = FakeTestLocalMedicationStore();
      final navigatorKey = GlobalKey<NavigatorState>();
      final messengerKey = GlobalKey<ScaffoldMessengerState>();

      await tester.pumpWidget(
        DrugTimeApp(
          authController: authController,
          consentRepository: InMemoryConsentRepository(),
          medicationRepository: InMemoryMedicationRepository(),
          localMedicationStore: store,
          navigatorKey: navigatorKey,
          scaffoldMessengerKey: messengerKey,
          notificationService: service,
        ),
      );
      await tester.pumpAndSettle();

      // Trigger notification response
      mockPlatform.onResponseCallback?.call(
        NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotification,
          payload: rawPayload,
        ),
      );
      await tester.pumpAndSettle();

      // Xác nhận có SnackBar báo lịch không còn
      expect(find.text('Lịch uống thuốc không còn tồn tại.'), findsOneWidget);
      // Không push màn hình dose reminder
      expect(find.byType(DoseReminderScreen), findsNothing);
    });

    testWidgets(
        '1 thuốc: tra lịch và mở màn hình S09e với đầy đủ thông tin thuốc',
        (tester) async {
      final scheduledAt = DateTime.utc(2026, 10, 8, 13, 0, 0); // 20:00 VN
      final rawPayload = NotificationPayload(
        medicationScheduleId: 1,
        scheduledAt: scheduledAt,
      ).serialize();

      final service = NotificationService(platform: mockPlatform);
      await service.init();

      final store = FakeTestLocalMedicationStore();
      store.schedules[1] = _testSchedule(id: 1, name: 'Losartan 50mg');

      final outbox = FakeTestDoseOutbox();
      final scheduler = FakeTestReminderScheduler();
      final navigatorKey = GlobalKey<NavigatorState>();
      final messengerKey = GlobalKey<ScaffoldMessengerState>();

      await tester.pumpWidget(
        DrugTimeApp(
          authController: authController,
          consentRepository: InMemoryConsentRepository(),
          medicationRepository: InMemoryMedicationRepository(),
          localMedicationStore: store,
          doseOutbox: outbox,
          reminderScheduler: scheduler,
          keyguardPlatform: FakeTestKeyguardPlatform(),
          navigatorKey: navigatorKey,
          scaffoldMessengerKey: messengerKey,
          notificationService: service,
        ),
      );
      await tester.pumpAndSettle();

      mockPlatform.onResponseCallback?.call(
        NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotification,
          payload: rawPayload,
        ),
      );
      await tester.pumpAndSettle();

      // Màn hình DoseReminderScreen (S09e) được mở
      expect(find.byType(DoseReminderScreen), findsOneWidget);
      expect(find.text('Losartan 50mg'), findsOneWidget);
      expect(find.text('Đã uống'), findsOneWidget);
      expect(find.text('Nhắc lại sau 10 phút'), findsOneWidget);
      expect(find.text('Bỏ qua liều này'), findsOneWidget);

      // Nhấn nút "Đã uống"
      await tester.tap(find.text('Đã uống'));
      await tester.pumpAndSettle();

      // Xác nhận outbox đã được gọi với ID và scheduledAt đúng
      expect(outbox.enqueued.length, 1);
      expect(outbox.enqueued.first['medicationScheduleId'], 1);
      expect(outbox.enqueued.first['scheduledAt'], scheduledAt);
    });

    testWidgets(
        '3 thuốc cùng giờ: gom thành nhóm và mở màn hình S09e-2 (nhiều thuốc)',
        (tester) async {
      final scheduledAt = DateTime.utc(2026, 10, 8, 13, 0, 0); // 20:00 VN
      final rawPayload = NotificationPayload(
        medicationScheduleId: 1,
        scheduledAt: scheduledAt,
      ).serialize();

      final service = NotificationService(platform: mockPlatform);
      await service.init();

      final store = FakeTestLocalMedicationStore();
      store.schedules[1] = _testSchedule(id: 1, name: 'Losartan 50mg');
      store.schedules[2] = _testSchedule(id: 2, name: 'Metformin 500mg');
      store.schedules[3] = _testSchedule(id: 3, name: 'Vitamin D3 1000IU');

      final outbox = FakeTestDoseOutbox();
      final scheduler = FakeTestReminderScheduler();
      final navigatorKey = GlobalKey<NavigatorState>();
      final messengerKey = GlobalKey<ScaffoldMessengerState>();

      await tester.pumpWidget(
        DrugTimeApp(
          authController: authController,
          consentRepository: InMemoryConsentRepository(),
          medicationRepository: InMemoryMedicationRepository(),
          localMedicationStore: store,
          doseOutbox: outbox,
          reminderScheduler: scheduler,
          keyguardPlatform: FakeTestKeyguardPlatform(),
          navigatorKey: navigatorKey,
          scaffoldMessengerKey: messengerKey,
          notificationService: service,
        ),
      );
      await tester.pumpAndSettle();

      mockPlatform.onResponseCallback?.call(
        NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotification,
          payload: rawPayload,
        ),
      );
      await tester.pumpAndSettle();

      // Màn hình DoseReminderScreen mở ở chế độ nhiều thuốc thu gọn (S09e-2)
      expect(find.byType(DoseReminderScreen), findsOneWidget);
      expect(find.text('+2 thuốc'), findsOneWidget);
      expect(find.text('Đã uống cả 3 thuốc'), findsOneWidget);

      // Nhấn "Đã uống cả 3 thuốc"
      await tester.tap(find.text('Đã uống cả 3 thuốc'));
      await tester.pumpAndSettle();

      // Mỗi thuốc gọi enqueue riêng với client_uuid riêng (3 lần gọi riêng biệt)
      expect(outbox.enqueued.length, 3);
      final enqueuedIds =
          outbox.enqueued.map((e) => e['medicationScheduleId']).toSet();
      expect(enqueuedIds, {1, 2, 3});
    });

    testWidgets(
        '3 thuốc nhưng 1 thuốc đã có trong local_dose_logs: chỉ hiện 2 thuốc còn lại',
        (tester) async {
      final scheduledAt = DateTime.utc(2026, 10, 8, 13, 0, 0); // 20:00 VN
      final rawPayload = NotificationPayload(
        medicationScheduleId: 1,
        scheduledAt: scheduledAt,
      ).serialize();

      final service = NotificationService(platform: mockPlatform);
      await service.init();

      final store = FakeTestLocalMedicationStore();
      store.schedules[1] = _testSchedule(id: 1, name: 'Losartan 50mg');
      store.schedules[2] = _testSchedule(id: 2, name: 'Metformin 500mg');
      store.schedules[3] = _testSchedule(id: 3, name: 'Vitamin D3 1000IU');

      // Thuốc 1 đã được ghi nhận trước đó
      store.recordedKeys.add('1:${scheduledAt.toUtc().toIso8601String()}');

      final outbox = FakeTestDoseOutbox();
      final scheduler = FakeTestReminderScheduler();
      final navigatorKey = GlobalKey<NavigatorState>();
      final messengerKey = GlobalKey<ScaffoldMessengerState>();

      await tester.pumpWidget(
        DrugTimeApp(
          authController: authController,
          consentRepository: InMemoryConsentRepository(),
          medicationRepository: InMemoryMedicationRepository(),
          localMedicationStore: store,
          doseOutbox: outbox,
          reminderScheduler: scheduler,
          keyguardPlatform: FakeTestKeyguardPlatform(),
          navigatorKey: navigatorKey,
          scaffoldMessengerKey: messengerKey,
          notificationService: service,
        ),
      );
      await tester.pumpAndSettle();

      mockPlatform.onResponseCallback?.call(
        NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotification,
          payload: rawPayload,
        ),
      );
      await tester.pumpAndSettle();

      // Chỉ còn 2 thuốc: hiển thị "+1 thuốc", nút "Đã uống cả 2 thuốc"
      expect(find.byType(DoseReminderScreen), findsOneWidget);
      expect(find.text('+1 thuốc'), findsOneWidget);
      expect(find.text('Đã uống cả 2 thuốc'), findsOneWidget);
    });

    testWidgets(
        'Tất cả các thuốc đã ghi nhận: hiện SnackBar thông báo, không push route',
        (tester) async {
      final scheduledAt = DateTime.utc(2026, 10, 8, 13, 0, 0); // 20:00 VN
      final rawPayload = NotificationPayload(
        medicationScheduleId: 1,
        scheduledAt: scheduledAt,
      ).serialize();

      final service = NotificationService(platform: mockPlatform);
      await service.init();

      final store = FakeTestLocalMedicationStore();
      store.schedules[1] = _testSchedule(id: 1, name: 'Losartan 50mg');

      // Đã ghi nhận
      store.recordedKeys.add('1:${scheduledAt.toUtc().toIso8601String()}');

      final navigatorKey = GlobalKey<NavigatorState>();
      final messengerKey = GlobalKey<ScaffoldMessengerState>();

      await tester.pumpWidget(
        DrugTimeApp(
          authController: authController,
          consentRepository: InMemoryConsentRepository(),
          medicationRepository: InMemoryMedicationRepository(),
          localMedicationStore: store,
          navigatorKey: navigatorKey,
          scaffoldMessengerKey: messengerKey,
          notificationService: service,
        ),
      );
      await tester.pumpAndSettle();

      mockPlatform.onResponseCallback?.call(
        NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotification,
          payload: rawPayload,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Các liều thuốc này đã được ghi nhận.'), findsOneWidget);
      expect(find.byType(DoseReminderScreen), findsNothing);
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
