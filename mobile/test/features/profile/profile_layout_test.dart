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

    final snackbar = tester.getRect(
        find.byKey(const Key('profile-save-success-snackbar')));
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
}
