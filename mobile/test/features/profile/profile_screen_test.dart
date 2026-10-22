import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/features/profile/presentation/screens/profile_screen.dart';
import 'package:drugtime_mobile/features/profile/presentation/state/profile_controller.dart';
import 'package:drugtime_mobile/features/auth/presentation/state/auth_controller.dart';
import 'package:drugtime_mobile/features/auth/data/repositories/in_memory_auth_repository.dart';
import '../../core/notification/device_token_coordinator_test.dart'
    show tokenSession;

void main() {
  testWidgets(
      'logout waits, reports cleanup failure and permits retry with old session',
      (tester) async {
    final auth = AuthController(InMemoryAuthRepository(
        initialSession: tokenSession('A'), simulatedDelay: Duration.zero));
    await auth.initSession();
    final pending = Completer<void>();
    auth.beforeSignOut = (_) => pending.future;
    final profile = ProfileController(null);
    await tester.pumpWidget(AuthScope(
        controller: auth,
        child: ProfileScope(
            controller: profile,
            child: const MaterialApp(
                home: Scaffold(body: ProfileScreen(active: false))))));
    await tester.tap(find.byTooltip('Cài đặt hồ sơ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đăng xuất'));
    await tester.pump();
    expect(auth.isAuthenticated, true);
    expect(auth.isSigningOut, true);
    pending.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(auth.isAuthenticated, true);
    expect(find.textContaining('Chưa hoàn tất đăng xuất'), findsOneWidget);
    auth.beforeSignOut = (_) async {};
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(auth.isAuthenticated, false);
    await tester.pumpWidget(const SizedBox());
    auth.dispose();
    profile.dispose();
  });
}
