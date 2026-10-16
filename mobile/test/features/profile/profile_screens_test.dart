import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/features/profile/presentation/screens/personal_profile_screen.dart';
import 'package:drugtime_mobile/features/profile/presentation/screens/medical_profile_screen.dart';
import 'package:drugtime_mobile/features/profile/presentation/screens/profile_screen.dart';
import 'package:drugtime_mobile/features/profile/presentation/state/profile_controller.dart';
import 'package:drugtime_mobile/features/profile/domain/entities/profile_failure.dart';
import 'package:drugtime_mobile/features/profile/presentation/widgets/profile_notices.dart';
import 'profile_test_helpers.dart';
import 'profile_widget_helpers.dart';

void main() {
  testWidgets(
      'form validates name, keeps draft on error and shows success only after ACK',
      (tester) async {
    final repo = FakeProfileRepository();
    final c = ProfileController(repo);
    addTearDown(c.dispose);
    await tester.pumpWidget(profileApp(c, const PersonalProfileScreen()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('profile-name')), '   ');
    await tester.ensureVisible(find.byKey(const Key('save-profile')));
    await tester.tap(find.byKey(const Key('save-profile')));
    await tester.pump();
    expect(find.text('Vui lòng nhập họ và tên'), findsOneWidget);
    expect(repo.writes, 0);
    await tester.enterText(find.byKey(const Key('profile-name')), 'Tên mới');
    repo.writeFailure = const ProfileFailure(ProfileFailureKind.network);
    await tester.ensureVisible(find.byKey(const Key('save-profile')));
    await tester.tap(find.byKey(const Key('save-profile')));
    await tester.pumpAndSettle();
    expect(find.text('Tên mới'), findsOneWidget);
    expect(find.text('Đã lưu thay đổi'), findsNothing);
    expect(find.byKey(const Key('profile-save-success-snackbar')), findsNothing);
    repo.writeFailure = null;
    repo.pendingWrite = Completer();
    await tester.ensureVisible(find.byKey(const Key('save-profile')));
    await tester.tap(find.byKey(const Key('save-profile')));
    await tester.pump();
    expect(find.text('Đang lưu…'), findsOneWidget);
    expect(find.text('Đã lưu thay đổi'), findsNothing);
    repo.pendingWrite!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Đã lưu thay đổi'), findsOneWidget);
    expect(find.byKey(const Key('profile-save-success-snackbar')), findsOneWidget);
    expect(
        find.descendant(
            of: find.byType(ProfileNotices),
            matching: find.text('Đã lưu thay đổi')),
        findsNothing);
    expect(repo.value.fullName, 'Tên mới');
  });

  testWidgets('partial save keeps inline warning instead of success snackbar',
      (tester) async {
    final repo = FakeProfileRepository()..failFetchAfterWrite = true;
    final c = ProfileController(repo);
    addTearDown(c.dispose);
    await tester.pumpWidget(profileApp(c, const PersonalProfileScreen()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('profile-name')), 'Tên mới');
    await tester.ensureVisible(find.byKey(const Key('save-profile')));
    await tester.tap(find.byKey(const Key('save-profile')));
    await tester.pumpAndSettle();

    expect(repo.writes, 1);
    expect(find.byKey(const Key('profile-save-success-snackbar')), findsNothing);
    expect(find.text('Đã lưu. Chưa tải lại được hồ sơ, vui lòng tải lại.'),
        findsOneWidget);
    expect(find.text('Không thể kết nối. Vui lòng thử lại.'), findsOneWidget);
  });

  testWidgets('email is editable draft but never part of saved profile',
      (tester) async {
    final repo = FakeProfileRepository();
    final c = ProfileController(repo);
    addTearDown(c.dispose);
    await tester.pumpWidget(profileApp(c, const PersonalProfileScreen()));
    await tester.pumpAndSettle();

    final email = find.byKey(const Key('profile-email'));
    expect(email, findsOneWidget);
    expect(tester.widget<TextFormField>(email).controller!.text, isEmpty);
    await tester.enterText(email, 'not-an-email');
    await tester.ensureVisible(find.byKey(const Key('save-profile')));
    await tester.tap(find.byKey(const Key('save-profile')));
    await tester.pumpAndSettle();
    expect(find.text('Email không hợp lệ'), findsOneWidget);
    expect(repo.writes, 0);

    await tester.enterText(email, 'mai@example.com');
    await tester.ensureVisible(find.byKey(const Key('save-profile')));
    await tester.tap(find.byKey(const Key('save-profile')));
    await tester.pumpAndSettle();
    expect(repo.writes, 1);
    expect(repo.lastDraft!.fullName, 'Nguyễn Mai');
    expect(find.text('Email chưa được đồng bộ với máy chủ.'), findsOneWidget);
  });
  testWidgets('profile only loads when tab is activated, opens personal route',
      (tester) async {
    final repo = FakeProfileRepository();
    final c = ProfileController(repo);
    addTearDown(c.dispose);
    await tester.pumpWidget(profileApp(c, const ProfileScreen(active: false)));
    await tester.pumpAndSettle();
    expect(repo.reads, 0);
    await tester.pumpWidget(profileApp(c, const ProfileScreen(active: true)));
    await tester.pumpAndSettle();
    expect(repo.reads, 1);
    await tester.tap(find.text('Thông tin cá nhân'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-name')), findsOneWidget);
    expect(repo.reads, 2);
  });

  testWidgets('profile shows the six Figma menu rows in design order',
      (tester) async {
    final repo = FakeProfileRepository();
    final c = ProfileController(repo);
    addTearDown(c.dispose);
    await tester.pumpWidget(profileApp(c, const ProfileScreen(active: false)));
    await tester.pumpAndSettle();

    final labels = [
      'Thông tin cá nhân',
      'Thông tin y tế',
      'Người giám sát',
      'Thông báo & Nhắc nhở',
      'Quyền riêng tư & Bảo mật',
      'Trợ giúp',
    ];
    for (final label in labels) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.byKey(const Key('personal-profile-tile')), findsOneWidget);
    expect(find.byKey(const Key('medical-profile-tile')), findsOneWidget);
    expect(find.byKey(const Key('supervisors-tile')), findsOneWidget);
    expect(find.byKey(const Key('notifications-tile')), findsOneWidget);
    expect(find.byKey(const Key('privacy-settings-tile')), findsOneWidget);
    expect(find.byKey(const Key('profile-help-tile')), findsOneWidget);
    final rowKeys = [
      const Key('personal-profile-tile'),
      const Key('medical-profile-tile'),
      const Key('supervisors-tile'),
      const Key('notifications-tile'),
      const Key('privacy-settings-tile'),
      const Key('profile-help-tile'),
    ];
    final rowY =
        rowKeys.map((key) => tester.getTopLeft(find.byKey(key)).dy).toList();
    expect(rowY, orderedEquals([...rowY]..sort()));
    expect(find.text('UI Catalog (Duyệt tất cả màn hình)'), findsNothing);
    expect(find.text('Đăng xuất'), findsNothing);
  });

  testWidgets('medical catalog adds, edits metadata and confirms delete',
      (tester) async {
    final repo = FakeProfileRepository();
    final c = ProfileController(repo);
    addTearDown(c.dispose);
    await tester.pumpWidget(profileApp(c, const MedicalProfileScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thêm bệnh khác'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xem thêm'));
    await tester.pumpAndSettle();
    expect(repo.offsets, [0, 1]);
    await tester.tap(find.text('Tăng huyết áp'));
    await tester.pumpAndSettle();
    expect(c.profile!.conditions.length, 1);
    await tester.tap(find.text('Bệnh nền'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('condition-stage')), 'II');
    await tester.tap(find.text('Lưu thông tin bệnh'));
    await tester.pumpAndSettle();
    expect(repo.lastLink, 99);
    expect(repo.lastPatch, {'stage': 'II'});
    await tester.tap(find.text('Bệnh nền'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa bệnh khỏi hồ sơ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa'));
    await tester.pumpAndSettle();
    expect(c.profile!.conditions, isEmpty);
  });
  testWidgets('403 removes sensitive form and offers consent action',
      (tester) async {
    final repo = FakeProfileRepository();
    final c = ProfileController(repo);
    addTearDown(c.dispose);
    await tester.pumpWidget(profileApp(c, const PersonalProfileScreen()));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('profile-name')), 'Private draft');
    repo.fetchFailure = const ProfileFailure(ProfileFailureKind.consent);
    await c.load();
    await tester.pumpAndSettle();
    expect(find.text('Private draft'), findsNothing);
    expect(find.byKey(const Key('profile-name')), findsNothing);
    expect(find.text('Xem và đồng ý'), findsOneWidget);
  });
}
