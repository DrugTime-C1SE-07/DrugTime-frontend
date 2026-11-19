import 'dart:io';
import 'dart:ui' as ui;

import 'package:drugtime_mobile/app/router.dart';
import 'package:drugtime_mobile/app/theme/app_theme.dart';
import 'package:drugtime_mobile/core/utils/app_assets.dart';
import 'package:drugtime_mobile/features/profile/presentation/screens/health_profile_intro_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _previewKey = ValueKey('health-profile-intro-preview');

Future<void> _openIntro(
  WidgetTester tester, {
  required Size size,
  double textScale = 1,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    RepaintBoundary(
      key: _previewKey,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        onGenerateRoute: (settings) => settings.name == AppRoutes.healthSetup
            ? MaterialPageRoute<bool>(
                settings: settings,
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Quay lại từ Dị ứng'),
                  ),
                ),
              )
            : onGenerateRoute(settings),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            padding: const EdgeInsets.only(top: 44, bottom: 34),
          ),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context)
                  .pushNamed<void>(AppRoutes.healthProfileIntro),
              child: const Text('Mở giới thiệu'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Mở giới thiệu'));
  await tester.pumpAndSettle();
}

void main() {
  _IntroPreviewBinding();
  final previewPath = Platform.environment['HEALTH_PROFILE_INTRO_PREVIEW'];
  setUpAll(() async {
    final loader = FontLoader('WelcomeInter');
    for (final weight in ['Regular', 'SemiBold', 'Bold']) {
      loader.addFont(rootBundle.load('assets/fonts/Inter-$weight.ttf'));
    }
    await loader.load();
    if (previewPath != null) {
      final materialIcons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await materialIcons.load();
    }
  });
  testWidgets('Intro shows the reference content and opens allergy setup', (
    tester,
  ) async {
    await _openIntro(tester, size: const Size(377, 814));
    expect(
      tester.getSize(find.text('Thiết lập hồ sơ sức khỏe')).height,
      lessThan(45),
    );
    final proceed = find.text('Tiếp tục đến dị ứng');
    expect(proceed.hitTestable(), findsOneWidget);
    expect(find.text('Dị ứng'), findsOneWidget);
    expect(find.text('Bệnh nền'), findsOneWidget);
    expect(find.text('Bạn có thể bổ sung hồ sơ sau.'), findsOneWidget);
    if (previewPath != null) {
      final context = tester.element(find.byType(HealthProfileIntroScreen));
      await tester.runAsync(
        () => precacheImage(const AssetImage(AppAssets.mascotProtect), context),
      );
      await tester.pumpAndSettle();
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(_previewKey),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        await File(previewPath).writeAsBytes(data!.buffer.asUint8List());
      });
    }

    await tester.tap(proceed);
    await tester.pumpAndSettle();
    expect(find.text('Quay lại từ Dị ứng'), findsOneWidget);
    await tester.tap(find.text('Quay lại từ Dị ứng'));
    await tester.pumpAndSettle();
    expect(find.byType(HealthProfileIntroScreen), findsOneWidget);
    expect(find.text('Mở giới thiệu'), findsNothing);
  });

  testWidgets('Intro actions remain reachable at 320 dp and 200% text', (
    tester,
  ) async {
    await _openIntro(tester, size: const Size(320, 640), textScale: 2);
    final skip = find.text('Bỏ qua');
    final proceed = find.text('Tiếp tục đến dị ứng');
    expect(skip.hitTestable(), findsOneWidget);
    await tester.ensureVisible(proceed);
    await tester.pumpAndSettle();
    expect(proceed.hitTestable(), findsOneWidget);
    await tester.tap(proceed);
    await tester.pumpAndSettle();
    expect(find.text('Quay lại từ Dị ứng'), findsOneWidget);
    await tester.tap(find.text('Quay lại từ Dị ứng'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(skip);
    await tester.pumpAndSettle();
    await tester.tap(skip);
    await tester.pumpAndSettle();
    expect(find.text('Mở giới thiệu'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _IntroPreviewBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}
