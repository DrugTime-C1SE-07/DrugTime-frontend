import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/app/app.dart';
import 'package:drugtime_mobile/app/app_shell.dart';
import 'package:drugtime_mobile/app/router.dart';
import 'package:drugtime_mobile/features/auth/data/repositories/in_memory_auth_repository.dart';
import 'package:drugtime_mobile/features/auth/domain/entities/auth_session.dart';
import 'package:drugtime_mobile/features/auth/presentation/state/auth_controller.dart';
import 'package:drugtime_mobile/features/medication/data/repositories/in_memory_medication_repository.dart';
import 'package:drugtime_mobile/features/profile/presentation/screens/profile_screen.dart';
import 'package:drugtime_mobile/features/profile/presentation/screens/personal_profile_screen.dart';
import 'package:drugtime_mobile/features/profile/presentation/screens/medical_profile_screen.dart';
import 'package:drugtime_mobile/features/profile/presentation/state/profile_controller.dart';
import 'package:drugtime_mobile/app/theme/app_theme.dart';
import 'package:drugtime_mobile/features/profile/domain/entities/condition.dart';
import 'package:drugtime_mobile/features/profile/domain/entities/health_profile.dart';
import 'package:drugtime_mobile/features/profile/presentation/widgets/profile_avatar.dart';
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

  testWidgets('S08 opens in the shell with the selected floating navbar',
      (tester) async {
    const path = String.fromEnvironment('PROFILE_CAPTURE_DIR');
    if (path.isNotEmpty) {
      await tester.runAsync(() async {
        final bytes = await File('C:/Windows/Fonts/segoeui.ttf').readAsBytes();
        await (FontLoader('Roboto')
              ..addFont(Future.value(ByteData.sublistView(bytes))))
            .load();
        await (FontLoader('packages/lucide_icons_flutter/Lucide')
              ..addFont(rootBundle.load(
                'packages/lucide_icons_flutter/assets/lucide.ttf',
              )))
            .load();
      });
    }
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    const systemInsets = FakeViewPadding(top: 44, bottom: 24);
    tester.view.padding = systemInsets;
    tester.view.viewPadding = systemInsets;
    addTearDown(tester.view.reset);

    final auth = AuthController(InMemoryAuthRepository(
      simulatedDelay: Duration.zero,
      initialSession: AuthSession(
        userId: 's08-preview',
        accessToken: 'app-token',
        expiresAt: DateTime.now().add(const Duration(days: 1)),
        profileComplete: true,
      ),
    ));
    addTearDown(auth.dispose);
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: boundaryKey,
      child: DrugTimeApp(
        initialRoute: AppRoutes.home,
        initialTab: AppTab.profile,
        authController: auth,
        profileRepository: FakeProfileRepository(),
        medicationRepository: InMemoryMedicationRepository(),
      ),
    ));
    await tester.pumpAndSettle();

    final nav = find.byType(NavigationBar);
    expect(tester.widget<NavigationBar>(nav).selectedIndex, 3);
    expect(tester.getRect(nav), const Rect.fromLTWH(12, 712, 351, 68));
    expect(find.byKey(const ValueKey('selected-nav-Hồ sơ')), findsOneWidget);
    expect(tester.getTopLeft(find.byKey(const Key('profile-card'))),
        const Offset(20, 116));
    expect(find.text('Nguyễn Mai'), findsOneWidget);

    if (path.isNotEmpty) {
      await tester.runAsync(() async {
        final boundary = boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory(path).create(recursive: true);
        await File('$path/implement-profile-shell.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  });

  group('Figma metrics', () {
    void phoneView(WidgetTester tester, Size size) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    testWidgets('S08 card 88, menu row at least 72, icon tile 40, soft divider',
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
      expect(tester.getSize(row).height, greaterThanOrEqualTo(72));
      final tile = tester.getSize(
          find.descendant(of: row, matching: find.byType(Container)).first);
      expect(tile, const Size(AppSizes.iconTile, AppSizes.iconTile));
      expect(tester.widget<Divider>(find.byType(Divider).first).color,
          AppColors.dividerSoft);
    });

    Future<void> pumpS08(WidgetTester tester,
        {Size size = const Size(375, 812),
        double textScale = 1,
        FakeProfileRepository? repo}) async {
      phoneView(tester, size);
      final c = ProfileController(repo ?? FakeProfileRepository());
      addTearDown(c.dispose);
      await tester.pumpWidget(
          profileApp(c, const ProfileScreen(), textScale: textScale));
      await tester.pumpAndSettle();
    }

    TextStyle styleOf(WidgetTester tester, String text) =>
        tester.widget<Text>(find.text(text).first).style!;

    Finder cardAvatar() => find.descendant(
        of: find.byKey(const Key('profile-card')),
        matching: find.byType(ProfileAvatar));

    testWidgets('S08 card avatar is a solid 56 brand circle with 17/700 initials',
        (tester) async {
      await pumpS08(tester);
      expect(tester.getSize(cardAvatar()), const Size(56, 56));
      final circle = tester.widget<DecoratedBox>(find
          .descendant(of: cardAvatar(), matching: find.byType(DecoratedBox))
          .first);
      expect((circle.decoration as BoxDecoration).color, AppColors.brand);
      expect(
          tester.getSize(find
              .descendant(of: cardAvatar(), matching: find.byType(ClipOval))),
          const Size(56, 56));
      final initials = styleOf(tester, 'NM');
      expect(initials.fontSize, 17);
      expect(initials.fontWeight, FontWeight.w700);
      expect(initials.height, 26 / 17);
      expect(initials.color, AppColors.onBrand);
    });

    testWidgets('S08 name is 17/700, menu titles stay 17/600', (tester) async {
      await pumpS08(tester);
      final name = styleOf(tester, 'Nguyễn Mai');
      expect(name.fontSize, 17);
      expect(name.fontWeight, FontWeight.w700);
      expect(name.height, 24 / 17);
      expect(name.color, AppColors.ink);
      expect(styleOf(tester, 'Thông tin cá nhân').fontWeight, FontWeight.w600);
    });

    testWidgets('S08 settings icon is 24 inside the 48 tinted action',
        (tester) async {
      await pumpS08(tester);
      final icon = find.byWidgetPredicate(
          (w) => w is ProfileIcon && w.name == 'h-settings');
      expect(tester.getSize(icon), const Size(24, 24));
      expect(tester.widget<ProfileIcon>(icon).color, AppColors.brand);
      expect(
          tester.getSize(find.byTooltip('Cài đặt hồ sơ')), const Size(48, 48));
    });

    testWidgets('S08 menu icon strokes match Figma', (tester) async {
      await pumpS08(tester);
      const expected = {
        'personal-profile-tile': Color(0xFF20568F),
        'medical-profile-tile': Color(0xFFA12E50),
        'supervisors-tile': Color(0xFF624394),
        'share-and-link-tile': Color(0xFF624394),
        'notifications-tile': Color(0xFF8A4E0B),
        'privacy-settings-tile': Color(0xFF01554F),
        'profile-help-tile': Color(0xFF256749),
      };
      for (final entry in expected.entries) {
        final icon = tester.widget<ProfileIcon>(find
            .descendant(
                of: find.byKey(Key(entry.key)),
                matching: find.byType(ProfileIcon))
            .first);
        expect(icon.color, entry.value, reason: entry.key);
      }
    });

    testWidgets('S08 card and menu use their own Figma shadows',
        (tester) async {
      await pumpS08(tester);
      BoxDecoration deco(String key) =>
          tester.widget<Container>(find.byKey(Key(key))).decoration!
              as BoxDecoration;
      expect(deco('profile-card').boxShadow, const [
        BoxShadow(
            color: Color.fromRGBO(1, 85, 79, 0.0392157),
            offset: Offset(0, 1),
            blurRadius: 3),
        BoxShadow(
            color: Color.fromRGBO(1, 85, 79, 0.0784314),
            offset: Offset(0, 4),
            blurRadius: 12),
      ]);
      expect(deco('profile-menu').boxShadow, const [
        BoxShadow(
            color: Color.fromRGBO(33, 54, 49, 0.0313726),
            offset: Offset(0, 1),
            blurRadius: 3),
        BoxShadow(
            color: Color.fromRGBO(33, 54, 49, 0.0509804),
            offset: Offset(0, 3),
            blurRadius: 12),
      ]);
    });

    testWidgets('S08 title 28/34 and subtitles 14/20', (tester) async {
      await pumpS08(tester);
      final title = styleOf(tester, 'Hồ sơ');
      expect(title.fontSize, 28);
      expect(title.fontWeight, FontWeight.w700);
      expect(title.height, 34 / 28);
      for (final text in ['0912345678', 'Họ tên, ngày sinh, giới tính']) {
        final style = styleOf(tester, text);
        expect(style.fontSize, 14, reason: text);
        expect(style.fontWeight, FontWeight.w400, reason: text);
        expect(style.height, 20 / 14, reason: text);
        expect(style.color, AppColors.inkMuted, reason: text);
      }
    });

    for (final width in [320.0, 375.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('S08 nameless avatar shows ? at $width scale $scale',
            (tester) async {
          final repo = FakeProfileRepository()
            ..value = HealthProfile(
                fullName: null,
                dateOfBirth: DateTime(1960, 3, 1),
                gender: 'nu');
          await pumpS08(tester,
              size: Size(width, 812), textScale: scale, repo: repo);
          expect(tester.takeException(), isNull);
          expect(find.descendant(of: cardAvatar(), matching: find.text('?')),
              findsOneWidget);
          expect(styleOf(tester, '?').fontWeight, FontWeight.w700);
        });
      }
    }

    testWidgets('personal profile avatar keeps its tint ring', (tester) async {
      phoneView(tester, const Size(375, 812));
      final c = ProfileController(FakeProfileRepository());
      addTearDown(c.dispose);
      await tester.pumpWidget(profileApp(c, const PersonalProfileScreen()));
      await tester.pumpAndSettle();
      final avatar = find.byType(ProfileAvatar);
      final ring = tester.widget<DecoratedBox>(find
          .descendant(of: avatar, matching: find.byType(DecoratedBox))
          .first);
      expect((ring.decoration as BoxDecoration).color, AppColors.brandTint);
      expect(
          tester.getSize(
              find.descendant(of: avatar, matching: find.byType(ClipOval))),
          const Size(60, 60));
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
      expect(find.text('LIÊN HỆ'), findsNothing);
      expect(find.text('0912345678'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      expect(find.text('Nữ'), findsOneWidget);
    });

    testWidgets('S08-2 chip is a 48 high tinted tile with a check icon',
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
      expect(tester.getSize(chip).height, 48);
      final ink = tester.widget<Ink>(
          find.descendant(of: chip, matching: find.byType(Ink)).first);
      expect((ink.decoration! as BoxDecoration).color, AppColors.brandTint);
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

    testWidgets('unsupported Figma fields are explicit and cannot save',
        (tester) async {
      phoneView(tester, const Size(375, 812));
      final repo = FakeProfileRepository();
      final c = ProfileController(repo);
      addTearDown(c.dispose);
      await tester.pumpWidget(profileApp(c, const PersonalProfileScreen()));
      await tester.pumpAndSettle();
      expect(find.text('LIÊN HỆ'), findsNothing);
      expect(find.text('Chưa khả dụng'), findsWidgets);
      await tester.pumpWidget(profileApp(c, const MedicalProfileScreen()));
      await tester.pumpAndSettle();
      expect(
          find.textContaining('Khai báo dị ứng chưa khả dụng'), findsOneWidget);
      final save = find.widgetWithText(FilledButton, 'Lưu thay đổi');
      await tester.scrollUntilVisible(save, 300);
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
      expect(repo.writes, 0);
    });
  });
}
