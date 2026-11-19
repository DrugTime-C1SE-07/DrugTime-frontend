import 'dart:math' as math;
import 'dart:ui';

/// Một bề mặt pet đứng được: đồi cỏ phía trước hoặc mặt trên một chip.
class Surface {
  const Surface(this.left, this.right, this._y, {this.chip});
  final double left, right;
  final double Function(double x) _y;

  /// Chỉ số chip, `null` nếu là cỏ.
  final int? chip;

  bool get isGrass => chip == null;
  double y(double x) => _y(x.clamp(left, right));
  bool spans(double x) => x >= left && x <= right;
}

/// Hình học của banner: chân trời, các lớp đồi, bề mặt đứng được, vùng cấm và ánh xạ thiên thể.
///
/// Thuần, không phụ thuộc widget; [LivingBanner] tạo lại khi kích thước hay vị trí chip đổi.
class SceneLayout {
  SceneLayout({
    required this.size,
    this.top = 0,
    this.chips = const [],
    this.forbidden = const [],
    this.petHalfWidth = 32,
  });

  final Size size;

  /// Phần trên dành cho thanh trạng thái (safe area).
  final double top;
  final List<Rect> chips;

  /// Vùng chữ (lời chào, tên, chuông) mà pet không được che.
  final List<Rect> forbidden;
  final double petHalfWidth;

  double get width => size.width;
  double get height => size.height;

  /// Đường chân trời: thiên thể có độ cao 0° nằm ở đây, phía sau lớp đồi xa.
  double get horizonY => height * .66;

  double _wave(double x, double base, double amp, double freq, double phase) =>
      base +
      amp * math.sin(2 * math.pi * freq * x / math.max(width, 1) + phase);

  double hillFarY(double x) =>
      _wave(x, height * .64, 9, 1.1, .6) + 4 * math.sin(x / 23);
  double hillMidY(double x) => _wave(x, height * .74, 11, .8, 2.1);

  /// Mặt cỏ phía trước, nơi pet đi lại.
  double grassY(double x) => _wave(x, height * .87, 7, .7, 1.9);

  late final List<Surface> surfaces = [
    Surface(petHalfWidth, width - petHalfWidth, grassY),
    for (var i = 0; i < chips.length; i++)
      // mép chip kẹp vào khoảng pet đứng lọt khung
      Surface(
          math.max(chips[i].left + 10, petHalfWidth),
          math.min(chips[i].right - 10, width - petHalfWidth),
          (_) => chips[i].top,
          chip: i),
  ];

  Surface get grass => surfaces.first;

  /// Bề mặt cao nhất (y nhỏ nhất) nằm dưới điểm [p]; không có thì là cỏ.
  Surface landingBelow(Offset p) {
    Surface best = grass;
    var bestY = grass.y(p.dx);
    for (final s in surfaces.skip(1)) {
      if (!s.spans(p.dx)) continue;
      final y = s.y(p.dx);
      if (y >= p.dy - 2 && y < bestY) {
        best = s;
        bestY = y;
      }
    }
    return best;
  }

  /// Khung pet khi chân đứng ở [feet], pet cao [petHeight].
  Rect petRect(Offset feet, double petHeight) => Rect.fromLTRB(
      feet.dx - petHalfWidth,
      feet.dy - petHeight,
      feet.dx + petHalfWidth,
      feet.dy);

  /// Pet nằm trọn trong banner và không giao vùng chữ.
  bool allows(Rect pet) =>
      pet.left >= 0 &&
      pet.right <= width &&
      pet.top >= top &&
      pet.bottom <= height &&
      !forbidden.any(pet.overlaps);

  /// Vị trí tâm thiên thể. [arc]: 0 lúc mọc (Đông, bên trái) → 1 lúc lặn (Tây, bên phải).
  Offset celestial(double arc, double altitude) {
    const margin = 36.0;
    final x = margin + arc.clamp(0.0, 1.0) * (width - 2 * margin);
    final reach = horizonY - top - 34;
    final y = horizonY -
        math.sin(altitude.clamp(-10.0, 90.0) * math.pi / 180) * reach;
    return Offset(x, y);
  }

  /// Thiên thể có độ cao dưới -1° thì không vẽ.
  static bool visible(double altitude) => altitude > -1;
}
