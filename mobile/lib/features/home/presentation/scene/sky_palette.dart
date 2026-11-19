import 'dart:math' as math;
import 'dart:ui';

/// Màu trong không gian OKLab (đồng đều về cảm nhận), dùng để nội suy mượt giữa các mốc trời.
class Oklab {
  const Oklab(this.l, this.a, this.b);
  final double l, a, b;

  static double _lin(double c) =>
      c <= .04045 ? c / 12.92 : math.pow((c + .055) / 1.055, 2.4).toDouble();
  static double _gam(double c) => c <= .0031308
      ? 12.92 * c
      : 1.055 * math.pow(c, 1 / 2.4).toDouble() - .055;
  static double _cbrt(double x) =>
      x < 0 ? -math.pow(-x, 1 / 3).toDouble() : math.pow(x, 1 / 3).toDouble();

  factory Oklab.fromColor(Color c) {
    final r = _lin(c.r), g = _lin(c.g), b = _lin(c.b);
    final l = _cbrt(.4122214708 * r + .5363325363 * g + .0514459929 * b);
    final m = _cbrt(.2119034982 * r + .6806995451 * g + .1073969566 * b);
    final s = _cbrt(.0883024619 * r + .2817188376 * g + .6299787005 * b);
    return Oklab(
      .2104542553 * l + .7936177850 * m - .0040720468 * s,
      1.9779984951 * l - 2.4285922050 * m + .4505937099 * s,
      .0259040371 * l + .7827717662 * m - .8086757660 * s,
    );
  }

  Color toColor([double alpha = 1]) {
    final l_ = l + .3963377774 * a + .2158037573 * b;
    final m_ = l - .1055613458 * a - .0638541728 * b;
    final s_ = l - .0894841775 * a - 1.2914855480 * b;
    final L = l_ * l_ * l_, M = m_ * m_ * m_, S = s_ * s_ * s_;
    double ch(double v) => _gam(v).clamp(0.0, 1.0);
    return Color.from(
      alpha: alpha,
      red: ch(4.0767416621 * L - 3.3077115913 * M + .2309699292 * S),
      green: ch(-1.2684380046 * L + 2.6097574011 * M - .3413193965 * S),
      blue: ch(-.0041960863 * L - .7034186147 * M + 1.7076147010 * S),
    );
  }

  Oklab lerp(Oklab o, double t) =>
      Oklab(l + (o.l - l) * t, a + (o.a - a) * t, b + (o.b - b) * t);

  double distance(Oklab o) {
    final dl = l - o.l, da = a - o.a, db = b - o.b;
    return math.sqrt(dl * dl + da * da + db * db);
  }
}

/// Bảng màu của cảnh tại một độ cao mặt trời.
class SkyPalette {
  const SkyPalette._(this._c, this.stars, this.light);

  final List<Oklab> _c;

  /// Độ hiện của sao, 0..1.
  final double stars;

  /// Cường độ ánh sáng chiếu lên cảnh (mặt trời hoặc trăng), 0..1.
  final double light;

  Color get zenith => _c[0].toColor();
  Color get horizon => _c[1].toColor();
  Color get glow => _c[2].toColor();
  Color get hillFar => _c[3].toColor();
  Color get hillMid => _c[4].toColor();
  Color get hillNear => _c[5].toColor();
  Color get grass => _c[6].toColor();
  Color get cloud => _c[7].toColor();

  /// Các màu dạng OKLab theo thứ tự trên, để test so khoảng cách.
  List<Oklab> get oklab => List.unmodifiable(_c);

  /// Chữ đặt trên trời nên dùng màu sáng hay không.
  bool get darkSky => _c[0].l < .62;

  static const _keys = <(double, List<int>, double, double)>[
    // độ cao, [đỉnh trời, chân trời, quầng, đồi xa, đồi giữa, đồi gần, cỏ, mây], sao, ánh sáng
    (
      -18,
      [
        0x0A0F24,
        0x1A1F45,
        0x23285A,
        0x1E2A48,
        0x17323F,
        0x12302F,
        0x1A4A3A,
        0x2A3156
      ],
      1,
      .05
    ),
    (
      -12,
      [
        0x111A3A,
        0x2B2C5E,
        0x3B3470,
        0x23304F,
        0x1A3843,
        0x15352F,
        0x1E503E,
        0x363A66
      ],
      .8,
      .08
    ),
    (
      -6,
      [
        0x1F3466,
        0x6A4A7A,
        0xC2627A,
        0x35406A,
        0x264A55,
        0x1E4A40,
        0x2B6450,
        0x7A5E84
      ],
      .3,
      .2
    ),
    (
      -2,
      [
        0x3A5A96,
        0xE58A6E,
        0xFF9A5C,
        0x5A6488,
        0x3D6268,
        0x2F5E50,
        0x3F7A5C,
        0xE3A08A
      ],
      .08,
      .4
    ),
    (
      0,
      [
        0x5A82BE,
        0xFFB27A,
        0xFFB45E,
        0x8E9C8E,
        0x6E9E5E,
        0x5E9A48,
        0xB8C870,
        0xFFD0B0
      ],
      0,
      .55
    ),
    (
      3,
      [
        0x6EA6DC,
        0xFFD9AE,
        0xFFD07A,
        0xA4BC86,
        0x88B95A,
        0x76B044,
        0xC9DC74,
        0xFFE6CC
      ],
      0,
      .7
    ),
    (
      8,
      [
        0x4FA9EA,
        0xCDEDFB,
        0xFFF0C0,
        0xB4D88A,
        0x98CC55,
        0x84C142,
        0xD6EC7A,
        0xFFFFFF
      ],
      0,
      .85
    ),
    (
      20,
      [
        0x41A8EE,
        0xC8EDFC,
        0xFFF7DA,
        0xBCDE8E,
        0x9FD25A,
        0x8BC745,
        0xDCF07E,
        0xFFFFFF
      ],
      0,
      .95
    ),
    (
      45,
      [
        0x3AA2EC,
        0xC2EBFC,
        0xFFFBEA,
        0xC2E294,
        0xA4D65E,
        0x90CB48,
        0xE0F282,
        0xFFFFFF
      ],
      0,
      1
    ),
  ];

  static final _ok = [
    for (final k in _keys)
      [for (final c in k.$2) Oklab.fromColor(Color(0xFF000000 | c))]
  ];

  /// Ánh trăng làm đêm sáng và xanh hơn một chút; [moonLight] = độ rọi × (trăng trên chân trời).
  static const _moonTint = Oklab(.42, -.02, -.06);

  /// Bảng màu tại [sunAltitude] (độ), nội suy tuyến tính trong OKLab giữa các mốc.
  static SkyPalette at(double sunAltitude, {double moonLight = 0}) {
    final alt = sunAltitude.clamp(_keys.first.$1, _keys.last.$1);
    var i = 0;
    while (i < _keys.length - 2 && alt > _keys[i + 1].$1) {
      i++;
    }
    final a = _keys[i], b = _keys[i + 1];
    final t = ((alt - a.$1) / (b.$1 - a.$1)).clamp(0.0, 1.0);
    // Ánh trăng chỉ có tác dụng khi trời đủ tối (mặt trời dưới -6°).
    final night = ((-sunAltitude - 6) / 12).clamp(0.0, 1.0);
    final moon = moonLight.clamp(0.0, 1.0) * night * .18;
    final colors = [
      for (var j = 0; j < a.$2.length; j++)
        _ok[i][j].lerp(_ok[i + 1][j], t).lerp(_moonTint, j == 2 ? 0 : moon)
    ];
    return SkyPalette._(
      colors,
      (a.$3 + (b.$3 - a.$3) * t) * (1 - moon * 1.5),
      a.$4 + (b.$4 - a.$4) * t + moon,
    );
  }
}
