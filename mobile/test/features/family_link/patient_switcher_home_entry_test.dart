import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/app/app.dart';
import 'package:drugtime_mobile/features/auth/data/repositories/in_memory_auth_repository.dart';
import 'package:drugtime_mobile/features/auth/domain/entities/auth_session.dart';
import 'package:drugtime_mobile/features/auth/presentation/state/auth_controller.dart';
import 'package:drugtime_mobile/features/medication/data/repositories/in_memory_medication_repository.dart';
import 'package:drugtime_mobile/features/patient_monitor/presentation/patient_monitor_screen.dart';
import '../patient_monitor/patient_monitor_controller_test.dart'
    show MonitorRepo;

void main() {
  testWidgets('profile opens Chia sẻ và liên kết', (tester) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(DrugTimeApp(
      authController: AuthController(InMemoryAuthRepository(
          initialSession: AuthSession(
              userId: 'Nam',
              accessToken: 'test-session',
              profileComplete: true,
              expiresAt: DateTime.now().add(const Duration(days: 1))),
          simulatedDelay: Duration.zero)),
      medicationRepository: InMemoryMedicationRepository(seed: []),
      patientMonitorRepository: MonitorRepo(),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byWidgetPredicate(
        (w) => w is NavigationDestination && w.label == 'Hồ sơ'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('share-and-link-tile')));
    await tester.tap(find.byKey(const Key('share-and-link-tile')));
    await tester.pumpAndSettle();
    expect(find.text('Mời người thân'), findsOneWidget);
    expect(find.byKey(const Key('share-own-qr')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  for (final empty in [false, true]) {
    testWidgets(
        'home ${empty ? 'empty' : 'full'} opens R1 before selecting a patient',
        (tester) async {
      tester.view.physicalSize = const Size(430, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(DrugTimeApp(
        authController: AuthController(InMemoryAuthRepository(
            initialSession: AuthSession(
                userId: 'Nam',
                accessToken: 'test-session',
                profileComplete: true,
                expiresAt: DateTime.now().add(const Duration(days: 1))),
            simulatedDelay: Duration.zero)),
        medicationRepository:
            InMemoryMedicationRepository(seed: empty ? [] : sampleMedications),
        patientMonitorRepository: MonitorRepo(),
      ));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Người thân').first);
      await tester.tap(find.text('Người thân').first);
      await tester.pumpAndSettle();
      expect(find.text('Tôi theo dõi (2)'), findsOneWidget);
      expect(find.text('Theo dõi tôi (0)'), findsOneWidget);
      expect(find.byType(PatientMonitorScreen), findsNothing);
      expect(find.byKey(const ValueKey('patient-mother')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('patient-mother')));
      await tester.pumpAndSettle();
      expect(find.text('Chỉ xem'), findsOneWidget);
      await tester.tap(find.text('Xem hôm nay'));
      await tester.pumpAndSettle();
      expect(find.text(mealMockLabel), findsOneWidget);
      expect(find.textContaining('Gọi mẹ'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
