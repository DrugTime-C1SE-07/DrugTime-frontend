import 'dart:math' as math;

import 'package:drugtime_mobile/features/home/presentation/scene/chibi_pet.dart';
import 'package:flutter_test/flutter_test.dart';

void _run(ChibiRig rig, PetController ctl, double seconds,
    {void Function()? each}) {
  for (var t = 0.0; t < seconds; t += 1 / 60) {
    rig.tick(1 / 60, ctl: ctl);
    each?.call();
  }
}

ChibiRig _rig(PetMood mood, PetController ctl, [int seed = 1]) =>
    ChibiRig(random: math.Random(seed))..setMood(mood);

void main() {
  test('mọi trạng thái chạy 3 s ổn định, không NaN (AC27)', () {
    for (final mood in PetMood.values) {
      final ctl = PetController();
      final rig = _rig(mood, ctl);
      _run(rig, ctl, 3);
      for (final key in [
        'pop',
        'y',
        'sq',
        'tilt',
        'lie',
        'blanket',
        'eye',
        'armL',
        'armR',
        'footL',
        'footR'
      ]) {
        final v = rig.value(key);
        expect(v.isFinite, isTrue, reason: '$mood.$key');
        expect(v.abs(), lessThan(50), reason: '$mood.$key');
      }
    }
  });

  test('đi kiểu nảy: có lúc chạm đất và lúc bay lên', () {
    final ctl = PetController();
    final rig = _rig(PetMood.walk, ctl);
    var low = 0.0, high = -99.0;
    _run(rig, ctl, 1, each: () {
      low = math.min(low, rig.value('y'));
      high = math.max(high, rig.value('y'));
    });
    expect(low, lessThan(-4));
    expect(high, greaterThan(-1.5));
  });

  test('ngủ có chăn: nằm, chăn phủ, mắt nhắm, có zzz (AC6)', () {
    final ctl = PetController();
    final rig = _rig(PetMood.sleepBlanket, ctl);
    _run(rig, ctl, 3);
    expect(rig.value('lie'), closeTo(1, .03));
    expect(rig.value('blanket'), closeTo(1, .05));
    expect(rig.value('eye'), lessThan(.1));
    expect(rig.value('zzz'), closeTo(1, .05));
  });

  test('kéo chăn ghi đè tư thế khi đang nằm; cáu thì trùm đầu (AC22)', () {
    final ctl = PetController()..blanketOverride = .2;
    final rig = _rig(PetMood.sleepBlanket, ctl);
    _run(rig, ctl, 3);
    expect(rig.value('blanket'), closeTo(.2, .05));
    ctl.blanketOverride = null;
    rig.setMood(PetMood.grumpy);
    _run(rig, ctl, 3);
    expect(rig.value('blanket'), greaterThan(1.2));
  });

  test('giậm chân: hai chân thay nhau nhấc, má phồng', () {
    final ctl = PetController();
    final rig = _rig(PetMood.stomp, ctl);
    var l = 0.0, r = 0.0;
    _run(rig, ctl, 2, each: () {
      l = math.max(l, rig.value('footL'));
      r = math.max(r, rig.value('footR'));
    });
    expect(l, greaterThan(3));
    expect(r, greaterThan(3));
    expect(rig.value('puff'), greaterThan(.9));
  });

  test('đứng yên vẫn thở và chớp mắt; hướng mặt theo controller', () {
    final ctl = PetController()..facing = -1;
    final rig = _rig(PetMood.idle, ctl);
    var blinked = false;
    final ys = <double>{};
    _run(rig, ctl, 6, each: () {
      if (rig.blink < .5) blinked = true;
      ys.add((rig.value('y') * 10).roundToDouble());
    });
    expect(blinked, isTrue);
    expect(ys.length, greaterThan(3));
    expect(rig.value('face'), closeTo(-1, .05));
  });
}
