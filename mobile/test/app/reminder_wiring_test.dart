import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/app/app.dart';
import 'package:drugtime_mobile/core/notification/notification_service.dart';
import 'package:drugtime_mobile/core/notification/reminder_sync_coordinator.dart';
import 'package:drugtime_mobile/features/auth/data/repositories/in_memory_auth_repository.dart';
import 'package:drugtime_mobile/features/auth/presentation/state/auth_controller.dart';
import 'package:drugtime_mobile/features/medication/presentation/state/medication_controller.dart';

import '../core/notification/device_token_coordinator_test.dart'
    show tokenSession;
import '../core/notification/reminder_notification_scheduler_test.dart'
    show MockReminderNotificationPlatform;

void main() {
  late AuthController auth;
  late _CountingPlatform platform;
  late _FakeCoordinator reminders;

  setUp(() {
    auth = AuthController(InMemoryAuthRepository(
        initialSession: tokenSession('A'), simulatedDelay: Duration.zero));
    platform = _CountingPlatform();
    reminders = _FakeCoordinator();
  });

  Future<void> pumpApp(WidgetTester tester,
      {Future<bool> Function()? shouldAsk}) async {
    await tester.pumpWidget(DrugTimeApp(
      authController: auth,
      notificationService: NotificationService(platform: platform),
      reminderSyncCoordinator: reminders,
      shouldAskReminderPermissions: shouldAsk,
    ));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'an active session asks for notification then full-screen permission and schedules reminders (regression)',
      (tester) async {
    await pumpApp(tester);

    expect(reminders.refreshed, ['A']);
    expect(platform.requests, ['notifications', 'full_screen']);

    // Một phiên chỉ kích hoạt một lần dù app dựng lại.
    await tester.pump();
    expect(reminders.refreshed, ['A']);

    await tester.pumpWidget(const SizedBox());
    auth.dispose();
  });

  testWidgets(
      'permissions already asked after install: no prompt, reminders still scheduled',
      (tester) async {
    await pumpApp(tester, shouldAsk: () async => false);

    expect(platform.requests, isEmpty);
    expect(reminders.refreshed, ['A']);

    await tester.pumpWidget(const SizedBox());
    auth.dispose();
  });

  testWidgets('first launch after install asks for both permissions',
      (tester) async {
    await pumpApp(tester, shouldAsk: () async => true);

    expect(platform.requests, ['notifications', 'full_screen']);
    expect(reminders.refreshed, ['A']);

    await tester.pumpWidget(const SizedBox());
    auth.dispose();
  });

  testWidgets('a successful medication change refreshes reminders again',
      (tester) async {
    await pumpApp(tester);
    final medications =
        MedicationScope.read(tester.element(find.byType(Navigator).first));
    await medications.load();
    final id = medications.medications.firstWhere((m) => m.isActive).id;

    await medications.setStopped(id, true);
    await tester.pumpAndSettle();

    expect(reminders.refreshed, ['A', 'A']);

    await tester.pumpWidget(const SizedBox());
    auth.dispose();
  });
}

class _CountingPlatform extends MockReminderNotificationPlatform
    implements NotificationPermissionPlatform {
  final List<String> requests = [];

  @override
  Future<bool?> requestNotificationsPermission() async {
    requests.add('notifications');
    return true;
  }

  @override
  Future<bool?> requestFullScreenIntentPermission() async {
    requests.add('full_screen');
    return true;
  }
}

class _FakeCoordinator implements ReminderSyncCoordinator {
  final List<String> refreshed = [];

  @override
  Future<void> refresh(String patientId) async => refreshed.add(patientId);

  @override
  Future<void> clear() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}
