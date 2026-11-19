import 'dart:math' as math;

import 'package:drugtime_mobile/shared/widgets/mascot/mascot_controller.dart';
import 'package:drugtime_mobile/shared/widgets/mascot/mascot_rig.dart';
import 'package:drugtime_mobile/shared/widgets/mascot/mascot_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cradle: hands meet in front of the belly and a heart shows (AC21)', () {
    final ctl = MascotController();
    final rig = MascotRig(random: math.Random(3))
      ..outfit = MascotOutfit.medic
      ..setMood(MascotMood.cradle, ledge: 360);
    for (var t = 0.0; t < 1.5; t += 1 / 60) {
      rig.tick(1 / 60, ctl: ctl, still: false);
    }
    expect(rig.value('heart'), greaterThan(.8));
    expect((rig.value('hrx') - rig.value('hlx')).abs(), lessThan(60));
    rig.setMood(MascotMood.idle, ledge: 360);
    for (var t = 0.0; t < 1.5; t += 1 / 60) {
      rig.tick(1 / 60, ctl: ctl, still: false);
    }
    expect(rig.value('heart'), lessThan(.1));
  });

  testWidgets(
      'medic outfit idles, and stops asking for frames with reduce motion (AC20, AC22)',
      (tester) async {
    final ctl = MascotController()..play(MascotMood.wave);
    await tester.pumpWidget(MaterialApp(
      home: Center(
          child: MascotView(
              controller: ctl, size: 160, outfit: MascotOutfit.medic)),
    ));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.hasRunningAnimations, isTrue);

    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(MaterialApp(
      home: Center(
          child: MascotView(
              key: const Key('still'),
              controller: ctl..play(MascotMood.cradle),
              size: 160,
              outfit: MascotOutfit.medic)),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.hasRunningAnimations, isFalse);
    expect(tester.takeException(), isNull);
  });
}
