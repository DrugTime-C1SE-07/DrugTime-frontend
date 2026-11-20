import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:drugtime_mobile/shared/widgets/mascot/mascot_controller.dart';
import 'package:drugtime_mobile/shared/widgets/mascot/mascot_painter.dart';
import 'package:drugtime_mobile/shared/widgets/mascot/mascot_rig.dart';
import 'package:drugtime_mobile/shared/widgets/mascot/mascot_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(MascotController ctl) => MaterialApp(
      home: Center(
          child:
              MascotView(controller: ctl, size: 200, random: math.Random(3))),
    );

void main() {
  testWidgets('pause app suspends joint animation until resume',
      (tester) async {
    final ctl = MascotController()..play(MascotMood.farewell);
    await tester.pumpWidget(_host(ctl));
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.binding.hasScheduledFrame, isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpWidget(const SizedBox());
  });
  test('vẽ mọi trạng thái không lỗi', () {
    final ctl = MascotController();
    for (final mood in MascotMood.values) {
      final rig = MascotRig(random: math.Random(2))..setMood(mood, ledge: 360);
      for (var i = 0; i < 40; i++) {
        rig.tick(1 / 30, ctl: ctl, still: false);
      }
      final recorder = ui.PictureRecorder();
      MascotPainter(rig).paint(Canvas(recorder), const Size.square(220));
      expect(recorder.endRecording(), isNotNull, reason: mood.name);
    }
  });

  testWidgets('giảm chuyển động: không còn yêu cầu khung hình sau khi dựng',
      (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final ctl = MascotController()..play(MascotMood.climb);
    await tester.pumpWidget(_host(ctl));
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
    ctl.play(MascotMood.concerned);
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('chạm vào linh vật → trạng thái bị chạm', (tester) async {
    final ctl = MascotController()..play(MascotMood.idle);
    await tester.pumpWidget(_host(ctl));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byType(MascotView));
    expect(ctl.mood, MascotMood.poke);
    expect(find.bySemanticsLabel('Linh vật DrugTime'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('route bị che thì ticker dừng (TickerMode)', (tester) async {
    final ctl = MascotController()..play(MascotMood.idle);
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: nav,
      home: Center(child: MascotView(controller: ctl, size: 200)),
    ));
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.binding.hasScheduledFrame, isTrue);
    nav.currentState!
        .push(MaterialPageRoute<void>(builder: (_) => const Scaffold()));
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(const SizedBox());
  });
}
