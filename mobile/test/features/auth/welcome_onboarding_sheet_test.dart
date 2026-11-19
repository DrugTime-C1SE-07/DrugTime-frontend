import 'dart:io';
import 'dart:ui' as ui;

import 'package:drugtime_mobile/app/theme/app_theme.dart';
import 'package:drugtime_mobile/features/auth/presentation/widgets/welcome_onboarding_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

const _sheet = Key('welcome-sheet');
const _handle = Key('welcome-drag-handle');
const _setup = Key('welcome-setup');
const _later = Key('welcome-later');
const _host = Key('welcome-test-host');
const _open = Key('welcome-test-open');

Future<void> _openSheet(
  WidgetTester tester, {
  Size size = const Size(375, 812),
  double textScale = 1,
  bool disableAnimations = false,
  bool settle = true,
  required VoidCallback onSetup,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    RepaintBoundary(
      key: _host,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: disableAnimations,
            padding: const EdgeInsets.only(bottom: 34),
            viewPadding: const EdgeInsets.only(bottom: 34),
          ),
          child: child!,
        ),
        home: Scaffold(
          backgroundColor: const Color(0xFFF7F8F6),
          body: Builder(
            builder: (context) => Align(
              alignment: Alignment.bottomCenter,
              child: TextButton(
                key: _open,
                onPressed: () =>
                    showWelcomeOnboardingSheet(context, onSetup: onSetup),
                child: const Text('Mở popup'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(_open));
  if (settle) await tester.pumpAndSettle();
}

void main() {
  _WelcomeTestBinding();
  setUpAll(() async {
    final fonts = FontLoader('WelcomeInter');
    for (final style in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      fonts.addFont(rootBundle.load('assets/fonts/Inter-$style.ttf'));
    }
    await fonts.load();
  });

  testWidgets('matches_figma_geometry_on_reference_viewport', (tester) async {
    await _openSheet(tester, onSetup: () {});
    expect(tester.getRect(find.byKey(_sheet)),
        const Rect.fromLTWH(0, 332, 375, 480));
    final surface = tester.widget<Material>(
      find
          .ancestor(of: find.byKey(_sheet), matching: find.byType(Material))
          .first,
    );
    expect(
      surface.borderRadius,
      const BorderRadius.vertical(top: Radius.circular(24)),
    );
    expect(tester.getRect(find.byKey(_handle)),
        const Rect.fromLTWH(169.5, 346, 36, 4));
    expect(
      tester.getRect(find.byKey(const Key('welcome-mascot'))),
      const Rect.fromLTWH(149.5, 368, 76, 70),
    );
    expect(tester.getRect(find.byKey(_setup)),
        const Rect.fromLTWH(20, 670, 335, 56));
    expect(tester.getRect(find.byKey(_later)),
        const Rect.fromLTWH(20, 734, 335, 48));
    const featureKeys = ['bell', 'alert-triangle', 'users'];
    for (var index = 0; index < featureKeys.length; index++) {
      final row = find.byKey(ValueKey('welcome-feature-${featureKeys[index]}'));
      final y = 490.0 + 56 * index;
      expect(tester.getRect(row), Rect.fromLTWH(24, y, 327, 42));
      final icon = find.descendant(of: row, matching: find.byType(SvgPicture));
      expect(tester.getRect(icon), Rect.fromLTWH(34, y + 11, 20, 20));
    }
    expect(
      tester.widgetList<ModalBarrier>(find.byType(ModalBarrier)).any(
            (barrier) => barrier.color == const Color(0x800B1F1C),
          ),
      isTrue,
    );
    final path = Platform.environment['WELCOME_POPUP_PREVIEW'];
    if (path != null) {
      await tester.runAsync(() async {
        await precacheImage(
          const AssetImage('assets/icons/mascot-happy.png'),
          tester.element(find.byKey(const Key('welcome-mascot'))),
        );
        for (final icon in featureKeys) {
          final picture = await vg.loadPicture(
            SvgAssetLoader('assets/icons/welcome/$icon.svg'),
            null,
          );
          picture.picture.dispose();
        }
      });
      await tester.pumpAndSettle();
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(_host),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        await File(path).writeAsBytes(png!.buffer.asUint8List());
      });
    }
  });

  testWidgets('reduced_motion_opens_and_closes_without_sliding',
      (tester) async {
    await _openSheet(
      tester,
      disableAnimations: true,
      settle: false,
      onSetup: () {},
    );
    await tester.pump();
    expect(tester.getTopLeft(find.byKey(_sheet)).dy, 332);

    await tester.tap(find.byKey(_later));
    await tester.pump();
    expect(find.byKey(_sheet), findsNothing);
  });

  testWidgets('setup_closes_sheet_and_invokes_callback_once', (tester) async {
    var calls = 0;
    await _openSheet(tester, onSetup: () => calls++);
    await tester.tap(find.byKey(_setup));
    await tester.tap(find.byKey(_setup), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.byKey(_sheet), findsNothing);
    expect(find.byKey(_open), findsOneWidget);
  });

  testWidgets('later_and_drag_dismiss_without_setup', (tester) async {
    var calls = 0;
    await _openSheet(tester, onSetup: () => calls++);
    await tester.tap(find.byKey(_later));
    await tester.pumpAndSettle();
    expect(find.byKey(_sheet), findsNothing);
    await tester.tap(find.byKey(_open));
    await tester.pumpAndSettle();
    await tester.fling(find.byKey(_handle), const Offset(0, 360), 900);
    await tester.pumpAndSettle();
    expect(find.byKey(_sheet), findsNothing);
    expect(find.byKey(_open), findsOneWidget);
    expect(calls, 0);
  });

  testWidgets('dragging back up interrupts a closing sheet', (tester) async {
    await _openSheet(tester, onSetup: () {});
    await tester.fling(find.byKey(_handle), const Offset(0, 120), 900);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    final closingTop = tester.getTopLeft(find.byKey(_sheet)).dy;
    expect(closingTop, greaterThan(332));

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(_handle)),
    );
    await gesture.moveBy(const Offset(0, -120));
    await tester.pump();
    expect(tester.getTopLeft(find.byKey(_sheet)).dy, lessThan(closingTop));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byKey(_sheet), findsOneWidget);
    expect(tester.getTopLeft(find.byKey(_sheet)).dy, 332);
  });

  testWidgets('short drag settles open and system back dismisses',
      (tester) async {
    await _openSheet(tester, onSetup: () {});
    await tester.drag(find.byKey(_handle), const Offset(0, 60));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byKey(_sheet)).dy, 332);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(_sheet), findsNothing);
  });

  testWidgets('narrow_and_scaled_viewports_keep_actions_reachable',
      (tester) async {
    await _openSheet(
      tester,
      size: const Size(320, 568),
      textScale: 2,
      onSetup: () {},
    );
    for (final key in [_setup, _later]) {
      await tester.ensureVisible(find.byKey(key));
      await tester.pumpAndSettle();
      expect(find.byKey(key).hitTestable(), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });
}

class _WelcomeTestBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}
