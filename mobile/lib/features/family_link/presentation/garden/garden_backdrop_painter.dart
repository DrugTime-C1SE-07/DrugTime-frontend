import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'garden_mood.dart';

/// Nền khu vườn: gradient trời theo trạng thái, đồi cỏ, hàng rào gỗ thấp, lá rơi,
/// bướm và tim nhỏ bay chậm. [clock] là thời gian (giây) của cảnh; đứng yên khi giảm
/// chuyển động. Không phụ thuộc gì từ banner trang chủ.
class GardenBackdropPainter extends CustomPainter {
  GardenBackdropPainter(
      {required this.spec, required this.clock, this.hearts = 0})
      : super(repaint: clock);

  final GardenSpec spec;
  final ValueNotifier<double> clock;

  /// Số tim nổi thêm (vd. khi được xoa đầu), 0..1 giảm dần.
  final double hearts;

  @override
  void paint(Canvas canvas, Size size) {
    final t = clock.value;
    final w = size.width, h = size.height;
    final rect = Offset.zero & size;
    canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: spec.sky)
              .createShader(rect));

    // các đốm sáng mềm trôi chậm
    for (var i = 0; i < 3; i++) {
      final cx = w * (.2 + .3 * i) + math.sin(t * .2 + i * 2) * 12;
      final cy = h * (.22 + .08 * (i % 2)) + math.cos(t * .17 + i) * 6;
      canvas.drawCircle(Offset(cx, cy), h * (.16 + .04 * i),
          Paint()..color = Colors.white.withValues(alpha: .35));
    }

    // hàng rào gỗ thấp
    final fenceTop = h * .58, fenceBottom = h * .78;
    final wood = Paint()..color = const Color(0xFFE9D3B0);
    final woodLine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFFC9A877);
    canvas.drawRect(Rect.fromLTRB(0, fenceTop + 10, w, fenceTop + 16), wood);
    canvas.drawRect(Rect.fromLTRB(0, fenceTop + 26, w, fenceTop + 32), wood);
    for (var x = 8.0; x < w; x += 22) {
      final post = Path()
        ..moveTo(x, fenceBottom)
        ..lineTo(x, fenceTop + 4)
        ..lineTo(x + 5, fenceTop)
        ..lineTo(x + 10, fenceTop + 4)
        ..lineTo(x + 10, fenceBottom)
        ..close();
      canvas.drawPath(post, wood);
      canvas.drawPath(post, woodLine);
    }

    // đồi cỏ
    final hill = Path()
      ..moveTo(0, h * .74)
      ..quadraticBezierTo(w * .3, h * .66, w * .55, h * .72)
      ..quadraticBezierTo(w * .8, h * .78, w, h * .7)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(hill, Paint()..color = spec.ground);
    final tuft = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = Color.lerp(spec.ground, const Color(0xFF2E7D4F), .35)!;
    for (var i = 0; i < 14; i++) {
      final x = (i * 37.0 + 11) % w;
      final y = h * .8 + (i % 3) * 6.0;
      final sway = math.sin(t * 1.4 + i) * 1.5;
      canvas.drawLine(Offset(x, y), Offset(x - 3 + sway, y - 7), tuft);
      canvas.drawLine(Offset(x + 3, y), Offset(x + 4 + sway, y - 8), tuft);
    }

    // lá rơi
    for (var i = 0; i < 4; i++) {
      final ph = (t * .08 + i * .27) % 1;
      final x = w * ((i * .23 + .1) % 1) + math.sin(ph * math.pi * 4 + i) * 14;
      final y = -10 + ph * (h * .9);
      _leaf(canvas, Offset(x, y), ph * math.pi * 3 + i,
          (1 - ph).clamp(0.0, 1.0) * .8);
    }

    // bướm
    final bx = w * .5 + math.sin(t * .35) * w * .32;
    final by = h * .3 + math.sin(t * .9) * h * .08;
    _butterfly(canvas, Offset(bx, by), t);

    // tim nổi
    if (hearts > .01) {
      for (var i = 0; i < 3; i++) {
        final ph = (t * .6 + i / 3) % 1;
        _heart(canvas, Offset(w * (.42 + i * .08), h * (.55 - ph * .4)),
            6 + i * 1.5, hearts * math.sin(ph * math.pi));
      }
    }
  }

  void _leaf(Canvas c, Offset at, double angle, double alpha) {
    c.save();
    c.translate(at.dx, at.dy);
    c.rotate(angle);
    final p = Path()
      ..moveTo(0, -6)
      ..quadraticBezierTo(5, 0, 0, 6)
      ..quadraticBezierTo(-5, 0, 0, -6)
      ..close();
    c.drawPath(
        p, Paint()..color = const Color(0xFF7CC28A).withValues(alpha: alpha));
    c.restore();
  }

  void _butterfly(Canvas c, Offset at, double t) {
    final flap = .35 + .65 * math.sin(t * 9).abs();
    final wing = Paint()..color = const Color(0xFFFFB3C7).withValues(alpha: .9);
    for (final side in [-1.0, 1.0]) {
      c.drawOval(
          Rect.fromCenter(
              center: at + Offset(side * 4 * flap, -2),
              width: 8 * flap,
              height: 9),
          wing);
      c.drawOval(
          Rect.fromCenter(
              center: at + Offset(side * 3 * flap, 4),
              width: 6 * flap,
              height: 6),
          wing);
    }
    c.drawLine(
        at + const Offset(0, -4),
        at + const Offset(0, 6),
        Paint()
          ..strokeWidth = 1.6
          ..color = const Color(0xFF5B3FA8));
  }

  void _heart(Canvas c, Offset at, double s, double alpha) {
    final p = Path()
      ..moveTo(at.dx, at.dy + s * .9)
      ..cubicTo(at.dx - s * 1.6, at.dy - s * .2, at.dx - s * .6,
          at.dy - s * 1.4, at.dx, at.dy - s * .45)
      ..cubicTo(at.dx + s * .6, at.dy - s * 1.4, at.dx + s * 1.6,
          at.dy - s * .2, at.dx, at.dy + s * .9)
      ..close();
    c.drawPath(
        p, Paint()..color = const Color(0xFFFF6F91).withValues(alpha: alpha));
  }

  @override
  bool shouldRepaint(covariant GardenBackdropPainter old) =>
      old.spec != spec || old.clock != clock || old.hearts != hearts;
}
