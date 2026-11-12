import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/features/profile/presentation/screens/profile_screen.dart';
import 'package:drugtime_mobile/features/profile/presentation/screens/personal_profile_screen.dart';
import 'package:drugtime_mobile/features/profile/presentation/screens/medical_profile_screen.dart';
import 'package:drugtime_mobile/features/profile/presentation/state/profile_controller.dart';
import 'package:drugtime_mobile/app/theme/app_theme.dart';
import 'package:drugtime_mobile/features/profile/domain/entities/condition.dart';
import 'package:drugtime_mobile/features/profile/domain/entities/health_profile.dart';
import 'package:drugtime_mobile/features/profile/presentation/widgets/profile_icons.dart';
import 'profile_test_helpers.dart';
import 'profile_widget_helpers.dart';

void main() {
  testWidgets('save snackbar floats above save footer and system navigation',
      (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    tester.view.viewPadding = const FakeViewPadding(bottom: 24);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewPadding);
    final c = ProfileController(FakeProfileRepository());
    addTearDown(c.dispose);
    await tester.pumpWidget(profileApp(c, const PersonalProfileScreen()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('profile-name')), 'Tên mới');
    await tester.ensureVisible(find.byKey(const Key('save-profile')));
    await tester.tap(find.byKey(const Key('save-profile')));
    await tester.pumpAndSettle();

    final snackbar =
        tester.getRect(find.byKey(const Key('profile-save-success-snackbar')));
    final saveButton = tester.getRect(find.byKey(const Key('save-profile')));
    expect(snackbar.bottom, lessThan(saveButton.top));
    expect(saveButton.bottom, lessThanOrEqualTo(812 - 24));
  });

  testWidgets('save button stays fixed while scrolling to email',
      (tester) async {
    tester.view.physicalSize = const Size(375, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = ProfileController(FakeProfileRepository());
    addTearDown(c.dispose);
    await tester.pumpWidget(profileApp(c, const PersonalProfileScreen()));
    await tester.pumpAndSettle();
    final save = find.byKey(const Key('save-profile'));
    final initialTop = tester.getTopLeft(save).dy;
    await tester.ensureVisible(find.byKey(const Key('profile-email')));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(save).dy, initialTop);
    expect(tester.getBottomRight(save).dy, lessThanOrEqualTo(640));
  });

  for (final size in [const Size(375, 812), const Size(320, 640)]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('layout $size text $scale with keyboard, save reachable',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repo = FakeProfileRepository();
        final c = ProfileController(repo);
        addTearDown(c.dispose);
        await tester.pumpWidget(profileApp(c, const PersonalProfileScreen(),
            textScale: scale, insets: const EdgeInsets.only(bottom: 240)));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const Key('save-profile')));
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(
            profileApp(c, const MedicalProfileScreen(), textScale: scale));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester
            .pumpWidget(profileApp(c, const ProfileScreen(), textScale: scale));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('capture in-scope screens for visual review', (tester) async {
    const path = String.fromEnvironment('PROFILE_CAPTURE_DIR');
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = FakeProfileRepository();
    final c = ProfileController(repo);
    addTearDown(c.dispose);
    if (path.isNotEmpty) {
      await tester.runAsync(() async {
        final bytes = await File('C:/Windows/Fonts/segoeui.ttf').readAsBytes();
        await (FontLoader('ProfilePreview')
              ..addFont(Future.value(ByteData.sublistView(bytes))))
            .load();
      });
    }
    for (final entry in <String, Widget>{
      'profile': const ProfileScreen(),
      'personal': const PersonalProfileScreen(),
      'medical': const MedicalProfileScreen()
    }.entries) {
      if (entry.key == 'medical') {
        repo.value = HealthProfile(
            fullName: repo.value.fullName,
            dateOfBirth: repo.value.dateOfBirth,
            gender: repo.value.gender,
            email: repo.value.email,
            phone: repo.value.phone,
            conditions: const [
              ProfileCondition(id: 1, conditionId: 3, name: 'Tăng huyết áp'),
              ProfileCondition(
                  id: 2, conditionId: 4, name: 'Tiểu đường type 2'),
            ]);
      }
      final key = GlobalKey();
      await tester.pumpWidget(profileApp(
          c,
          RepaintBoundary(
              key: key,
              child: ColoredBox(color: AppColors.canvas, child: entry.value)),
          previewFont: path.isNotEmpty));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (path.isNotEmpty) {
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory(path).create(recursive: true);
          await File('$path/implement-${entry.key}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    }
  });

  group('Figma metrics', () {
    void phoneView(WidgetTester tester, Size size) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    testWidgets('S08 card 88, menu row 72, icon tile 40, soft divider',
        (tester) async {
      phoneView(tester, const Size(375, 812));
      final c = ProfileController(FakeProfileRepository());
      addTearDown(c.dispose);
      await tester.pumpWidget(profileApp(c, const ProfileScreen()));
      await tester.pumpAndSettle();

      final card = find.byKey(const Key('profile-card'));
      expect(tester.getSize(card).height, 88);
      expect(tester.getSize(card).width, 335);
      expect(
          (tester.widget<Container>(card).decoration! as BoxDecoration).color,
          AppColors.brandTint);
      expect(find.text('0912345678'), findsOneWidget);

      final row = find.byKey(const Key('personal-profile-tile'));
      expect(tester.getSize(row).height, 72);
      final tile = tester.getSize(
          find.descendant(of: row, matching: find.byType(Container)).first);
      expect(tile, const Size(AppSizes.iconTile, AppSizes.iconTile));
      expect(tester.widget<Divider>(find.byType(Divider).first).color,
          AppColors.dividerSoft);
    });

    testWidgets('S08 phone subtitle falls back when phone_number is null',
        (tester) async {
      phoneView(tester, const Size(375, 812));
      final repo = FakeProfileRepository()
        ..value = HealthProfile(
            fullName: 'Nguyễn Mai',
            dateOfBirth: DateTime(1960, 3, 1),
            gender: 'nu');
      final c = ProfileController(repo);
      addTearDown(c.dispose);
      await tester.pumpWidget(profileApp(c, const ProfileScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Chưa có số điện thoại'), findsOneWidget);
      expect(find.text('Chưa cung cấp'), findsNothing);
    });

    testWidgets(
        'S08-1 field is 48 tall, phone read-only, only name/email typed',
        (tester) async {
      phoneView(tester, const Size(375, 812));
      final c = ProfileController(FakeProfileRepository());
      addTearDown(c.dispose);
      await tester.pumpWidget(profileApp(c, const PersonalProfileScreen()));
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byKey(const Key('profile-name'))).height,
          closeTo(48, 2));
      final nameField = tester.widget<TextField>(find.descendant(
          of: find.byKey(const Key('profile-name')),
          matching: find.byType(TextField)));
      expect(nameField.decoration!.contentPadding,
          const EdgeInsets.symmetric(horizontal: 14, vertical: 13));
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.text('LIÊN HỆ'), findsOneWidget);
      expect(find.text('0912345678'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      expect(find.text('Nữ'), findsOneWidget);
    });

    testWidgets('S08-2 chip is a 42 high brand pill with a check icon',
        (tester) async {
      phoneView(tester, const Size(375, 812));
      final repo = FakeProfileRepository()
        ..value = HealthProfile(
            fullName: 'Nguyễn Mai',
            dateOfBirth: DateTime(1960, 3, 1),
            gender: 'nu',
            phone: '+84912345678',
            conditions: const [
              ProfileCondition(
                  id: 1,
                  conditionId: 3,
                  name: 'Tăng huyết áp',
                  subtype: null,
                  stage: null)
            ]);
      final c = ProfileController(repo);
      addTearDown(c.dispose);
      await tester.pumpWidget(profileApp(c, const MedicalProfileScreen()));
      await tester.pumpAndSettle();

      final chip = find.byKey(const Key('condition-chip-1'));
      expect(tester.getSize(chip).height, 42);
      final ink = tester.widget<Ink>(
          find.descendant(of: chip, matching: find.byType(Ink)).first);
      expect((ink.decoration! as BoxDecoration).color, AppColors.brand);
      expect(find.descendant(of: chip, matching: find.byType(ProfileIcon)),
          findsOneWidget);
      expect(find.text('Thêm bệnh khác'), findsOneWidget);
    });

    testWidgets('pairs sit side by side at 375 and stack at 320',
        (tester) async {
      phoneView(tester, const Size(375, 812));
      final c = ProfileController(FakeProfileRepository());
      addTearDown(c.dispose);
      await tester.pumpWidget(profileApp(c, const PersonalProfileScreen()));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('Ngày sinh')).dy,
          tester.getTopLeft(find.text('Giới tính')).dy);

      tester.view.physicalSize = const Size(320, 640);
      await tester.pumpWidget(profileApp(c, const PersonalProfileScreen()));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('Ngày sinh')).dy,
          lessThan(tester.getTopLeft(find.text('Giới tính')).dy));
    });

    testWidgets('no unsupported Figma field is rendered', (tester) async {
      phoneView(tester, const Size(375, 812));
      final c = ProfileController(FakeProfileRepository());
      addTearDown(c.dispose);
      for (final screen in <Widget>[
        const ProfileScreen(),
        const PersonalProfileScreen(),
        const MedicalProfileScreen()
      ]) {
        await tester.pumpWidget(profileApp(c, screen));
        await tester.pumpAndSettle();
        for (final label in [
          'Chiều cao',
          'Cân nặng',
          'Nhóm máu',
          'Bác sĩ điều trị',
          'Dị ứng',
        ]) {
          expect(find.textContaining(label), findsNothing,
              reason: '$label không có trong HealthProfileResponse');
        }
      }
    });
  });
}
