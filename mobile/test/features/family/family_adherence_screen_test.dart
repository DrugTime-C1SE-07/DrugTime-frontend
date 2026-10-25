import 'dart:async';
import 'dart:convert';

import 'package:drugtime_mobile/app/app.dart';
import 'package:drugtime_mobile/app/router.dart';
import 'package:drugtime_mobile/core/sync/sync_engine.dart';
import 'package:drugtime_mobile/features/adherence/domain/entities/adherence_failure.dart';
import 'package:drugtime_mobile/features/adherence/data/models/adherence_api_mapper.dart';
import 'package:drugtime_mobile/features/adherence/domain/entities/adherence_history.dart';
import 'package:drugtime_mobile/features/adherence/presentation/screens/family_adherence_screen.dart';
import 'package:drugtime_mobile/features/auth/data/repositories/in_memory_auth_repository.dart';
import 'package:drugtime_mobile/features/auth/domain/entities/auth_session.dart';
import 'package:drugtime_mobile/features/auth/presentation/state/auth_controller.dart';
import 'package:drugtime_mobile/features/consent/data/repositories/in_memory_consent_repository.dart';
import 'package:drugtime_mobile/features/consent/domain/entities/consent.dart';
import 'package:drugtime_mobile/features/medication/data/repositories/in_memory_medication_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../adherence/adherence_api_mapper_test.dart'
    show samplePatientId, sampleHistoryJson;
import 'family_adherence_controller_test.dart'
    show PendingFamilyHistory, familyHistory;

class _Connection implements ConnectivityMonitor {
  final changes = StreamController<bool>.broadcast(sync: true);
  @override
  Stream<bool> get onlineChanges => changes.stream;
  @override
  Future<bool> get isOnline async => true;
  @override
  Future<void> dispose() => changes.close();
}

Widget _screen(PendingFamilyHistory repo,
        {String patientId = samplePatientId}) =>
    MaterialApp(
      navigatorObservers: [familyAdherenceRouteObserver],
      home: FamilyAdherenceScreen(
        key: const Key('family-history'),
        patientId: patientId,
        repository: repo,
        now: () => DateTime.utc(2026, 10, 22, 5),
      ),
    );

Future<void> _loaded(WidgetTester tester, PendingFamilyHistory repo) async {
  await tester.pumpWidget(_screen(repo));
  repo.pending.single.complete(familyHistory());
  await tester.pumpAndSettle();
  expect(find.text('Thuốc A'), findsWidgets);
}

AdherenceHistory _todayHistory() {
  // The app route uses its production current date, unlike the fixed-date screen tests.
  final today = adherenceDateQuery(vietnamWallTime(DateTime.now()));
  final monthStart = '${today.substring(0, 8)}01';
  final payload = jsonEncode(sampleHistoryJson())
      .replaceAll('2026-10-22', today)
      .replaceAll('2026-10-01', monthStart);
  return AdherenceApiMapper.history(jsonDecode(payload));
}

void main() {
  testWidgets('AC6: the family view has data and no dose or schedule writes',
      (tester) async {
    final repo = PendingFamilyHistory();
    await _loaded(tester, repo);
    expect(find.text('66.67%'), findsOneWidget);
    expect(find.text('Xác nhận'), findsNothing);
    expect(find.text('Sửa'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final kind in [
    AdherenceFailureKind.denied,
    AdherenceFailureKind.network
  ]) {
    testWidgets('AC6: refresh $kind clears the previously displayed patient',
        (tester) async {
      final repo = PendingFamilyHistory();
      await _loaded(tester, repo);
      final refresh =
          tester.widget<RefreshIndicator>(find.byType(RefreshIndicator));
      final read = refresh.onRefresh();
      await tester.pump();
      expect(find.text('Thuốc A'), findsNothing);
      repo.pending[1].completeError(AdherenceFailure(kind));
      await read;
      await tester.pumpAndSettle();
      expect(find.text('Thuốc A'), findsNothing);
      expect(
          find.text(kind == AdherenceFailureKind.denied
              ? 'Không còn quyền xem lịch sử'
              : 'Chưa thể tải lịch sử'),
          findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('AC6: changing to Q removes P before the Q read completes',
      (tester) async {
    final repo = PendingFamilyHistory();
    await _loaded(tester, repo);
    const other = '22222222-2222-4222-8222-222222222222';
    await tester.pumpWidget(_screen(repo, patientId: other));
    expect(find.text('Thuốc A'), findsNothing);
    expect(repo.patients.last, other);
    repo.pending[1]
        .completeError(const AdherenceFailure(AdherenceFailureKind.denied));
    await tester.pumpAndSettle();
    expect(find.text('Thuốc A'), findsNothing);
    expect(find.text('Không còn quyền xem lịch sử'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('AC6 QD-29: background removes family health data immediately',
      (tester) async {
    final repo = PendingFamilyHistory();
    await _loaded(tester, repo);
    try {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(find.text('Thuốc A', skipOffstage: false), findsNothing);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    }
  });

  for (final trigger in ['offline', 'logout']) {
    testWidgets('AC6 QD-29: $trigger removes health data from the actual app',
        (tester) async {
      final repo = PendingFamilyHistory();
      final connection = _Connection();
      final auth = AuthController(InMemoryAuthRepository(
        simulatedDelay: Duration.zero,
        initialSession: AuthSession(
          userId: 'family-test-user',
          accessToken: 'test-session',
          expiresAt: DateTime.now().add(const Duration(days: 1)),
          profileComplete: true,
        ),
      ));
      final navigator = GlobalKey<NavigatorState>();
      try {
        await tester.pumpWidget(DrugTimeApp(
          authController: auth,
          navigatorKey: navigator,
          adherenceRepository: repo,
          familyConnectivity: connection,
          medicationRepository: InMemoryMedicationRepository(),
          consentRepository: InMemoryConsentRepository(
              granted: {ConsentPurpose.terms, ConsentPurpose.healthData}),
        ));
        await tester.pumpAndSettle();
        unawaited(navigator.currentState!.pushNamed(AppRoutes.familyAdherence,
            arguments:
                const FamilyAdherenceRouteArgs(patientId: samplePatientId)));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        repo.pending.single.complete(_todayHistory());
        await tester.pumpAndSettle();
        expect(find.text('Thuốc A'), findsWidgets);
        if (trigger == 'offline') {
          connection.changes.add(false);
        } else {
          await auth.signOut();
        }
        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.text('Thuốc A', skipOffstage: false), findsNothing);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        auth.dispose();
      }
    });
  }
}
