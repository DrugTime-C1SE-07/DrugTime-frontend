import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import 'astronomy.dart';
import 'scene_layout.dart';
import 'sky_palette.dart';

/// Vẽ bầu trời, thiên thể, mây, đồi và cỏ của banner.
class ScenePainter extends CustomPainter {
  ScenePainter({
    required this.sky,
    required this.palette,
    required this.layout,
    required this.time,
    super.repaint,
  });

  final SkyNow sky;
  final SkyPalette palette;
  final SceneLayout layout;

  /// Giây trôi qua, cho mây trôi, sao nhấp nháy, cỏ đung đưa.
  final double Function() time;

  static final _stars = () {
    final r = math.Random(42);
    return [
      for (var i = 0; i < 70; i++)
        (
          r.nextDouble(),
          r.nextDouble(),
          .6 + r.nextDouble() * 1.2,
          r.nextDouble() * 6
        )
    ];
  }();

  static final _clouds = () {
    final r = math.Random(7);
    return [
      for (var layer = 0; layer < 3; layer++)
        for (var i = 0; i < 3; i++)
          (
            layer,
            r.nextDouble(),
            .22 + layer * .14 + r.nextDouble() * .12,
            .7 + r.nextDouble() * .6,
          )
    ];
  }();

  /// Vị trí tâm mặt trời trên khung, `null` khi đã lặn.
  Offset? get sunPoint =>
      sky.sunArc == null || !SceneLayout.visible(sky.sun.altitude)
          ? null
          : layout.celestial(sky.sunArc!, sky.sun.altitude);

  Offset? get moonPoint =>
      sky.moonArc == null || !SceneLayout.visible(sky.moon.position.altitude)
          ? null
          : layout.celestial(sky.moonArc!, sky.moon.position.altitude);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 1 || size.height < 1) return;
    final t = time();
    final w = size.width, h = size.height;
    final full = Offset.zero & size;
    final horizon = layout.horizonY;

    // bầu trời
    canvas.drawRect(
        full,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [palette.zenith, palette.horizon, palette.horizon],
            stops: [0, horizon / h, 1],
          ).createShader(full));

    // tán xạ quanh mặt trời: mạnh khi mặt trời thấp, vẫn còn chút sau khi lặn
    final alt = sky.sun.altitude;
    if (alt > -10) {
      final p = sunPoint ??
          Offset(sky.sunArc == null && sky.sun.azimuth > 180 ? w * .9 : w * .1,
              horizon);
      final low = (1 - (alt / 40)).clamp(0.0, 1.0);
      final fade = ((alt + 10) / 10).clamp(0.0, 1.0);
      final radius = 120 + 160 * low;
      canvas.drawCircle(
          p,
          radius,
          Paint()
            ..shader = RadialGradient(colors: [
              palette.glow.withValues(alpha: .65 * fade),
              palette.glow.withValues(alpha: .18 * fade),
              palette.glow.withValues(alpha: 0),
            ], stops: const [
              0,
              .45,
              1
            ]).createShader(Rect.fromCircle(center: p, radius: radius)));
    }

    // sao
    if (palette.stars > .01) {
      final star = Paint();
      for (final (sx, sy, r, ph) in _stars) {
        final y = layout.top + sy * (horizon - layout.top) * .95;
        final tw = .55 + .45 * math.sin(t * 1.7 + ph);
        star.color =
            const Color(0xFFFFFFFF).withValues(alpha: palette.stars * tw * .9);
        canvas.drawCircle(Offset(sx * w, y), r, star);
      }
    }

    final moon = moonPoint;
    if (moon != null) _moon(canvas, moon);
    final sun = sunPoint;
    if (sun != null) _sun(canvas, sun, alt);

    // đốm lấp lánh ban ngày
    if (palette.light > .5) {
      for (final (fx, fy, ph) in _sparkles) {
        final p = Offset(fx * w, layout.top + fy * (horizon - layout.top));
        final k =
            math.max(0.0, math.sin(t * 1.4 + ph)) * (palette.light - .5) * 2;
        if (k < .05) continue;
        final star = Paint()
          ..color = const Color(0xFFFFFFFF).withValues(alpha: .85 * k);
        final r = 3.5 * k;
        canvas.drawPath(
            Path()
              ..moveTo(p.dx, p.dy - r * 2)
              ..quadraticBezierTo(p.dx, p.dy, p.dx + r * 2, p.dy)
              ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy + r * 2)
              ..quadraticBezierTo(p.dx, p.dy, p.dx - r * 2, p.dy)
              ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy - r * 2),
            star);
        canvas.drawCircle(
            p,
            r * 1.6,
            Paint()
              ..color = const Color(0xFFFFFFFF).withValues(alpha: .25 * k)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
      }
    }

    // mây (lớp xa trước)
    for (final (layer, x0, yf, scale) in _clouds) {
      final speed = 2.5 + layer * 2.5;
      final span = w + 240;
      final x = (x0 * span + t * speed) % span - 120;
      final y = layout.top + yf * (horizon - layout.top);
      _cloud(canvas, Offset(x, y), (9 + layer * 3.5) * scale, layer);
    }

    // đồi mượt kiểu "đồng cỏ xanh": xa → giữa → gần, mỗi đồi có dải sáng trên đỉnh
    final haze = palette.horizon;
    _hill(
        canvas,
        size,
        layout.hillFarY,
        Color.lerp(palette.hillFar, haze, .12)!,
        palette.hillFar,
        palette.grass,
        .35);
    _foliage(canvas, size, t, back: true);
    _hill(
        canvas,
        size,
        layout.hillMidY,
        palette.hillMid,
        Color.lerp(palette.hillMid, const Color(0xFF123A1C), .12)!,
        palette.grass,
        .45);
    _hill(
        canvas,
        size,
        layout.grassY,
        palette.hillNear,
        Color.lerp(palette.hillNear, const Color(0xFF123A1C), .2)!,
        palette.grass,
        .6);
    _foliage(canvas, size, t, back: false);
  }

  /// Khóm lá ở hai góc: (bên trái?, x lệch so với mép, góc nghiêng, cỡ, loại, tông, pha gió, lớp sau?).
  static const _plants = [
    (true, 2.0, -.55, 1.0, 1, 0, 0.0, true),
    (true, 18.0, -.25, .85, 0, 1, 1.3, true),
    (true, -6.0, -.05, 1.15, 0, 2, 2.1, false),
    (true, 22.0, .25, .9, 1, 3, .7, false),
    (true, 40.0, .5, .6, 0, 1, 2.8, false),
    (false, 4.0, .55, 1.05, 1, 0, .4, true),
    (false, 26.0, .2, .9, 0, 2, 1.9, true),
    (false, -4.0, .05, 1.2, 0, 1, 2.6, false),
    (false, 30.0, -.3, .8, 1, 3, 1.1, false),
    (false, 52.0, -.55, .55, 0, 2, 3.3, false),
  ];

  /// Đốm lấp lánh trên trời ban ngày.
  static final _sparkles = () {
    final r = math.Random(17);
    return [
      for (var i = 0; i < 7; i++)
        (r.nextDouble(), .15 + r.nextDouble() * .6, r.nextDouble() * 6)
    ];
  }();

  void _hill(Canvas c, Size size, double Function(double) y, Color top,
      Color bottom, Color highlight, double glow) {
    final path = Path()..moveTo(0, size.height);
    final ridge = Path();
    var minY = size.height;
    for (var x = 0.0; x <= size.width + 4; x += 4) {
      final v = y(x);
      minY = math.min(minY, v);
      path.lineTo(x, v);
      x == 0 ? ridge.moveTo(x, v + 9) : ridge.lineTo(x, v + 9);
    }
    path
      ..lineTo(size.width, size.height)
      ..close();
    final bounds = Rect.fromLTRB(0, minY, size.width, size.height);
    c.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [top, bottom],
          ).createShader(bounds));
    // dải sáng mềm chạy theo đỉnh đồi
    c.save();
    c.clipPath(path);
    c.drawPath(
        ridge,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 16
          ..color =
              highlight.withValues(alpha: glow * (.35 + .65 * palette.light))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7));
    c.restore();
  }

  void _foliage(Canvas c, Size size, double t, {required bool back}) {
    final day = palette.light;
    const night = Color(0xFF0F2A22);
    Color tone(Color day0) => Color.lerp(night, day0, .35 + .65 * day)!;
    final tones = [
      tone(const Color(0xFF2E7D32)),
      tone(const Color(0xFF43A047)),
      tone(const Color(0xFF66BB6A)),
      tone(const Color(0xFF9CCC65)),
    ];
    for (final (left, dx, lean, s, kind, k, phase, isBack) in _plants) {
      if (isBack != back) continue;
      final x = left ? dx : size.width - dx;
      final base = Offset(x, layout.grassY(x) + 6);
      final sway =
          math.sin(t * 1.1 + phase) * .05 + math.sin(t * 2.3 + phase) * .015;
      c.save();
      c.translate(base.dx, base.dy);
      c.rotate(lean + sway);
      c.scale(s * (back ? .85 : 1));
      final color = tones[back ? math.max(0, k - 1) : k];
      if (kind == 0) {
        _broadLeaf(c, color);
      } else {
        _fern(c, color, t, phase);
      }
      c.restore();
    }
  }

  /// Lá rộng có gân giữa, nửa sáng nửa tối.
  void _broadLeaf(Canvas c, Color color) {
    const h = 74.0, w = 30.0;
    final leaf = Path()
      ..moveTo(0, 0)
      ..cubicTo(-w, -h * .25, -w * .8, -h * .8, 0, -h)
      ..cubicTo(w * .8, -h * .8, w, -h * .25, 0, 0)
      ..close();
    c.drawPath(leaf, Paint()..color = color);
    final half = Path()
      ..moveTo(0, 0)
      ..cubicTo(w, -h * .25, w * .8, -h * .8, 0, -h)
      ..close();
    c.drawPath(half,
        Paint()..color = Color.lerp(color, const Color(0xFFFFFFFF), .14)!);
    final vein = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..color = Color.lerp(color, const Color(0xFF0B2A12), .3)!;
    c.drawLine(Offset.zero, const Offset(0, -h * .92), vein);
    for (var i = 1; i < 5; i++) {
      final y = -h * i / 5.5;
      c.drawLine(Offset(0, y), Offset(-w * .45, y - 9), vein..strokeWidth = .9);
      c.drawLine(Offset(0, y), Offset(w * .45, y - 9), vein);
    }
  }

  /// Cành nhỏ với các lá bầu dục mọc đối, rung nhẹ theo gió.
  void _fern(Canvas c, Color color, double t, double phase) {
    const h = 84.0;
    final stem = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = Color.lerp(color, const Color(0xFF0B2A12), .25)!;
    final bend = math.sin(t * 1.6 + phase) * 3;
    c.drawPath(
        Path()
          ..moveTo(0, 0)
          ..quadraticBezierTo(bend, -h * .5, bend * 1.5 + 4, -h),
        stem);
    final leaf = Paint()..color = color;
    for (var i = 1; i <= 6; i++) {
      final u = i / 6.4;
      final p = Offset(bend * u * 1.5 + 4 * u * u, -h * u);
      final size = 13.0 * (1 - u * .45);
      for (final side in [-1.0, 1.0]) {
        c.save();
        c.translate(p.dx, p.dy);
        c.rotate(side * (1.05 - u * .3) + math.sin(t * 2 + phase + i) * .06);
        c.drawOval(
            Rect.fromCenter(
                center: Offset(0, -size * .55),
                width: size * .55,
                height: size * 1.1),
            leaf);
        c.restore();
      }
    }
    c.drawOval(
        Rect.fromCenter(
            center: Offset(bend * 1.5 + 4, -h - 4), width: 6, height: 11),
        leaf);
  }

  void _sun(Canvas c, Offset p, double alt) {
    final warm = (alt / 15).clamp(0.0, 1.0);
    final core =
        Color.lerp(const Color(0xFFFF7A3D), const Color(0xFFFFF4C2), warm)!;
    for (final (r, a) in [(64.0, .10), (40.0, .18), (26.0, .35)]) {
      c.drawCircle(p, r, Paint()..color = core.withValues(alpha: a));
    }
    c.drawCircle(
        p,
        18,
        Paint()
          ..shader = RadialGradient(colors: [
            const Color(0xFFFFFFF4),
            core,
          ]).createShader(Rect.fromCircle(center: p, radius: 18)));
  }

  void _moon(Canvas c, Offset p) {
    final k = sky.moon.illumination;
    // ban ngày trăng nhạt đi theo độ sáng trời
    final a = (1 - palette.light * .65).clamp(.25, 1.0);
    const r = 15.0;
    if (palette.stars > .1) {
      c.drawCircle(
          p,
          r * 3.4,
          Paint()
            ..shader = RadialGradient(colors: [
              const Color(0xFFEFF3FF).withValues(alpha: .28 * k * a),
              const Color(0x00EFF3FF),
            ]).createShader(Rect.fromCircle(center: p, radius: r * 3.4)));
    }
    c.drawCircle(p, r,
        Paint()..color = const Color(0xFF3A4266).withValues(alpha: .35 * a));
    // phần sáng: nửa đĩa phía được chiếu + nửa elip của đường phân sáng
    final side = sky.moon.waxing ? 1.0 : -1.0;
    final ex = r * (1 - 2 * k); // >0: lưỡi liềm, <0: trăng khuyết lồi
    final lit = Path()
      ..moveTo(p.dx, p.dy - r)
      ..arcToPoint(Offset(p.dx, p.dy + r),
          radius: const Radius.circular(r), clockwise: side > 0)
      ..arcToPoint(Offset(p.dx, p.dy - r),
          radius: Radius.elliptical(ex.abs().clamp(.01, r), r),
          clockwise: (side > 0) == (ex > 0) ? false : true);
    c.drawPath(
        lit, Paint()..color = const Color(0xFFF7F2DC).withValues(alpha: a));
    // vài vết sẫm
    final crater = Paint()
      ..color = const Color(0xFFD8D0B0).withValues(alpha: .5 * a);
    c.save();
    c.clipPath(lit);
    c.drawCircle(p + const Offset(-4, -3), 3.2, crater);
    c.drawCircle(p + const Offset(5, 5), 2.4, crater);
    c.drawCircle(p + const Offset(-2, 7), 1.6, crater);
    c.restore();
  }

  void _cloud(Canvas c, Offset o, double s, int layer) {
    final base = palette.cloud;
    final alpha = (.3 + .45 * palette.light) * (.55 + layer * .15);
    final top = Paint()
      ..color = base.withValues(alpha: alpha)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * .12);
    final shade = Paint()
      ..color =
          Color.lerp(base, palette.hillFar, .45)!.withValues(alpha: alpha * .9);
    final puffs = [
      (Offset(-s * 1.2, 0), s * .7),
      (Offset(-s * .4, -s * .45), s * .9),
      (Offset(s * .5, -s * .3), s * .8),
      (Offset(s * 1.25, 0), s * .62),
    ];
    for (final (d, r) in puffs) {
      c.drawCircle(o + d + Offset(0, s * .18), r, shade);
    }
    for (final (d, r) in puffs) {
      c.drawCircle(o + d, r, top);
    }
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTRB(
                o.dx - s * 1.7, o.dy - s * .1, o.dx + s * 1.8, o.dy + s * .62),
            Radius.circular(s * .4)),
        top);
  }

  @override
  bool shouldRepaint(ScenePainter old) =>
      old.sky != sky || old.palette != palette || old.layout != layout;
}
