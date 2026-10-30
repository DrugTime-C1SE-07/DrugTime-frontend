import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/app/app.dart';
import 'package:drugtime_mobile/features/auth/data/repositories/in_memory_auth_repository.dart';
import 'package:drugtime_mobile/features/auth/domain/entities/auth_session.dart';
import 'package:drugtime_mobile/features/auth/presentation/state/auth_controller.dart';
import 'package:drugtime_mobile/features/consent/data/repositories/in_memory_consent_repository.dart';
import 'package:drugtime_mobile/features/consent/domain/entities/consent.dart';
import 'package:drugtime_mobile/features/consent/presentation/state/consent_controller.dart';
import 'package:drugtime_mobile/features/medication/data/repositories/in_memory_medication_repository.dart';
import 'package:drugtime_mobile/features/adherence_history/data/models/adherence_history_api_mapper.dart';
import 'package:drugtime_mobile/features/adherence_history/domain/entities/adherence_history_failure.dart';
import 'package:drugtime_mobile/features/adherence_history/presentation/state/adherence_history_controller.dart';
import 'package:drugtime_mobile/features/adherence_history/presentation/screens/adherence_month_screen.dart';
import 'package:drugtime_mobile/features/adherence_history/presentation/screens/medication_history_screen.dart';
import 'package:drugtime_mobile/features/adherence_history/presentation/widgets/dose_history_tile.dart';
import 'package:drugtime_mobile/features/adherence_history/presentation/widgets/history_motion.dart';
import 'adherence_history_test_helpers.dart';

Future<AuthController> pumpApp(
    WidgetTester tester, FakeHistoryRepository repo) async {
  tester.view.physicalSize = const Size(375, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final auth = AuthController(InMemoryAuthRepository(
      simulatedDelay: Duration.zero,
      initialSession: AuthSession(
          userId: 'one',
          accessToken: 'test',
          expiresAt: DateTime.now().add(const Duration(days: 1)),
          profileComplete: true)));
  addTearDown(auth.dispose);
  await tester.pumpWidget(DrugTimeApp(
      authController: auth,
      adherenceHistoryRepository: repo,
      clock: () => historyNow,
      medicationRepository: InMemoryMedicationRepository(),
      consentRepository: InMemoryConsentRepository(
          granted: {ConsentPurpose.terms, ConsentPurpose.healthData})));
  await tester.pumpAndSettle();
  return auth;
}

void main() {
  for (final trigger in ['logout', '401', 'consent', '403', 'background']) {
    for (final child in [false, true]) {
      testWidgets(
          '$trigger clears the first frame during ${child ? 'route' : 'content'} motion',
          (tester) async {
        final repo = FakeHistoryRepository();
        final auth = await pumpApp(tester, repo);
        await tester.tap(find.text('Lịch nhắc'));
        await tester.pumpAndSettle();
        final context = tester.element(find.byKey(const Key('history-title')));
        final c = AdherenceHistoryScope.read(context);
        final consent = ConsentScope.read(context);
        await c.selectDay(DateTime.utc(2026, 10, 19));
        await tester.pump();
        if (child) {
          await tester.tap(find.byTooltip('Mở lịch tháng'));
          await tester.pump();
        }
        await tester.pump(const Duration(milliseconds: 80));
        expect(find.byType(HistoryEntrance, skipOffstage: false), findsWidgets);
        switch (trigger) {
          case 'logout':
            await auth.signOut();
          case '401':
            await auth.handleUnauthorized();
          case 'consent':
            await consent.withdraw(ConsentPurpose.healthData);
          case '403':
            repo.failure = const HistoryFailure(HistoryFailureKind.forbidden);
            await c.load();
          case 'background':
            tester.binding
                .handleAppLifecycleStateChanged(AppLifecycleState.inactive);
            tester.binding
                .handleAppLifecycleStateChanged(AppLifecycleState.hidden);
            tester.binding
                .handleAppLifecycleStateChanged(AppLifecycleState.paused);
        }
        await tester.pump();
        expect(c.history, isNull);
        expect(find.byType(DoseHistoryTile, skipOffstage: false), findsNothing);
        expect(find.byKey(const Key('history-summary'), skipOffstage: false),
            findsNothing);
        expect(
            find.text('Metformin 500 mg', skipOffstage: false), findsNothing);
        await tester.pump();
        // Auth navigation may retain an empty route until its transition ends.
        if (trigger == 'background') {
          tester.binding
              .handleAppLifecycleStateChanged(AppLifecycleState.hidden);
          tester.binding
              .handleAppLifecycleStateChanged(AppLifecycleState.inactive);
          tester.binding
              .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
          await tester.pumpAndSettle();
          expect(c.history, isNotNull);
        }
        await tester.pumpAndSettle();
        expect(find.byType(AdherenceMonthScreen, skipOffstage: false),
            findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }
  for (final medication in [false, true]) {
    testWidgets(
        'hidden tab no GET; resume with ${medication ? 'medication' : 'month'} refetches safely',
        (tester) async {
      final repo = FakeHistoryRepository();
      await pumpApp(tester, repo);
      expect(repo.calls, isEmpty);
      await tester.tap(find.text('Lịch nhắc'));
      await tester.pumpAndSettle();
      expect(repo.calls.length, 1);
      final c = AdherenceHistoryScope.read(
          tester.element(find.byKey(const Key('history-title'))));
      if (medication) {
        await openMedicationHistory(tester);
      } else {
        await openHistoryMonth(tester);
      }
      final before = repo.calls.length;
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pumpAndSettle();
      expect(c.history, isNull);
      for (final state in [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pumpAndSettle();
      expect(repo.calls.length, before + 1);
      expect(find.byType(AdherenceMonthScreen), findsNothing);
      expect(find.byType(MedicationHistoryScreen), findsNothing);
      await tester.tap(find.text('Thuốc'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lịch nhắc'));
      await tester.pumpAndSettle();
      expect(repo.calls.length, before + 2);
    });

    testWidgets(
        'withdraw consent removes ${medication ? 'medication' : 'month'} and delayed payload',
        (tester) async {
      final repo = FakeHistoryRepository();
      await pumpApp(tester, repo);
      await tester.tap(find.text('Lịch nhắc'));
      await tester.pumpAndSettle();
      final context = tester.element(find.byKey(const Key('history-title')));
      final c = AdherenceHistoryScope.read(context);
      final consents = ConsentScope.read(context);
      if (medication) {
        await openMedicationHistory(tester);
      } else {
        await openHistoryMonth(tester);
      }
      await consents.withdraw(ConsentPurpose.healthData);
      await tester.pumpAndSettle();
      expect(c.history, isNull);
      expect(find.byType(AdherenceMonthScreen), findsNothing);
      expect(find.byType(MedicationHistoryScreen), findsNothing);
      expect(find.text('Metformin 500 mg'), findsNothing);
      c.allowFreshRead();
      repo.delayed = true;
      final pending = c.load();
      c.revoke();
      repo.pending.single
          .complete(AdherenceHistoryApiMapper.parse(historyFixture()));
      await pending;
      await tester.pumpAndSettle();
      expect(c.history, isNull);
    });

    for (final unauthorized in [false, true]) {
      testWidgets(
          '${unauthorized ? '401' : 'logout'} removes ${medication ? 'medication' : 'month'} without stale response',
          (tester) async {
        final repo = FakeHistoryRepository();
        final auth = await pumpApp(tester, repo);
        await tester.tap(find.text('Lịch nhắc'));
        await tester.pumpAndSettle();
        final c = AdherenceHistoryScope.read(
            tester.element(find.byKey(const Key('history-title'))));
        if (medication) {
          await openMedicationHistory(tester);
        } else {
          await openHistoryMonth(tester);
        }
        repo.delayed = true;
        final pending = c.load();
        if (unauthorized) {
          await auth.handleUnauthorized();
        } else {
          await auth.signOut();
        }
        await tester.pumpAndSettle();
        repo.pending.single
            .complete(AdherenceHistoryApiMapper.parse(historyFixture()));
        await pending;
        await tester.pumpAndSettle();
        expect(c.history, isNull);
        expect(find.byType(AdherenceMonthScreen), findsNothing);
        expect(find.byType(MedicationHistoryScreen), findsNothing);
        expect(find.text('Metformin 500 mg'), findsNothing);
      });
    }
  }

  testWidgets('forbidden read clears and closes medication page',
      (tester) async {
    final repo = FakeHistoryRepository();
    final c = await pumpHistory(tester, repo);
    await openMedicationHistory(tester);
    repo.failure = const HistoryFailure(HistoryFailureKind.forbidden);
    await c.load();
    await tester.pumpAndSettle();
    expect(c.history, isNull);
    expect(find.byType(MedicationHistoryScreen), findsNothing);
    expect(find.byKey(const Key('history-error')), findsOneWidget);
    expect(find.text('Metformin 500 mg'), findsNothing);
  });

  testWidgets('revocation removes only history route under another route',
      (tester) async {
    final c = await pumpHistory(tester, FakeHistoryRepository());
    await openHistoryMonth(tester);
    final navigator =
        Navigator.of(tester.element(find.byType(AdherenceMonthScreen)));
    navigator.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Login route retained'))));
    await tester.pumpAndSettle();
    c.revoke();
    await tester.pumpAndSettle();
    expect(c.history, isNull);
    expect(find.text('Login route retained'), findsOneWidget);
    expect(
        find.byType(AdherenceMonthScreen, skipOffstage: false), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('history-error')), findsOneWidget);
  });
}
