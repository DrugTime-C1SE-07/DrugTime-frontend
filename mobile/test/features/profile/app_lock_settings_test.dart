import 'package:drugtime_mobile/core/security/app_lock_controller.dart';
import 'package:drugtime_mobile/core/security/app_lock_gate.dart';
import 'package:drugtime_mobile/core/security/app_lock_settings_store.dart';
import 'package:drugtime_mobile/features/profile/presentation/screens/profile_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/security/app_lock_test_fakes.dart';

void main() {
  late FakeAuthenticator auth;
  late MemoryAppLockSettingsStore store;
  late AppLockController lock;

  Future<void> pump(WidgetTester tester) async {
    lock = AppLockController(
      store: store,
      authenticator: auth,
      leavePlatform: FakeLeavePlatform(),
      useLeaveHint: true,
    );
    await lock.load(signedIn: true);
    await tester.pumpWidget(MaterialApp(
      home: AppLockScope(
        controller: lock,
        child: ProfileSettingsScreen(
            args: ProfileSettingsArgs(logout: () async {})),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Switch switchWidget(WidgetTester tester) =>
      tester.widget<Switch>(find.byKey(const Key('settings-app-lock-switch')));

  setUp(() {
    auth = FakeAuthenticator();
    store = MemoryAppLockSettingsStore();
  });

  testWidgets('no screen lock on device: switch disabled with guidance',
      (tester) async {
    auth.supported = false;
    await pump(tester);

    expect(switchWidget(tester).onChanged, isNull);
    expect(find.text('Hãy đặt khóa màn hình cho điện thoại trước'),
        findsOneWidget);
  });

  testWidgets('turning on authenticates then saves', (tester) async {
    await pump(tester);
    expect(switchWidget(tester).value, isFalse);

    await tester.tap(find.byKey(const Key('settings-app-lock-switch')));
    await tester.pumpAndSettle();

    expect(auth.calls, 1);
    expect(store.enabled, isTrue);
    expect(switchWidget(tester).value, isTrue);
  });

  testWidgets('failed authentication keeps it off and explains why',
      (tester) async {
    auth.result = false;
    await pump(tester);

    await tester.tap(find.byKey(const Key('settings-app-lock-switch')));
    await tester.pumpAndSettle();

    expect(store.enabled, isFalse);
    expect(switchWidget(tester).value, isFalse);
    expect(find.text('Chưa xác thực được nên chưa bật khóa ứng dụng'),
        findsOneWidget);
  });

  testWidgets('turning off disables without a prompt', (tester) async {
    store.enabled = true;
    await pump(tester);
    await lock.unlock();
    final promptsBefore = auth.calls;
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('settings-app-lock-switch')));
    await tester.pumpAndSettle();

    expect(store.enabled, isFalse);
    expect(switchWidget(tester).value, isFalse);
    expect(auth.calls, promptsBefore);
  });

  testWidgets('section is hidden when the app has no lock controller',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ProfileSettingsScreen()));
    expect(find.byKey(const Key('settings-app-lock')), findsNothing);
  });
}
