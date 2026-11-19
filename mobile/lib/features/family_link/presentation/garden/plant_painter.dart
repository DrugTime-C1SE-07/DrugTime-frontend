import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'garden_mood.dart';

/// Một chậu cây. [shape] đi theo dữ liệu; [wobble] (0..1, giảm dần) là độ lắc khi người
/// dùng chạm hoặc tưới, chỉ là hiệu ứng, không đổi [shape]. Khung vẽ 100×120.
class PlantPainter extends CustomPainter {
  PlantPainter(
      {required this.shape,
      required this.clock,
      this.wobble = 0,
      this.drops = 0,
      this.petals = 0,
      this.accent = const Color(0xFFFF8FB1)})
      : super(repaint: clock);

  final PlantShape shape;
  final ValueNotifier<double> clock;
  final double wobble, drops, petals;

  /// Màu hoa, khác nhau giữa các chậu.
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final t = clock.value;
    canvas.save();
    canvas.scale(size.width / 100, size.height / 120);

    // chậu đất nung
    final pot = Path()
      ..moveTo(26, 82)
      ..lineTo(74, 82)
      ..lineTo(68, 116)
      ..quadraticBezierTo(50, 120, 32, 116)
      ..close();
    canvas.drawOval(const Rect.fromLTWH(24, 112, 52, 8),
        Paint()..color = Colors.black.withValues(alpha: .08));
    canvas.drawPath(pot, Paint()..color = const Color(0xFFD9825B));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(22, 76, 56, 10), const Radius.circular(4)),
        Paint()..color = const Color(0xFFE79A72));
    canvas.drawOval(const Rect.fromLTWH(28, 78, 44, 6),
        Paint()..color = const Color(0xFF7A4B32));

    if (shape != PlantShape.emptyPot) {
      final sway = math.sin(t * 1.6) * .04 + math.sin(t * 18) * .12 * wobble;
      final droop = switch (shape) {
        PlantShape.droop => .55,
        PlantShape.revive => .15 + .1 * math.sin(t * 2).abs(),
        _ => 0.0,
      };
      canvas.save();
      canvas.translate(50, 80);
      canvas.rotate(sway);
      _stem(canvas, droop);
      canvas.restore();
    } else {
      // vòng chấm mờ: chỗ chờ "trồng" người thân
      final dot = Paint()
        ..color = const Color(0xFF5B3FA8).withValues(alpha: .35);
      for (var i = 0; i < 10; i++) {
        final a = i / 10 * math.pi * 2 + t * .3;
        canvas.drawCircle(
            Offset(50 + math.cos(a) * 18, 56 + math.sin(a) * 18), 2, dot);
      }
    }

    // giọt nước khi tưới
    if (drops > .01) {
      final water = Paint()
        ..color = const Color(0xFF6EC6F5).withValues(alpha: drops);
      for (var i = 0; i < 5; i++) {
        final y = 20 + ((t * 80 + i * 13) % 50);
        canvas.drawOval(
            Rect.fromCenter(
                center: Offset(34 + i * 8.0, y), width: 4, height: 7),
            water);
      }
    }
    // cánh hoa rơi khi chạm
    if (petals > .01 && shape != PlantShape.emptyPot) {
      final p = Paint()..color = accent.withValues(alpha: petals);
      for (var i = 0; i < 4; i++) {
        final fall = (1 - petals) * 40;
        canvas.drawOval(
            Rect.fromCenter(
                center: Offset(36 + i * 9.0 + math.sin(fall / 8 + i) * 4,
                    30 + fall + i * 3),
                width: 6,
                height: 4),
            p);
      }
    }
    canvas.restore();
  }

  void _stem(Canvas c, double droop) {
    final green = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF3E9B5B);
    // ngọn cây cong xuống theo độ rũ
    final tip = Offset(14 * droop, -60 + 26 * droop);
    c.drawPath(
        Path()
          ..moveTo(0, 0)
          ..quadraticBezierTo(-4, -30, tip.dx, tip.dy),
        green);
    final leaf = Paint()..color = const Color(0xFF5DBB73);
    for (final (y, side) in [(-18.0, -1.0), (-30.0, 1.0)]) {
      c.save();
      c.translate(-2, y);
      c.rotate(side * (.9 + droop * .6));
      c.drawOval(const Rect.fromLTWH(0, -5, 20, 10), leaf);
      c.restore();
    }
    // hoa: nở khi tươi, khép khi rũ
    final open = 1 - droop;
    c.save();
    c.translate(tip.dx, tip.dy);
    for (var i = 0; i < 5; i++) {
      final a = i / 5 * math.pi * 2;
      c.drawCircle(Offset(math.cos(a) * 7 * open, math.sin(a) * 7 * open),
          5 + 2 * open, Paint()..color = accent);
    }
    c.drawCircle(Offset.zero, 4.5, Paint()..color = const Color(0xFFFFD45C));
    c.restore();
  }

  @override
  bool shouldRepaint(covariant PlantPainter old) =>
      old.shape != shape ||
      old.wobble != wobble ||
      old.drops != drops ||
      old.petals != petals ||
      old.accent != accent;
}
