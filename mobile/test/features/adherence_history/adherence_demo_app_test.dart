import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/app/adherence_demo_app.dart';
import 'package:drugtime_mobile/app/router.dart';
import 'package:drugtime_mobile/features/auth/presentation/state/auth_controller.dart';
import 'package:drugtime_mobile/features/adherence_history/presentation/state/adherence_history_controller.dart';
import 'adherence_history_test_helpers.dart';

void main() {
  setUp(() {
    final previous = HttpOverrides.current;
    HttpOverrides.global = _NoPreviewNetwork();
    addTearDown(() => HttpOverrides.global = previous);
    for (final name in [
      'plugins.it_nomads.com/flutter_secure_storage',
      'dexterous.com/flutter/local_notifications',
      'com.tekartik.sqflite',
      'dev.fluttercommunity.plus/share',
      'dev.steenbakker.mobile_scanner/scanner/method'
    ]) {
      final channel = MethodChannel(name);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              channel,
              (_) async =>
                  throw StateError('External service in preview: $name'));
      addTearDown(() => TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null));
    }
  });
  testWidgets(
      'integrated five tabs, compact history, no welcome/picker; children preserve day',
      (tester) async {
    tester.view.physicalSize = const Size(430, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(AdherenceDemoApp(now: DateTime.utc(2026, 10, 22)));
    await tester.pumpAndSettle();
    expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        2);
    expect(find.text('Mẫu'), findsOneWidget);
    expect(find.text('4/6 đã uống'), findsOneWidget);
    expect(find.text('80%'), findsOneWidget);
    for (final key in ['demo-enter', 'demo-exit', 'demo-preset-picker']) {
      expect(find.byKey(Key(key)), findsNothing);
    }
    await openHistoryMonth(tester);
    expect(find.text('Mẫu'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('history-day-20')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('history-view-day')));
    await tester.tap(find.byKey(const Key('history-view-day')));
    await tester.pumpAndSettle();
    final c = AdherenceHistoryScope.read(
        tester.element(find.byKey(const Key('history-title'))));
    expect(c.selectedDay.day, 20);
    await openMedicationHistory(tester);
    expect(find.text('Mẫu'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byType(NavigationDestination).at(i));
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<NavigationBar>(find.byType(NavigationBar))
              .selectedIndex,
          i);
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets(
      'preview family routes use memory UI, logout clears history and restart resets',
      (tester) async {
    tester.view.physicalSize = const Size(430, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(AdherenceDemoApp(now: DateTime.utc(2026, 10, 22)));
    await tester.pumpAndSettle();
    var context = tester.element(find.byKey(const Key('history-title')));
    final navigator = Navigator.of(context);
    navigator.pushNamed(AppRoutes.familyShareLink);
    await tester.pumpAndSettle();
    expect(find.text('MẪU'), findsOneWidget);
    expect(find.byKey(const Key('invite-share')), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    navigator.pushNamed(AppRoutes.familyScanCode);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    context = tester.element(find.byKey(const Key('history-title')));
    final auth = AuthScope.read(context);
    await tester.tap(find.byTooltip('Giải thích lịch sử'));
    await tester.pumpAndSettle();
    await auth.signOut();
    await tester.pump();
    expect(find.text('Về lịch sử', skipOffstage: false), findsNothing);
    expect(find.text('Metformin 500 mg', skipOffstage: false), findsNothing);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('history-title'), skipOffstage: false),
        findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.pumpWidget(AdherenceDemoApp(now: DateTime.utc(2026, 10, 23)));
    await tester.pumpAndSettle();
    expect(find.text('4/6 đã uống'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _NoPreviewNetwork extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      throw StateError('Network in app preview');
}
