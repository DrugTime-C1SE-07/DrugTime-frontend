import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'garden_mood.dart';

/// Vẽ một đạo cụ trong khung 48×48: kính lúp, viên thuốc, chuông, máy bay giấy,
/// bình tưới. Chuyển động nhẹ theo [clock].
class GardenPropPainter extends CustomPainter {
  GardenPropPainter(this.prop, {required this.clock, this.tilt = 0})
      : super(repaint: clock);

  final GardenProp prop;
  final ValueNotifier<double> clock;

  /// Độ nghiêng thêm (vd. bình tưới khi đang tưới), radian.
  final double tilt;

  @override
  void paint(Canvas canvas, Size size) {
    final t = clock.value;
    canvas.save();
    canvas.scale(size.width / 48);
    canvas.translate(24, 24);
    switch (prop) {
      case GardenProp.magnifier:
        canvas.rotate(-.4 + math.sin(t * 2) * .12);
        _magnifier(canvas);
      case GardenProp.pill:
        canvas.translate(0, math.sin(t * 3) * 2);
        canvas.rotate(-.6);
        _pill(canvas);
      case GardenProp.bell:
        canvas.translate(0, -8);
        canvas.rotate(math.sin(t * 14) * .45);
        canvas.translate(0, 8);
        _bell(canvas, t);
      case GardenProp.paperPlane:
        canvas.translate(math.sin(t * 1.5) * 4, math.cos(t * 3) * 3);
        _plane(canvas);
      case GardenProp.wateringCan:
        canvas.rotate(tilt);
        _can(canvas);
      case GardenProp.confetti:
        break;
    }
    canvas.restore();
  }

  void _magnifier(Canvas c) {
    c.drawLine(
        const Offset(6, 6),
        const Offset(18, 18),
        Paint()
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFF7A4B32));
    c.drawCircle(Offset.zero, 11,
        Paint()..color = const Color(0xFFCFEFFF).withValues(alpha: .8));
    c.drawCircle(
        Offset.zero,
        11,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = const Color(0xFF274280));
    c.drawCircle(const Offset(-4, -4), 3, Paint()..color = Colors.white);
  }

  void _pill(Canvas c) {
    final half = RRect.fromRectAndRadius(
        const Rect.fromLTWH(-16, -7, 32, 14), const Radius.circular(7));
    c.save();
    c.clipRect(const Rect.fromLTWH(-16, -7, 16, 14));
    c.drawRRect(half, Paint()..color = const Color(0xFFFF9A62));
    c.restore();
    c.save();
    c.clipRect(const Rect.fromLTWH(0, -7, 16, 14));
    c.drawRRect(half, Paint()..color = Colors.white);
    c.restore();
    c.drawRRect(
        half,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFFB4502A));
  }

  void _bell(Canvas c, double t) {
    final body = Path()
      ..moveTo(-13, 8)
      ..quadraticBezierTo(-12, -14, 0, -15)
      ..quadraticBezierTo(12, -14, 13, 8)
      ..close();
    c.drawPath(body, Paint()..color = const Color(0xFFFFC928));
    c.drawPath(
        body,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFFE9A400));
    c.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(-16, 7, 32, 5), const Radius.circular(2.5)),
        Paint()..color = const Color(0xFFE9A400));
    c.drawCircle(
        const Offset(0, 14), 3.5, Paint()..color = const Color(0xFFE9A400));
    // sóng âm
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 2; i++) {
      final ph = (t * 1.4 + i * .5) % 1;
      ring.color = const Color(0xFFE9A400).withValues(alpha: 1 - ph);
      final r = 16 + ph * 8;
      c.drawArc(Rect.fromCircle(center: Offset.zero, radius: r), -.6, 1.2,
          false, ring);
      c.drawArc(Rect.fromCircle(center: Offset.zero, radius: r), math.pi - .6,
          1.2, false, ring);
    }
  }

  void _plane(Canvas c) {
    final wing = Path()
      ..moveTo(-16, 2)
      ..lineTo(16, -10)
      ..lineTo(2, 12)
      ..lineTo(-2, 4)
      ..close();
    c.drawPath(wing, Paint()..color = Colors.white);
    c.drawPath(
        wing,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0xFF5B3FA8));
    c.drawLine(
        const Offset(-2, 4),
        const Offset(16, -10),
        Paint()
          ..strokeWidth = 1.2
          ..color = const Color(0xFF5B3FA8));
  }

  void _can(Canvas c) {
    final body = RRect.fromRectAndRadius(
        const Rect.fromLTWH(-12, -6, 22, 18), const Radius.circular(5));
    c.drawRRect(body, Paint()..color = const Color(0xFF6EC6F5));
    c.drawPath(
        Path()
          ..moveTo(10, 0)
          ..lineTo(20, -10)
          ..lineTo(22, -7)
          ..lineTo(12, 6)
          ..close(),
        Paint()..color = const Color(0xFF4DAEE0));
    c.drawArc(
        const Rect.fromLTWH(-10, -16, 16, 16),
        math.pi,
        math.pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = const Color(0xFF4DAEE0));
    c.drawRRect(
        body,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = const Color(0xFF2A86B8));
  }

  @override
  bool shouldRepaint(covariant GardenPropPainter old) =>
      old.prop != prop || old.tilt != tilt || old.clock != clock;
}

/// Confetti rơi một lần, [progress] 0..1.
class ConfettiPainter extends CustomPainter {
  ConfettiPainter(this.progress);
  final double progress;

  static const _colors = [
    Color(0xFFFF8FB1),
    Color(0xFFFFC928),
    Color(0xFF6EC6F5),
    Color(0xFF5DBB73),
    Color(0xFF9B87E8),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final rnd = math.Random(7);
    final fade = 1 - progress;
    for (var i = 0; i < 28; i++) {
      final x0 = rnd.nextDouble() * size.width;
      final drift = (rnd.nextDouble() - .5) * 40;
      final y = -10 + progress * size.height * (.7 + rnd.nextDouble() * .5);
      final spin = progress * 12 + i;
      canvas.save();
      canvas.translate(x0 + drift * progress, y);
      canvas.rotate(spin);
      canvas.drawRect(const Rect.fromLTWH(-3, -1.5, 6, 3),
          Paint()..color = _colors[i % _colors.length].withValues(alpha: fade));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant ConfettiPainter old) => old.progress != progress;
}
