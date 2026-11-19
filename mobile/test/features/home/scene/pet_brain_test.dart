import 'dart:math' as math;

import 'package:drugtime_mobile/features/home/presentation/scene/home_pet_signals.dart';
import 'package:drugtime_mobile/features/home/presentation/scene/pet_body.dart';
import 'package:drugtime_mobile/features/home/presentation/scene/pet_brain.dart';
import 'package:drugtime_mobile/features/home/presentation/scene/scene_layout.dart';
import 'package:drugtime_mobile/features/home/presentation/scene/chibi_pet.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

final _layout = SceneLayout(
  size: const Size(375, 300),
  top: 40,
  chips: const [
    Rect.fromLTWH(20, 236, 90, 30),
    Rect.fromLTWH(118, 238, 130, 30),
  ],
  forbidden: const [
    Rect.fromLTWH(20, 52, 230, 80),
    Rect.fromLTWH(311, 48, 44, 44)
  ],
);

PetBrain _brain([int seed = 1]) =>
    PetBrain(PetBody(_layout, x: 300), random: math.Random(seed))
      ..skyPoint = const Offset(200, 90);

const _day = HomePetSignals(ictMinutes: 10 * 60);
const _night = HomePetSignals(ictMinutes: 23 * 60);

void _run(PetBrain b, double seconds, HomePetSignals s,
    {void Function(PetBrain)? each}) {
  for (var t = 0.0; t < seconds; t += 1 / 60) {
    b.tick(1 / 60, s);
    each?.call(b);
  }
}

/// Ngủ yên ở chỗ ngủ.
PetBrain _sleeping() {
  final b = _brain();
  _run(b, 12, _night);
  expect(b.asleep, isTrue);
  expect(b.mood, PetMood.sleepBlanket);
  return b;
}

void main() {
  setUp(() => PetBrain.onboardingShown = false);

  group('ngủ và thức (AC6, AC12)', () {
    test('22:00–05:29 không có liều: đi tới chỗ ngủ rồi đắp chăn ngủ', () {
      final b = _sleeping();
      expect(b.layer, PetLayer.sleep);
      expect(b.body.surface.isGrass, isTrue);
      expect(b.ctl.facing, 1);
    });

    test('05:30: thức dậy vươn vai rồi về hành vi rảnh', () {
      final b = _sleeping();
      _run(b, 1, const HomePetSignals(ictMinutes: 5 * 60 + 30));
      expect(b.mood, PetMood.stretch);
      _run(b, 3, const HomePetSignals(ictMinutes: 5 * 60 + 31));
      expect(b.mood, isNot(PetMood.stretch));
      expect(b.layer, isNot(PetLayer.sleep));
    });

    test('21:30–21:59 thỉnh thoảng ngáp', () {
      final b = _brain();
      _run(b, 30, const HomePetSignals(ictMinutes: 21 * 60 + 40));
      expect(b.played, contains(PetMood.yawn));
    });

    test('thiết bị UTC, 22:30 ICT → ngủ', () {
      final b = _brain();
      final s = HomePetSignals(
          ictMinutes:
              HomePetSignals.minutesOf(DateTime.utc(2026, 11, 17, 15, 30)));
      _run(b, 12, s);
      expect(b.asleep, isTrue);
    });
  });

  test(
      'giờ ngủ + liều trong cửa sổ: thức và nhắc; xác nhận xong thì ngủ lại (AC7)',
      () {
    final b = _sleeping();
    _run(b, 6, const HomePetSignals(ictMinutes: 23 * 60, inDoseWindow: true));
    expect(b.layer, PetLayer.remind);
    expect(b.asleep, isFalse);
    expect(b.prop, PetProp.clock);
    expect([PetMood.point, PetMood.hold], contains(b.mood));
    _run(b, 12, const HomePetSignals(ictMinutes: 23 * 60, confirmedSeq: 1));
    // ăn mừng xong vẫn phải quay về ngủ
    _run(b, 25, const HomePetSignals(ictMinutes: 23 * 60, confirmedSeq: 1));
    expect(b.asleep, isTrue);
  });

  group('sự kiện liều (AC8)', () {
    test('confirmedSeq tăng → ăn mừng đúng một lần, có confetti', () {
      final b = _brain();
      _run(b, 1, _day);
      expect(b.played, isNot(contains(PetMood.celebrate)));
      var confetti = false;
      _run(b, 3, const HomePetSignals(ictMinutes: 600, confirmedSeq: 1),
          each: (b) => confetti |= b.prop == PetProp.confetti);
      _run(b, 20, const HomePetSignals(ictMinutes: 600, confirmedSeq: 1));
      expect(b.played.where((m) => m == PetMood.celebrate).length, 1);
      expect(confetti, isTrue);
    });

    test('mở trang chủ khi seq đã khác 0 thì không ăn mừng', () {
      final b = _brain();
      _run(b, 5, const HomePetSignals(ictMinutes: 600, confirmedSeq: 4));
      expect(b.played, isNot(contains(PetMood.celebrate)));
    });

    test('ghi nhận thất bại → bối rối, không ăn mừng', () {
      final b = _brain();
      _run(b, 1, _day);
      _run(b, 2, const HomePetSignals(ictMinutes: 600, confirmFailedSeq: 1));
      expect(b.played, contains(PetMood.thinking));
      expect(b.played, isNot(contains(PetMood.celebrate)));
    });

    test('có liều bỏ lỡ: 120 s rảnh không ăn mừng, không nhào lộn, nhìn xuống',
        () {
      final b = _brain(3);
      _run(b, 120, const HomePetSignals(ictMinutes: 600, missedToday: true));
      expect(b.played, isNot(contains(PetMood.celebrate)));
      expect(b.played, isNot(contains(PetMood.flip)));
      expect(b.played, contains(PetMood.concerned));
      expect(b.ctl.gaze!.dy, greaterThan(.5));
    });
  });

  test(
      'rảnh 120 s seed cố định: luôn trong khung, không che chữ, có leo chip (AC9)',
      () {
    for (final seed in [1, 2, 3]) {
      final b = _brain(seed);
      var climbed = false;
      _run(b, 120, _day, each: (b) {
        expect(_layout.allows(b.body.rect), isTrue,
            reason: 'seed $seed ${b.body.feet}');
        if (b.body.onChip) climbed = true;
      });
      expect(climbed, isTrue, reason: 'seed $seed');
    }
  });

  group('trạng thái của ngày (AC20, AC21)', () {
    test('xong mọi liều: nằm thư giãn trên cỏ', () {
      final b = _brain();
      _run(b, 12, const HomePetSignals(ictMinutes: 600, allDone: true));
      expect(b.layer, PetLayer.allDone);
      expect(b.mood, PetMood.lie);
    });

    test('mốc chuỗi: cắm cờ', () {
      final b = _brain();
      _run(b, 1, _day);
      b.celebrateMilestone(7);
      var flag = false;
      _run(b, 3, _day, each: (b) => flag |= b.prop == PetProp.flag);
      expect(flag, isTrue);
    });

    test('lỗi tải → kính lúp; chờ đồng bộ → mây, không ăn mừng', () {
      final b = _brain();
      _run(b, 12, const HomePetSignals(ictMinutes: 600, failed: true));
      expect((b.layer, b.prop), (PetLayer.failed, PetProp.magnifier));
      _run(b, 12, const HomePetSignals(ictMinutes: 600, pending: true));
      expect((b.layer, b.prop), (PetLayer.pending, PetProp.cloud));
      expect(b.played, isNot(contains(PetMood.celebrate)));
    });

    test(
        'chưa có thuốc: lần đầu trong phiên chỉ vào "Thêm thuốc", lần sau không',
        () {
      final b = _brain();
      _run(b, 12, const HomePetSignals(ictMinutes: 600, empty: true));
      expect(b.played, contains(PetMood.point));
      // đứng ngay bên phải các chip (không che nút), quay sang trái chỉ về "Thêm thuốc"
      final chipsRight = _layout.chips.map((c) => c.right).reduce(math.max);
      expect(b.body.feet.dx, greaterThan(chipsRight));
      expect(b.body.feet.dx, lessThan(chipsRight + 80));
      expect(b.body.facing, -1);
      final again = _brain();
      _run(again, 12, const HomePetSignals(ictMinutes: 600, empty: true));
      expect(again.played, isNot(contains(PetMood.point)));
      expect(again.speech, isNotNull);
    });
  });

  group('cử chỉ khi ngủ (AC22)', () {
    test('gõ 1 lần: hé mắt rồi ngủ lại', () {
      final b = _sleeping()..tapPet();
      _run(b, .2, _night);
      expect(b.mood, PetMood.sleepPeek);
      _run(b, 2, _night);
      expect(b.mood, PetMood.sleepBlanket);
      expect(b.asleep, isTrue);
    });

    test('gõ 3 lần trong 2 s: cáu, trùm chăn; rồi ngủ lại', () {
      final b = _sleeping();
      for (var i = 0; i < 3; i++) {
        b.tapPet();
        _run(b, .3, _night);
      }
      expect(b.mood, PetMood.grumpy);
      _run(b, 4, _night);
      expect(b.mood, PetMood.sleepBlanket);
    });

    test('kéo chăn quá ngưỡng: run, rồi tự kéo chăn lại', () {
      final b = _sleeping()..dragBlanket(.7);
      _run(b, .2, _night);
      expect(b.mood, PetMood.shiver);
      expect(b.ctl.blanketOverride, closeTo(.3, .01));
      b.releaseBlanket();
      _run(b, 3, _night);
      expect(b.ctl.blanketOverride, isNull);
      expect(b.mood, PetMood.sleepBlanket);
    });

    test('kéo chăn chưa tới ngưỡng: chăn bật về, không run', () {
      final b = _sleeping()..dragBlanket(.3);
      _run(b, .2, _night);
      expect(b.mood, PetMood.sleepBlanket);
      b.releaseBlanket();
      _run(b, .4, _night);
      expect(b.ctl.blanketOverride, isNull);
      expect(b.played, isNot(contains(PetMood.shiver)));
    });

    test('kéo gối: ngóc dậy; thả: giật gối lại rồi ngủ tiếp', () {
      final b = _sleeping()..dragPillow(40);
      _run(b, .2, _night);
      expect(b.mood, PetMood.sleepPeek);
      expect(b.ctl.pillowShift, 40);
      b.releasePillow();
      _run(b, .3, _night);
      expect(b.mood, PetMood.grumpy);
      _run(b, 2, _night);
      expect(b.ctl.pillowShift, 0);
      expect(b.mood, PetMood.sleepBlanket);
    });

    test('xoa: hiện tim, vẫn ngủ; kéo pet đang ngủ không nhấc lên', () {
      final b = _sleeping()..rubPet();
      _run(b, .2, _night);
      expect(b.hearts, isTrue);
      expect(b.asleep, isTrue);
      expect(b.grabPet(b.body.feet), isFalse);
      expect(b.body.motion, isNot(PetMotion.carried));
      _run(b, 4, _night);
      expect(b.asleep, isTrue);
      expect(b.hearts, isFalse);
    });
  });

  group('cử chỉ khi thức (AC23)', () {
    test('chạm hai lần liền nhau không cùng phản ứng', () {
      final b = _brain();
      _run(b, 1, _day);
      for (var i = 0; i < 12; i++) {
        b.tapPet();
        _run(b, .1, _day);
        final first = b.mood;
        _run(b, 2, _day);
        b.tapPet();
        _run(b, .1, _day);
        expect(b.mood, isNot(first));
        _run(b, 2, _day);
      }
    });

    test('chạm đôi: nhào lộn; giữ: ôm và tim; xoa: cười nhột', () {
      final b = _brain();
      _run(b, 1, _day);
      b.doubleTapPet();
      _run(b, .1, _day);
      expect(b.mood, PetMood.flip);
      expect(b.spin, isNot(0));
      _run(b, 2, _day);
      b.longPressStart();
      _run(b, 3, _day);
      expect(b.mood, PetMood.hug);
      expect(b.hearts, isTrue);
      b.longPressEnd();
      _run(b, 1, _day);
      expect(b.mood, isNot(PetMood.hug));
      b.rubPet();
      _run(b, .1, _day);
      expect(b.mood, PetMood.tickle);
    });

    test('kéo rồi thả: carried → fall → đứng trên bề mặt hợp lệ', () {
      final b = _brain();
      _run(b, 1, _day);
      expect(b.grabPet(b.body.feet - const Offset(0, 30)), isTrue);
      b.dragPet(const Offset(150, 120), 1 / 60);
      _run(b, .1, _day);
      expect(b.mood, PetMood.carried);
      b.releasePet(const Offset(200, -100));
      _run(b, .05, _day);
      expect(b.mood, PetMood.fall);
      _run(b, 3, _day);
      expect(b.body.motion, isNot(PetMotion.falling));
      expect(_layout.allows(b.body.rect), isTrue);
    });
  });

  test('RubDetector: ≥ 3 lần đổi hướng trong 0,8 s', () {
    final r = RubDetector();
    expect(r.add(0, 10), isFalse);
    expect(r.add(.1, -10), isFalse);
    expect(r.add(.2, 10), isFalse);
    expect(r.add(.3, -10), isTrue);
    final slow = RubDetector();
    expect([
      slow.add(0, 10),
      slow.add(.5, -10),
      slow.add(1.0, 10),
      slow.add(1.5, -10)
    ], everyElement(isFalse));
  });

  group('còn liều: pet tự lên chip số liều (AC25)', () {
    const remaining = HomePetSignals(ictMinutes: 600, remaining: true);

    test(
        '90 s: lên chip ít nhất 2 lần, chỉ trỏ rồi giậm chân, cách nhau 20–30 s',
        () {
      for (final seed in [1, 4, 9]) {
        final b = _brain(seed);
        _run(b, 90, remaining, each: (b) {
          expect(_layout.allows(b.body.rect), isTrue);
        });
        expect(b.nagStarts.length, greaterThanOrEqualTo(2),
            reason: 'seed $seed');
        for (var i = 1; i < b.nagStarts.length; i++) {
          final gap = b.nagStarts[i] - b.nagStarts[i - 1];
          expect(gap, inInclusiveRange(20, 30.05),
              reason: 'seed $seed gap $gap');
        }
        final stomp = b.played.indexOf(PetMood.stomp);
        expect(stomp, greaterThan(0));
        expect(b.played.sublist(0, stomp), contains(PetMood.point));
        expect(b.layer, PetLayer.remaining);
      }
    });

    test('có liều bỏ lỡ hoặc đã đủ liều thì không giậm chân', () {
      final missed = _brain();
      _run(
          missed,
          60,
          const HomePetSignals(
              ictMinutes: 600, remaining: true, missedToday: true));
      expect(missed.played, isNot(contains(PetMood.stomp)));
      expect(missed.layer, PetLayer.missed);
      final done = _brain();
      _run(done, 60, const HomePetSignals(ictMinutes: 600, allDone: true));
      expect(done.played, isNot(contains(PetMood.stomp)));
    });

    test('liều trong cửa sổ thắng tầng còn liều; ban đêm thì ngủ', () {
      final b = _brain();
      _run(
          b,
          30,
          const HomePetSignals(
              ictMinutes: 600, remaining: true, inDoseWindow: true));
      expect(b.layer, PetLayer.remind);
      expect(b.played, isNot(contains(PetMood.stomp)));
      final night = _brain();
      _run(night, 40,
          const HomePetSignals(ictMinutes: 23 * 60, remaining: true));
      expect(night.asleep, isTrue);
      expect(night.played, isNot(contains(PetMood.stomp)));
    });
  });

  test('dừng lại trên cỏ thì không đứng trước chip hay nút (không che chữ)',
      () {
    bool inFrontOfChip(PetBrain b) =>
        b.body.idle &&
        b.body.surface.isGrass &&
        _layout.chips.any((c) =>
            b.body.feet.dx > c.left - _layout.petHalfWidth &&
            b.body.feet.dx < c.right + _layout.petHalfWidth);
    for (final s in const [
      HomePetSignals(ictMinutes: 600),
      HomePetSignals(ictMinutes: 600, failed: true),
      HomePetSignals(ictMinutes: 600, allDone: true),
    ]) {
      PetBrain.onboardingShown = false;
      final b = _brain(5);
      _run(b, 60, s, each: (b) {
        expect(inFrontOfChip(b), isFalse, reason: '${b.layer} ${b.body.feet}');
      });
    }
  });

  test(
      'chưa có thuốc: pet đứng sát đầu phải của nút, quay về nút, có lời thoại',
      () {
    final b = _brain();
    _run(b, 15, const HomePetSignals(ictMinutes: 600, empty: true));
    final right = _layout.chips.map((c) => c.right).reduce(math.max);
    expect(b.body.idle, isTrue);
    expect(b.body.rect.left, closeTo(right, 6));
    expect(b.body.facing, -1);
    expect(b.speech, isNotNull);
    expect(b.layer, PetLayer.onboarding);
    // sau lần chỉ đầu tiên: vẫy tay về phía nút theo nhịp 3,2 s, không chỉ tay lặp lại
    var waved = 0, pointed = 0;
    _run(b, 6.4, const HomePetSignals(ictMinutes: 600, empty: true), each: (b) {
      waved += b.mood == PetMood.wave ? 1 : 0;
      pointed += b.mood == PetMood.point ? 1 : 0;
    });
    expect(waved, greaterThan(0));
    expect(pointed, 0);
    // rời trạng thái chưa có thuốc thì hết lời thoại
    _run(b, 1, const HomePetSignals(ictMinutes: 600));
    expect(b.speech, isNull);
  });
}
