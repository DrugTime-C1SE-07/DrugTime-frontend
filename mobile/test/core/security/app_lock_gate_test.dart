import 'package:drugtime_mobile/core/security/app_lock_controller.dart';
import 'package:drugtime_mobile/core/security/app_lock_gate.dart';
import 'package:drugtime_mobile/core/security/app_lock_settings_store.dart';
import 'package:drugtime_mobile/core/security/top_route_observer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_lock_test_fakes.dart';

const _reminder = '/reminders/dose';

void main() {
  late FakeAuthenticator auth;
  late AppLockController controller;
  late TopRouteObserver observer;
  late GlobalKey<NavigatorState> navigator;
  late int contentTaps;
  late int signOuts;

  Future<void> pumpApp(WidgetTester tester,
      {bool enabled = true, bool load = true}) async {
    controller = AppLockController(
      store: MemoryAppLockSettingsStore(enabled),
      authenticator: auth,
      leavePlatform: FakeLeavePlatform(),
      useLeaveHint: true,
    );
    if (load) await controller.load(signedIn: true);
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigator,
      navigatorObservers: [observer],
      builder: (context, child) => AppLockGate(
        controller: controller,
        topRoute: observer.topRoute,
        exemptRoutes: const {_reminder},
        onSignOut: () async => signOuts++,
        child: child!,
      ),
      onGenerateRoute: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => Scaffold(
          body: TextButton(
            onPressed: () => contentTaps++,
            child: Text('Lịch sử liều ${settings.name}'),
          ),
        ),
      ),
    ));
  }

  setUp(() {
    auth = FakeAuthenticator(result: false);
    observer = TopRouteObserver();
    navigator = GlobalKey<NavigatorState>();
    contentTaps = 0;
    signOuts = 0;
  });

  testWidgets('locked: shows lock screen, hides and blocks content',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpApp(tester);
    await tester.pump();

    expect(find.byKey(const Key('app-lock-screen')), findsOneWidget);
    expect(auth.calls, 1, reason: 'auto prompt once on show');
    expect(find.semantics.byLabel(RegExp('Lịch sử liều')), findsNothing);

    await tester.tap(find.textContaining('Lịch sử liều'), warnIfMissed: false);
    expect(contentTaps, 0);
    semantics.dispose();
  });

  testWidgets('failed prompt keeps lock; Mở khóa retries and unlocks',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpApp(tester);
    await tester.pump();
    expect(find.byKey(const Key('app-lock-error')), findsOneWidget);

    auth.result = true;
    await tester.tap(find.byKey(const Key('app-lock-unlock')));
    await tester.pump();

    expect(find.byKey(const Key('app-lock-screen')), findsNothing);
    expect(find.semantics.byLabel(RegExp('Lịch sử liều')), findsOneWidget);
    await tester.tap(find.textContaining('Lịch sử liều'));
    expect(contentTaps, 1);
    semantics.dispose();
  });

  testWidgets('obscured: shows privacy cover without content', (tester) async {
    final semantics = tester.ensureSemantics();
    auth.result = true;
    await pumpApp(tester);
    await tester.pump();
    await controller.onLifecycle(AppLifecycleState.inactive);
    await tester.pump();

    expect(find.byKey(const Key('app-privacy-cover')), findsOneWidget);
    expect(find.semantics.byLabel(RegExp('Lịch sử liều')), findsNothing);
    semantics.dispose();
  });

  testWidgets('not loaded yet: fail-closed cover', (tester) async {
    await pumpApp(tester, load: false);
    expect(find.byKey(const Key('app-privacy-cover')), findsOneWidget);
  });

  testWidgets('dose reminder route is exempt; lock returns after pop',
      (tester) async {
    await pumpApp(tester);
    await tester.pump();
    final promptsBefore = auth.calls;

    navigator.currentState!.pushNamed(_reminder);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('app-lock-screen')), findsNothing);
    expect(find.text('Lịch sử liều $_reminder'), findsOneWidget);
    expect(auth.calls, promptsBefore, reason: 'no prompt over the reminder');

    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('app-lock-screen')), findsOneWidget);
  });

  testWidgets('Đăng xuất calls sign out', (tester) async {
    await pumpApp(tester);
    await tester.pump();

    await tester.tap(find.byKey(const Key('app-lock-sign-out')));
    await tester.pump();

    expect(signOuts, 1);
  });

  testWidgets('disabled: no lock, no cover', (tester) async {
    await pumpApp(tester, enabled: false);
    await tester.pump();
    await controller.onLifecycle(AppLifecycleState.inactive);
    await tester.pump();

    expect(find.byKey(const Key('app-lock-screen')), findsNothing);
    expect(find.byKey(const Key('app-privacy-cover')), findsNothing);
    expect(auth.calls, 0);
  });
}
