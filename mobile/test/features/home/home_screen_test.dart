import 'dart:io';
import 'dart:ui' as ui;

import 'package:drugtime_mobile/app/theme/app_theme.dart';
import 'package:drugtime_mobile/core/utils/app_assets.dart';
import 'package:drugtime_mobile/features/home/presentation/widgets/home_navigation_bar.dart';
import 'package:drugtime_mobile/features/home/presentation/screens/home_screen.dart';
import 'package:drugtime_mobile/features/medication/data/repositories/in_memory_medication_repository.dart';
import 'package:drugtime_mobile/features/medication/presentation/state/medication_controller.dart';
import 'package:drugtime_mobile/app/router.dart';
import 'package:drugtime_mobile/features/profile/presentation/screens/health_profile_intro_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  _HomePreviewBinding();
  setUpAll(() async {
    final font = FontLoader('WelcomeInter');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      font.addFont(rootBundle.load('assets/fonts/Inter-$weight.ttf'));
    }
    await font.load();
  });
  for (final useSystemBack in [false, true]) {
    testWidgets(
        'Welcome setup opens S08a once and returns via '
        '${useSystemBack ? 'system back' : 'skip'}', (tester) async {
      final controller = MedicationController(
        InMemoryMedicationRepository(seed: []),
      );
      addTearDown(controller.dispose);
      final observer = _IntroRouteObserver();
      await controller.load();
      await tester.pumpWidget(
        MedicationScope(
          controller: controller,
          child: MaterialApp(
            onGenerateRoute: onGenerateRoute,
            navigatorObservers: [observer],
            home: Scaffold(
              body: HomeScreen(onFamily: () {}, onMedications: () {}),
            ),
          ),
        ),
      );
      final home = tester.element(find.byType(HomeScreen));
      await tester.tap(find.text('Bắt đầu nào!'));
      await tester.pumpAndSettle();
      final setup = find.text('Thiết lập hồ sơ sức khỏe');
      final setupPosition = tester.getCenter(setup);
      await tester.tap(setup);
      await tester.tapAt(setupPosition);
      await tester.pumpAndSettle();

      expect(observer.introReplacements, 1);
      expect(find.byType(HealthProfileIntroScreen), findsOneWidget);
      expect(find.text('Chào mừng đến với DrugTime!'), findsNothing);

      // The fixture has no profile or consent scope. This flow works without
      // accessing either controller.
      if (useSystemBack) {
        await tester.binding.handlePopRoute();
      } else {
        await tester.tap(find.text('Bỏ qua'));
      }
      await tester.pumpAndSettle();

      expect(tester.element(find.byType(HomeScreen)), same(home));
      expect(find.byType(HealthProfileIntroScreen), findsNothing);
      expect(find.text('Chào mừng đến với DrugTime!'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('Empty home waits for data and opens the welcome popup',
      (tester) async {
    final controller =
        MedicationController(InMemoryMedicationRepository(seed: []));
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(controller.dispose);
    const previewKey = ValueKey('home-preview');
    await tester.pumpWidget(RepaintBoundary(
      key: previewKey,
      child: MedicationScope(
        controller: controller,
        child: MaterialApp(
          theme: buildAppTheme(),
          debugShowCheckedModeBanner: false,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: const EdgeInsets.only(top: 44, bottom: 21),
            ),
            child: child!,
          ),
          home: Scaffold(
            extendBody: true,
            body: HomeScreen(
              displayName: 'Anh Bẻo',
              onFamily: () {},
              onMedications: () {},
            ),
            bottomNavigationBar: HomeNavigationBar(onSelected: (_) {}),
          ),
        ),
      ),
    ));
    final empty = find.text('Chưa có lịch uống thuốc');
    expect(empty, findsNothing);
    expect(find.text('Bắt đầu nào!'), findsNothing);
    await controller.load();
    await tester.pumpAndSettle();
    expect(empty, findsOneWidget);
    expect(tester.getTopLeft(find.text('Chào buổi sáng')).dy, closeTo(62, 0.1));
    expect(tester.getTopLeft(find.text('Anh Bẻo')).dy, closeTo(86, 0.1));
    expect(tester.getTopLeft(find.text('Bắt đầu nào!')).dy, closeTo(138, 0.1));
    expect(tester.getTopLeft(find.text('Dumi AI')).dy, closeTo(282, 0.1));
    final path = Platform.environment['HOME_POPUP_PREVIEW'];
    if (path != null) {
      final context = tester.element(find.byType(HomeScreen));
      await tester.runAsync(() async {
        await Future.wait([
          precacheImage(const AssetImage(AppAssets.mascotHappy), context),
          precacheImage(const AssetImage(AppAssets.mascotCooking), context),
        ]);
      });
    }

    final home = tester.element(find.byType(HomeScreen));
    await tester.tap(find.text('Bắt đầu nào!'));
    await tester.pumpAndSettle();
    expect(find.text('Chào mừng đến với DrugTime!'), findsOneWidget);
    expect(tester.element(find.byType(HomeScreen)), same(home));
    expect(empty, findsOneWidget);
    expect(find.byType(HomeNavigationBar), findsOneWidget);

    if (path != null) {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(previewKey),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        await File(path).writeAsBytes(bytes!.buffer.asUint8List());
      });
    }
    await tester.tap(find.text('Để sau'));
    await tester.pumpAndSettle();
    expect(empty, findsOneWidget);
  });

  testWidgets('Home navigation matches the iOS reference inset',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme().copyWith(platform: TargetPlatform.iOS),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          padding: const EdgeInsets.only(bottom: 34),
          viewPadding: const EdgeInsets.only(bottom: 34),
        ),
        child: child!,
      ),
      home: Scaffold(
        bottomNavigationBar: HomeNavigationBar(onSelected: (_) {}),
      ),
    ));
    final surface = find.descendant(
      of: find.byType(HomeNavigationBar),
      matching: find.byType(Material),
    );
    expect(tester.getRect(surface), const Rect.fromLTWH(16, 734, 343, 58));
  });
}

class _HomePreviewBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

class _IntroRouteObserver extends NavigatorObserver {
  int introReplacements = 0;

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute?.settings.name == AppRoutes.healthProfileIntro &&
        oldRoute is ModalBottomSheetRoute<bool>) {
      introReplacements++;
    }
  }
}
