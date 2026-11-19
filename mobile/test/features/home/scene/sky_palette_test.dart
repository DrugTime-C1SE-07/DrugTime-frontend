import 'package:drugtime_mobile/features/home/presentation/scene/sky_palette.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('màu biến thiên liên tục khi mặt trời đi từ -20° đến 60° (AC4)', () {
    for (final moon in [0.0, 1.0]) {
      var prev = SkyPalette.at(-20, moonLight: moon);
      for (var i = 1; i <= 800; i++) {
        final alt = -20 + i * .1;
        final next = SkyPalette.at(alt, moonLight: moon);
        for (var j = 0; j < prev.oklab.length; j++) {
          expect(prev.oklab[j].distance(next.oklab[j]), lessThanOrEqualTo(.02),
              reason: 'màu $j tại ${alt.toStringAsFixed(1)}° (trăng $moon)');
        }
        expect((prev.stars - next.stars).abs(), lessThanOrEqualTo(.02));
        expect((prev.light - next.light).abs(), lessThanOrEqualTo(.02));
        prev = next;
      }
    }
  });

  test('đêm tối, có sao; ban ngày sáng, không sao', () {
    final night = SkyPalette.at(-30);
    expect(night.oklab[0].l, lessThan(.3));
    expect(night.stars, 1);
    expect(night.darkSky, isTrue);
    final noon = SkyPalette.at(70);
    expect(noon.oklab[0].l, greaterThan(.6));
    expect(noon.stars, 0);
    expect(noon.darkSky, isFalse);
  });

  test('ánh trăng làm đêm sáng hơn và bớt sao, không ảnh hưởng ban ngày', () {
    expect(SkyPalette.at(-30, moonLight: 1).oklab[0].l,
        greaterThan(SkyPalette.at(-30).oklab[0].l));
    expect(SkyPalette.at(-30, moonLight: 1).stars, lessThan(1));
    expect(
        SkyPalette.at(30, moonLight: 1)
            .oklab[0]
            .distance(SkyPalette.at(30).oklab[0]),
        0);
  });

  test('OKLab chuyển qua lại giữ màu', () {
    const c = Color(0xFF5C9EE0);
    final back = Oklab.fromColor(c).toColor();
    expect((back.r - c.r).abs(), lessThan(.002));
    expect((back.g - c.g).abs(), lessThan(.002));
    expect((back.b - c.b).abs(), lessThan(.002));
  });
}
