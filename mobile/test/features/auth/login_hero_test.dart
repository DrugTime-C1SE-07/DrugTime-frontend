import 'dart:ui' as ui;

import 'package:drugtime_mobile/core/utils/app_assets.dart';
import 'package:drugtime_mobile/features/auth/presentation/screens/login_mobile_screen.dart';
import 'package:drugtime_mobile/features/auth/presentation/widgets/login_hero.dart';
import 'package:drugtime_mobile/features/auth/presentation/widgets/pill_sky_scene.dart';
import 'package:drugtime_mobile/shared/widgets/mascot/mascot_controller.dart';
import 'package:drugtime_mobile/shared/widgets/mascot/mascot_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Task adhoc-20261115-pill-mascot-redesign: phần đầu màn đăng nhập.
void main() {
  void setScreen(WidgetTester tester, Size size) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
  }

  void reduceMotion(WidgetTester tester) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }

  MascotController mascot(WidgetTester tester) => tester
      .widget<MascotView>(find.byType(MascotView, skipOffstage: false))
      .controller;

  /// Linh vật chạy liên tục nên không dùng pumpAndSettle khi có animation.
  Future<void> pumpFor(WidgetTester tester, Duration total) async {
    const step = Duration(milliseconds: 16);
    for (var t = Duration.zero; t < total; t += step) {
      await tester.pump(step);
    }
  }

  Finder asset(String path) => find.byWidgetPredicate((w) =>
      w is Image &&
      w.image is AssetImage &&
      (w.image as AssetImage).assetName == path);

  test('AC1: nền vẽ được ở đầu, giữa và cuối hiệu ứng vào màn', () {
    for (final e in [0.0, .5, 1.0]) {
      final painter = PillSkyScenePainter(
        entrance: AlwaysStoppedAnimation(e),
        time: ValueNotifier(3),
        kick: ValueNotifier(2),
      );
      final recorder = ui.PictureRecorder();
      painter.paint(Canvas(recorder), const Size(390, 380));
      expect(recorder.endRecording(), isNotNull);
    }
  });

  testWidgets('AC1, AC12: phần đầu mới thay cho header teal + PNG',
      (tester) async {
    setScreen(tester, const Size(390, 844));
    reduceMotion(tester);
    await tester.pumpWidget(const MaterialApp(home: LoginMobileScreen()));
    await tester.pumpAndSettle();

    expect(find.byType(LoginHero), findsOneWidget);
    expect(find.byType(MascotView), findsOneWidget);
    expect(
        find.byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is PillSkyScenePainter),
        findsOneWidget);
    expect(asset('assets/icons/login-mascot-figma.png'), findsNothing);
    final wordmark = find.byKey(const Key('login-wordmark'));
    expect(asset(AppAssets.logoWordmark), findsOneWidget);
    expect(tester.getSize(wordmark).width, lessThanOrEqualTo(190));
  });

  testWidgets('AC12: chữ logo không bị cắt trên màn 360x640, chữ ×1.5',
      (tester) async {
    setScreen(tester, const Size(360, 640));
    reduceMotion(tester);
    await tester.pumpWidget(MaterialApp(
      // giữ cờ giảm chuyển động của nền tảng, chỉ phóng to chữ
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(1.5)),
        child: child!,
      ),
      home: const LoginMobileScreen(),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final rect = tester.getRect(find.byKey(const Key('login-wordmark')));
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(360));
    expect(rect.top, greaterThanOrEqualTo(0));
  });

  testWidgets('nút Nhận mã OTP bám đáy sheet, không để trống phía dưới',
      (tester) async {
    setScreen(tester, const Size(390, 844));
    reduceMotion(tester);
    await tester.pumpWidget(const MaterialApp(home: LoginMobileScreen()));
    await tester.pumpAndSettle();
    final sheet = tester.getRect(find.byKey(const Key('login-sheet')));
    final button =
        tester.getRect(find.widgetWithText(FilledButton, 'Nhận mã OTP'));
    // padding đáy sheet là 30
    expect(sheet.bottom - button.bottom, closeTo(30, 1));
  });

  testWidgets(
      'AC2: sau hiệu ứng vào màn, sheet ở vị trí cuối và linh vật đứng chờ',
      (tester) async {
    setScreen(tester, const Size(390, 844));
    await tester.pumpWidget(const MaterialApp(home: LoginMobileScreen()));
    final hero = tester.getRect(find.byType(LoginHero));

    await pumpFor(tester, const Duration(milliseconds: 1200));
    // linh vật chưa xuất hiện khi sheet chưa lên xong
    expect(mascot(tester).mood, MascotMood.hidden);

    await pumpFor(tester, const Duration(seconds: 4));
    final sheet = tester.getRect(find.byKey(const Key('login-sheet')));
    expect(sheet.top, closeTo(hero.bottom, .5));
    expect(sheet.bottom, closeTo(844, .5));
    // climb (3,05 s) → wave (2,6 s) → idle; controller chỉ ghi lệnh climb
    expect(mascot(tester).mood, MascotMood.climb);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'AC3: giảm chuyển động → hiện ngay vị trí cuối, không còn khung hình',
      (tester) async {
    setScreen(tester, const Size(390, 844));
    reduceMotion(tester);
    await tester.pumpWidget(const MaterialApp(home: LoginMobileScreen()));
    await tester.pump();
    await tester.pump();

    final hero = tester.getRect(find.byType(LoginHero));
    final sheet = tester.getRect(find.byKey(const Key('login-sheet')));
    expect(sheet.top, closeTo(hero.bottom, .5));
    expect(mascot(tester).mood, MascotMood.idle);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets(
      'AC4: gõ email → linh vật nhìn sang phải theo con trỏ; bỏ focus → thôi nhìn',
      (tester) async {
    setScreen(tester, const Size(390, 844));
    reduceMotion(tester);
    await tester.pumpWidget(const MaterialApp(home: LoginMobileScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Email').first);
    await tester.pumpAndSettle();

    final field = find.byType(TextField);
    await tester.tap(field);
    await tester.pump();
    final start = mascot(tester).gaze!;
    await tester.enterText(field, 'nguyenvanan.rat.dai@example.com');
    await tester.pump();
    expect(mascot(tester).gaze!.dx, greaterThan(start.dx));
    expect(mascot(tester).gaze!.dy, greaterThan(0),
        reason: 'ô nhập nằm dưới mắt');

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    expect(mascot(tester).gaze, isNull);
  });

  testWidgets('AC9: sang màn khác thì ticker của phần đầu và linh vật dừng',
      (tester) async {
    setScreen(tester, const Size(390, 844));
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
        MaterialApp(navigatorKey: nav, home: const LoginMobileScreen()));
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(tester.binding.hasScheduledFrame, isTrue);

    nav.currentState!
        .push(MaterialPageRoute<void>(builder: (_) => const Scaffold()));
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(const SizedBox());
  });
}
