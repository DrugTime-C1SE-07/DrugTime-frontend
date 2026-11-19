import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:drugtime_mobile/shared/widgets/mascot/mascot_controller.dart';
import 'package:drugtime_mobile/shared/widgets/mascot/mascot_painter.dart';
import 'package:drugtime_mobile/shared/widgets/mascot/mascot_rig.dart';
import 'package:drugtime_mobile/shared/widgets/mascot/mascot_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('vẽ mọi trạng thái × trang phục không lỗi', () {
    final ctl = MascotController();
    for (final outfit in MascotOutfit.values) {
      for (final mood in MascotMood.values) {
        final rig = MascotRig(random: math.Random(2))
          ..outfit = outfit
          ..setMood(mood, ledge: 360);
        for (var i = 0; i < 40; i++) {
          rig.tick(1 / 30, ctl: ctl, still: false);
        }
        final recorder = ui.PictureRecorder();
        MascotPainter(rig, outfit: outfit)
            .paint(Canvas(recorder), const Size.square(220));
        expect(recorder.endRecording(), isNotNull,
            reason: '${outfit.name}/${mood.name}');
      }
    }
  });

  test('vẫy chào ngay từ trạng thái đầu: hết lượt vẫy linh vật vẫn hiện', () {
    final ctl = MascotController();
    final rig = MascotRig(random: math.Random(1))
      ..outfit = MascotOutfit.chef
      ..setMood(MascotMood.wave, ledge: 360);
    for (var t = 0.0; t < 3.5; t += 1 / 60) {
      rig.tick(1 / 60, ctl: ctl, still: false);
    }
    expect(rig.mood, isNot(MascotMood.hidden));
    expect(rig.value('pop'), greaterThan(.9));
  });

  testWidgets('đang nấu + giảm chuyển động: không còn yêu cầu khung hình',
      (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final ctl = MascotController()..play(MascotMood.cooking);
    await tester.pumpWidget(MaterialApp(
      home: Center(
        child:
            MascotView(controller: ctl, size: 160, outfit: MascotOutfit.chef),
      ),
    ));
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
