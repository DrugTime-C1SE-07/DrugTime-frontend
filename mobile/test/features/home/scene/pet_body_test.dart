import 'dart:math' as math;

import 'package:drugtime_mobile/features/home/presentation/scene/pet_body.dart';
import 'package:drugtime_mobile/features/home/presentation/scene/scene_layout.dart';
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

void _run(PetBody b, double seconds, {void Function(PetBody)? each}) {
  for (var t = 0.0; t < seconds; t += 1 / 60) {
    b.step(1 / 60);
    each?.call(b);
  }
}

void _inBounds(PetBody b) {
  expect(_layout.allows(b.rect), isTrue, reason: 'pet ở ${b.feet}');
}

void main() {
  test('đi trên cỏ: bám mặt cỏ và tới đích', () {
    final b = PetBody(_layout, x: 330)..goTo(_layout.grass, 200);
    _run(b, 6, each: (b) {
      expect(b.feet.dy, closeTo(_layout.grassY(b.feet.dx), .01));
      _inBounds(b);
    });
    expect(b.feet.dx, closeTo(200, 1));
    expect(b.idle, isTrue);
    expect(b.facing, -1);
  });

  test('leo lên chip, đứng trên mặt chip, rồi nhảy xuống cỏ (AC9)', () {
    final b = PetBody(_layout, x: 330);
    final chip = _layout.surfaces[2];
    b.goTo(chip, 180);
    var climbed = false;
    _run(b, 12, each: (b) {
      if (b.motion == PetMotion.climbing) climbed = true;
      _inBounds(b);
    });
    expect(climbed, isTrue);
    expect(b.surface.chip, 1);
    expect(b.feet.dy, 238);
    expect(b.feet.dx, closeTo(180, 1));

    b.goTo(_layout.grass, 340);
    _run(b, 12, each: _inBounds);
    expect(b.surface.isGrass, isTrue);
    expect(b.feet.dx, closeTo(340, 1));
  });

  test('chuyển từ chip này sang chip kia', () {
    final b = PetBody(_layout, x: 330)..goTo(_layout.surfaces[2], 150);
    _run(b, 12);
    b.goTo(_layout.surfaces[1], 60);
    _run(b, 15, each: _inBounds);
    expect(b.surface.chip, 0);
  });

  test('kéo pet: bám ngón tay, không vào vùng chữ, không ra ngoài khung (AC23)',
      () {
    final b = PetBody(_layout, x: 300)..grab(const Offset(300, 270));
    b.dragTo(const Offset(100, 60), 1 / 60);
    _inBounds(b);
    b.dragTo(const Offset(-200, 999), 1 / 60);
    _inBounds(b);
    expect(b.motion, PetMotion.carried);
  });

  test('thả ở 50 điểm ngẫu nhiên đều đáp lên bề mặt hợp lệ (AC23)', () {
    final rnd = math.Random(7);
    for (var i = 0; i < 50; i++) {
      final b = PetBody(_layout, x: 300)..grab(b0(300));
      final p = Offset(rnd.nextDouble() * 375, 40 + rnd.nextDouble() * 260);
      b.dragTo(p, 1 / 60);
      b.release(
          Offset(rnd.nextDouble() * 800 - 400, rnd.nextDouble() * 600 - 300));
      _run(b, 4, each: _inBounds);
      expect(b.motion, PetMotion.standing, reason: 'thả tại $p');
      expect(b.feet.dy, closeTo(b.surface.y(b.feet.dx), .01));
      expect(b.surface.spans(b.feet.dx), isTrue);
    }
  });

  test('chip biến mất khi đang đứng trên đó thì pet rơi xuống cỏ', () {
    final b = PetBody(_layout, x: 330)..goTo(_layout.surfaces[1], 60);
    _run(b, 15);
    expect(b.surface.chip, 0);
    b.updateLayout(
        SceneLayout(size: _layout.size, top: 40, forbidden: _layout.forbidden));
    _run(b, 3);
    expect(b.surface.isGrass, isTrue);
    expect(b.motion, PetMotion.standing);
  });

  test('fits: chip quá cao chạm vùng chữ thì không đứng được', () {
    final tall = SceneLayout(
      size: const Size(375, 300),
      top: 40,
      chips: const [Rect.fromLTWH(30, 150, 90, 30)],
      forbidden: const [Rect.fromLTWH(20, 52, 230, 80)],
    );
    expect(PetBody(tall).fits(tall.surfaces[1]), isFalse);
    expect(PetBody(_layout).fits(_layout.surfaces[1]), isTrue);
  });
}

Offset b0(double x) => Offset(x, _layout.grassY(x) - 30);
