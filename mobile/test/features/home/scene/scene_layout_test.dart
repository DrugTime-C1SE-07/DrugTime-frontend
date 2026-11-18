import 'package:drugtime_mobile/features/home/presentation/scene/astronomy.dart';
import 'package:drugtime_mobile/features/home/presentation/scene/scene_layout.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime _ict(int h, [int m = 0]) =>
    DateTime.utc(2026, 11, 17, h, m).subtract(const Duration(hours: 7));

void main() {
  final layout = SceneLayout(
    size: const Size(375, 300),
    top: 40,
    chips: const [
      Rect.fromLTWH(20, 220, 90, 30),
      Rect.fromLTWH(120, 222, 120, 30)
    ],
    forbidden: const [Rect.fromLTWH(20, 50, 220, 70)],
  );

  group('vị trí thiên thể (AC3)', () {
    test('02:00 ICT: mặt trời đã lặn, không có cung', () {
      final sky = SkyNow.at(_ict(2));
      expect(sky.sunArc, isNull);
      expect(SceneLayout.visible(sky.sun.altitude), isFalse);
    });

    test('12:00 ICT: mặt trời gần giữa và gần đỉnh cung', () {
      final sky = SkyNow.at(_ict(12));
      expect(sky.sunArc, closeTo(.5, .08));
      final p = layout.celestial(sky.sunArc!, sky.sun.altitude);
      expect(p.dx, closeTo(375 / 2, 30));
      expect(p.dy, lessThan(layout.horizonY - (layout.horizonY - 40) * .6));
    });

    test('đúng giờ mọc: tâm mặt trời ở chân trời, bên trái', () {
      final rise = Astronomy.sunrise(_ict(0))!;
      final sky = SkyNow.at(rise.add(const Duration(seconds: 5)));
      expect(sky.sunArc, closeTo(0, .01));
      final p = layout.celestial(sky.sunArc!, sky.sun.altitude);
      expect((p.dy - layout.horizonY).abs(), lessThanOrEqualTo(300 * .02));
      expect(p.dx, lessThan(60));
    });

    test('mặt trời đi từ trái sang phải trong ngày', () {
      double x(int h) {
        final s = SkyNow.at(_ict(h));
        return layout.celestial(s.sunArc!, s.sun.altitude).dx;
      }

      expect(x(8), lessThan(x(12)));
      expect(x(12), lessThan(x(16)));
    });

    test('mặt trăng có cung khi đã mọc, ánh trăng bằng 0 khi chưa mọc', () {
      for (var h = 0; h < 24; h++) {
        final s = SkyNow.at(_ict(h));
        if (s.moon.position.altitude > 0) {
          expect(s.moonArc, isNotNull, reason: '$h giờ');
          expect(s.moonLight, s.moon.illumination);
        } else {
          expect(s.moonLight, 0);
        }
      }
    });
  });

  group('bề mặt và vùng cấm', () {
    test('rơi từ trên chip xuống thì đáp lên chip, ngoài chip thì đáp lên cỏ',
        () {
      final onChip = layout.landingBelow(const Offset(60, 150));
      expect(onChip.chip, 0);
      expect(onChip.y(60), 220);
      final onGrass = layout.landingBelow(const Offset(320, 150));
      expect(onGrass.isGrass, isTrue);
      // Điểm đã ở dưới mặt chip thì không "đáp ngược" lên chip.
      expect(layout.landingBelow(const Offset(60, 240)).isGrass, isTrue);
    });

    test('mặt cỏ nằm trong banner và thấp hơn chân trời', () {
      for (var x = 0.0; x <= 375; x += 5) {
        expect(layout.grassY(x), greaterThan(layout.horizonY));
        expect(layout.grassY(x), lessThan(300));
      }
    });

    test('allows chặn khung ra ngoài banner hoặc giao vùng chữ', () {
      expect(layout.allows(layout.petRect(const Offset(300, 260), 60)), isTrue);
      expect(
          layout.allows(layout.petRect(const Offset(100, 150), 60)), isFalse);
      expect(layout.allows(layout.petRect(const Offset(10, 260), 60)), isFalse);
    });
  });
}
