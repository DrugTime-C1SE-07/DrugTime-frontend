import 'dart:math' as math;

import 'package:drugtime_mobile/shared/widgets/mascot/mascot_controller.dart';
import 'package:drugtime_mobile/shared/widgets/mascot/mascot_rig.dart';
import 'package:flutter_test/flutter_test.dart';

/// Chạy rig [seconds] giây với bước 1/60 s.
void run(MascotRig rig, MascotController ctl, double seconds,
    {bool still = false}) {
  for (var t = 0.0; t < seconds; t += 1 / 60) {
    rig.tick(1 / 60, ctl: ctl, still: still);
  }
}

void main() {
  group('MascotController', () {
    test('lookAt kẹp trong -1..1 và tăng gazeStamp', () {
      final ctl = MascotController();
      ctl.lookAt(const Offset(3, -2));
      expect(ctl.gaze, const Offset(1, -1));
      expect(ctl.gazeStamp, 1);
      ctl.lookAt(const Offset(.2, .3));
      expect(ctl.gazeStamp, 2);
    });

    test('play tăng seq kể cả khi phát lại cùng trạng thái', () {
      final ctl = MascotController()..play(MascotMood.poke);
      final first = ctl.seq;
      ctl.play(MascotMood.poke);
      expect(ctl.seq, first + 1);
      expect(ctl.mood, MascotMood.poke);
    });

    test('clearLook xóa hướng nhìn và báo listener', () {
      final ctl = MascotController()..lookAt(const Offset(.5, .5));
      var notified = 0;
      ctl.addListener(() => notified++);
      ctl.clearLook();
      expect(ctl.gaze, isNull);
      expect(notified, 1);
    });
  });

  group('MascotRig', () {
    late MascotController ctl;
    late MascotRig rig;
    setUp(() {
      ctl = MascotController();
      rig = MascotRig(random: math.Random(1));
    });

    test('lò xo hội tụ về tư thế đứng chờ', () {
      rig.setMood(MascotMood.idle, ledge: ctl.ledge);
      run(rig, ctl, 3);
      expect(rig.value('pop'), closeTo(1, .02));
      expect(rig.value('y').abs(), lessThan(4));
    });

    test('climb → wave → idle trong ≤ 5,7 s, kết thúc đứng trên mây', () {
      rig.setMood(MascotMood.climb, ledge: 360);
      run(rig, ctl, .1);
      expect(rig.mood, MascotMood.climb);
      // đầu cảnh leo: thân ẩn dưới mép form (đỉnh đầu 56 + y ≥ mép)
      expect(56 + rig.value('y'), greaterThanOrEqualTo(360 - 1));
      run(rig, ctl, 3.0);
      expect(rig.mood, MascotMood.wave);
      run(rig, ctl, 2.6);
      expect(rig.mood, MascotMood.idle);
      expect(rig.value('y').abs(), lessThan(4));
      expect(rig.value('hw'), closeTo(0, .05));
    });

    test('poke xong quay về trạng thái trước đó', () {
      rig.setMood(MascotMood.concerned, ledge: ctl.ledge);
      run(rig, ctl, .5);
      rig.setMood(MascotMood.poke, ledge: ctl.ledge);
      run(rig, ctl, 1.1);
      expect(rig.mood, MascotMood.concerned);
    });

    test(
        'giảm chuyển động: snap về đích, không chớp, trạng thái chuyển tiếp hiển thị như idle',
        () {
      rig.setMood(MascotMood.climb, ledge: 360, still: true);
      expect(rig.mood, MascotMood.idle);
      rig.tick(1 / 60, ctl: ctl, still: true);
      expect(rig.value('pop'), 1);
      expect(rig.value('y'), 0);
      expect(rig.blink, 1);
      final time = rig.time;
      run(rig, ctl, 1, still: true);
      expect(rig.time, time);
    });

    test('cover: mắt nhắm, peek kéo tay phải xuống', () {
      rig.setMood(MascotMood.cover, ledge: ctl.ledge);
      run(rig, ctl, 1);
      final handDown = rig.value('hry');
      ctl.setPeek(true);
      run(rig, ctl, 1);
      expect(rig.peek, isTrue);
      expect(rig.value('hry'), greaterThan(handDown + 10));
      expect(rig.value('open'), closeTo(0, .05));
    });

    test('nhìn theo gaze của controller khi đứng chờ', () {
      rig.setMood(MascotMood.idle, ledge: ctl.ledge);
      ctl.lookAt(const Offset(.9, .9));
      run(rig, ctl, .5);
      expect(rig.value('lx'), greaterThan(.5));
      expect(rig.value('ly'), greaterThan(.5));
    });
  });
}
