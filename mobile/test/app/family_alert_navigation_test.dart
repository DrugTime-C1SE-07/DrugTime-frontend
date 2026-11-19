import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/app/app.dart';
import 'package:drugtime_mobile/core/notification/family_push_service.dart';
import 'package:drugtime_mobile/features/auth/data/repositories/in_memory_auth_repository.dart';
import 'package:drugtime_mobile/features/auth/presentation/state/auth_controller.dart';
import 'package:drugtime_mobile/features/consent/data/repositories/in_memory_consent_repository.dart';
import 'package:drugtime_mobile/features/consent/domain/entities/consent.dart';
import 'package:drugtime_mobile/features/consent/presentation/state/consent_controller.dart';
import 'package:drugtime_mobile/features/family/presentation/state/family_alert_controller.dart';
import '../features/family/family_alert_controller_test.dart' show AlertRepo;
import '../core/notification/device_token_coordinator_test.dart'
    show tokenSession;

void main() {
  testWidgets(
      'cold start waits for consent, then HTTP detail determines patient; background clears it',
      (tester) async {
    final auth = AuthController(InMemoryAuthRepository(
        initialSession: tokenSession('A'), simulatedDelay: Duration.zero));
    final alerts = FamilyAlertController(AlertRepo());
    final push =
        FamilyPushService(android: false, showForeground: (_, __) async {})
          ..offer('1');
    final consent = InMemoryConsentRepository(granted: {ConsentPurpose.terms});
    await tester.pumpWidget(DrugTimeApp(
        authController: auth,
        familyAlertController: alerts,
        familyPushService: push,
        consentRepository: consent));
    await tester.pumpAndSettle();
    expect(alerts.detail, isNull);
    expect(push.pendingId, 1);
    await consent.grant(ConsentPurpose.healthData);
    // Refresh the app's existing consent controller through the mounted gate.
    final context = tester.element(find.byType(Navigator).first);
    await ConsentScope.read(context).load();
    await tester.pumpAndSettle();
    expect(find.text('Chi tiết cảnh báo'), findsOneWidget);
    expect(find.text('Bác An'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(alerts.detail, isNull);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(alerts.detail, isNotNull);
    await auth.signOut();
    await tester.pumpAndSettle();
    expect(alerts.detail, isNull);
    await tester.pumpWidget(const SizedBox());
    alerts.dispose();
    push.dispose();
    auth.dispose();
  });
}
