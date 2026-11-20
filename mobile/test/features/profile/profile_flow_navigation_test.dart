import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/app/router.dart';
import 'package:drugtime_mobile/app/theme/app_theme.dart';
import 'package:drugtime_mobile/features/profile/presentation/screens/notification_preferences_screen.dart';
import 'package:drugtime_mobile/features/profile/presentation/screens/profile_settings_screen.dart';
import 'package:drugtime_mobile/features/profile/presentation/screens/reminder_sound_screen.dart';
import 'package:drugtime_mobile/features/family_link/presentation/screens/invite_caregiver_screen.dart';
import 'package:drugtime_mobile/features/family_link/presentation/screens/link_request_result_screen.dart';
import 'package:drugtime_mobile/features/family_link/presentation/state/link_request_controller.dart';

void main() {
  testWidgets(
      'notification controls cannot change or save; sound route and back work',
      (t) async {
    await t.pumpWidget(MaterialApp(
        theme: buildAppTheme(),
        home: const NotificationPreferencesScreen(),
        onGenerateRoute: onGenerateRoute));
    expect(
        t
            .widgetList<Switch>(find.byType(Switch))
            .every((w) => w.onChanged == null),
        isTrue);
    final save = find.widgetWithText(FilledButton, 'Lưu thay đổi');
    await t.scrollUntilVisible(save, 300);
    await t.pumpAndSettle();
    expect(t.widget<FilledButton>(save).onPressed, isNull);
    final sound = find.text('Âm thanh nhắc nhở');
    await t.scrollUntilVisible(sound, -300);
    await t.pumpAndSettle();
    await t.tap(sound);
    await t.pumpAndSettle();
    expect(find.byType(ReminderSoundScreen), findsOneWidget);
    expect(find.byType(Slider), findsNothing);
    await t.tap(find.byType(BackButton));
    await t.pumpAndSettle();
    expect(find.byType(NotificationPreferencesScreen), findsOneWidget);
  });
  testWidgets(
      'settings invokes supplied logout once and prevents duplicate tap while busy',
      (t) async {
    var calls = 0;
    final pending = Completer<void>();
    await t.pumpWidget(MaterialApp(
        theme: buildAppTheme(),
        home: ProfileSettingsScreen(args: ProfileSettingsArgs(logout: () {
          calls++;
          return pending.future;
        }))));
    final action = find.byKey(const Key('settings-logout'));
    await t.ensureVisible(action);
    await t.pumpAndSettle();
    await t.tap(action);
    await t.pump();
    expect(calls, 1);
    expect(find.text('Đang đăng xuất…'), findsOneWidget);
    await t.tap(action);
    await t.pump();
    expect(calls, 1);
    pending.complete();
    await t.pumpAndSettle();
    expect(find.text('Đăng xuất'), findsOneWidget);
    await t.tap(action);
    await t.pumpAndSettle();
    expect(calls, 2);
  });
  testWidgets('settings direct entry does not invent a logout handler',
      (t) async {
    await t.pumpWidget(MaterialApp(
        theme: buildAppTheme(), home: const ProfileSettingsScreen()));
    final row = find.byKey(const Key('settings-logout'));
    await t.ensureVisible(row);
    await t.pumpAndSettle();
    await t.tap(row);
    await t.pump();
    expect(find.text('Đang đăng xuất…'), findsNothing);
    expect(find.text('Chưa khả dụng'), findsWidgets);
  });
  testWidgets('invitation choices use existing route names without submitting',
      (t) async {
    for (final pair in [
      ('Hiện mã QR của bạn', AppRoutes.familyMyCode),
      ('Quét mã QR người thân', AppRoutes.familyScanCode),
      ('Gửi link mời', AppRoutes.familyShareLink)
    ]) {
      String? opened;
      await t.pumpWidget(MaterialApp(
          key: UniqueKey(),
          theme: buildAppTheme(),
          home: const InviteCaregiverScreen(),
          onGenerateRoute: (s) {
            opened = s.name;
            return MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: Text('Đích')));
          }));
      await t.tap(find.text(pair.$1));
      await t.pumpAndSettle();
      expect(opened, pair.$2);
    }
  });
  testWidgets(
      'waiting result never displays patient identity or a cancel action',
      (t) async {
    await t.pumpWidget(MaterialApp(
        theme: buildAppTheme(),
        home:
            const LinkRequestResultScreen(outcome: LinkSubmitOutcome.waiting)));
    await t.pumpAndSettle();
    expect(find.text('Đang chờ xác nhận'), findsOneWidget);
    expect(find.text('Chưa có quyền xem dữ liệu'), findsOneWidget);
    expect(find.text('Hủy yêu cầu'), findsNothing);
    expect(find.textContaining('Nguyễn'), findsNothing);
  });
}
