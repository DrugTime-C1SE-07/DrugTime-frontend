import 'dart:async';

import 'package:drugtime_mobile/core/security/app_lock_controller.dart';
import 'package:drugtime_mobile/core/security/app_lock_settings_store.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_lock_test_fakes.dart';

void main() {
  late MemoryAppLockSettingsStore store;
  late FakeAuthenticator auth;
  late FakeLeavePlatform leave;

  AppLockController build({bool android = true}) => AppLockController(
        store: store,
        authenticator: auth,
        leavePlatform: leave,
        useLeaveHint: android,
      );

  Future<AppLockController> enabledController({bool android = true}) async {
    store.enabled = true;
    final c = build(android: android);
    await c.load(signedIn: true);
    await c.unlock();
    return c;
  }

  Future<void> leaveAndReturn(AppLockController c, {bool paused = true}) async {
    await c.onLifecycle(AppLifecycleState.inactive);
    if (paused) {
      await c.onLifecycle(AppLifecycleState.hidden);
      await c.onLifecycle(AppLifecycleState.paused);
    }
    await c.onLifecycle(AppLifecycleState.resumed);
  }

  setUp(() {
    store = MemoryAppLockSettingsStore();
    auth = FakeAuthenticator();
    leave = FakeLeavePlatform();
  });

  group('enable / disable', () {
    test('saves enabled only after successful authentication', () async {
      final c = build();
      await c.load(signedIn: true);

      expect(await c.enable(), isTrue);
      expect(c.enabled, isTrue);
      expect(store.enabled, isTrue);
      expect(leave.recentsPrivacy, isTrue);
      expect(c.locked, isFalse);
    });

    test('stays disabled when authentication fails or is cancelled', () async {
      auth.result = false;
      final c = build();
      await c.load(signedIn: true);

      expect(await c.enable(), isFalse);
      expect(c.enabled, isFalse);
      expect(store.enabled, isFalse);
    });

    test('disable clears the setting and unlocks', () async {
      final c = await enabledController();
      await c.disable();
      expect(c.enabled, isFalse);
      expect(store.enabled, isFalse);
      expect(leave.recentsPrivacy, isFalse);
    });
  });

  group('cold start', () {
    test('locks when enabled and signed in', () async {
      store.enabled = true;
      final c = build();
      expect(c.obscured, isTrue, reason: 'fail-closed before load');
      await c.load(signedIn: true);
      expect(c.locked, isTrue);
    });

    test('does not lock when disabled or signed out', () async {
      final off = build();
      await off.load(signedIn: true);
      expect(off.locked, isFalse);
      expect(off.obscured, isFalse);

      store.enabled = true;
      final signedOut = build();
      await signedOut.load(signedIn: false);
      expect(signedOut.locked, isFalse);
    });
  });

  group('Android lifecycle', () {
    test('locks immediately when the user left the app', () async {
      final c = await enabledController();
      leave.userLeft = true;
      await leaveAndReturn(c);
      expect(c.locked, isTrue);
      expect(c.obscured, isTrue);
    });

    test('does not lock after app-opened activities (picker, permission)',
        () async {
      final c = await enabledController();
      leave.userLeft = false;
      await leaveAndReturn(c);
      expect(c.locked, isFalse);
      expect(c.obscured, isFalse);
    });

    test('inactive only (notification shade) does not ask native or lock',
        () async {
      final c = await enabledController();
      await leaveAndReturn(c, paused: false);
      expect(leave.consumed, 0);
      expect(c.locked, isFalse);
    });

    test('consumes the native flag even while disabled', () async {
      final c = build();
      await c.load(signedIn: true);
      await leaveAndReturn(c);
      expect(leave.consumed, 1);
      expect(c.locked, isFalse);
      expect(c.obscured, isFalse);
    });
  });

  group('iOS lifecycle', () {
    test('inactive then resumed (Face ID, alerts) does not lock', () async {
      final c = await enabledController(android: false);
      await leaveAndReturn(c, paused: false);
      expect(c.locked, isFalse);
      expect(c.obscured, isFalse);
    });

    test('paused then resumed locks without asking native', () async {
      final c = await enabledController(android: false);
      await leaveAndReturn(c);
      expect(c.locked, isTrue);
      expect(leave.consumed, 0);
    });
  });

  group('privacy cover', () {
    test('inactive obscures when enabled', () async {
      final c = await enabledController();
      await c.onLifecycle(AppLifecycleState.inactive);
      expect(c.obscured, isTrue);
    });

    test('inactive does nothing when disabled', () async {
      final c = build();
      await c.load(signedIn: true);
      await c.onLifecycle(AppLifecycleState.inactive);
      expect(c.obscured, isFalse);
    });
  });

  group('unlock', () {
    test('failure keeps the lock; success removes lock and cover', () async {
      store.enabled = true;
      final c = build();
      await c.load(signedIn: true);

      auth.result = false;
      expect(await c.unlock(), isFalse);
      expect(c.locked, isTrue);

      auth.result = true;
      expect(await c.unlock(), isTrue);
      expect(c.locked, isFalse);
      expect(c.obscured, isFalse);
    });

    test('concurrent unlock calls show only one prompt', () async {
      store.enabled = true;
      final c = build();
      await c.load(signedIn: true);
      auth.pending = Completer<bool>();

      final first = c.unlock();
      final second = c.unlock();
      auth.pending!.complete(true);

      expect(await first, isTrue);
      expect(await second, isTrue);
      expect(auth.calls, 1);
    });

    test('lifecycle events caused by the prompt do not re-lock', () async {
      store.enabled = true;
      final c = build(android: false);
      await c.load(signedIn: true);
      auth.pending = Completer<bool>();

      final unlocking = c.unlock();
      await c.onLifecycle(AppLifecycleState.inactive);
      await c.onLifecycle(AppLifecycleState.resumed);
      auth.pending!.complete(true);

      expect(await unlocking, isTrue);
      expect(c.locked, isFalse);
      expect(auth.calls, 1);
    });
  });

  group('sign out', () {
    test('signing out clears the setting and the lock', () async {
      store.enabled = true;
      final c = build();
      await c.load(signedIn: true);

      await c.onAuthChanged(signedIn: false);

      expect(c.enabled, isFalse);
      expect(c.locked, isFalse);
      expect(store.enabled, isFalse);
    });

    test('auth updates while still signed out do not clear the setting',
        () async {
      store.enabled = true;
      final c = build();
      await c.load(signedIn: false);
      await c.onAuthChanged(signedIn: false);
      expect(store.enabled, isTrue);
    });
  });
}
