import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../shared/widgets/pill_glyph.dart';

/// Nền "Bầu trời viên thuốc": thế giới của linh vật.
/// Cùng bảng màu (xanh nhạt–trắng–navy, nhấn vàng), cùng hình khối bo tròn,
/// viên thuốc vẽ thật bay ở nhiều độ sâu; nảy lên khi linh vật ăn mừng ([kick]).
class PillSkyScenePainter extends CustomPainter {
  PillSkyScenePainter(
      {required this.entrance, required this.time, required this.kick})
      : super(repaint: Listenable.merge([entrance, time]));

  final Animation<double> entrance;
  final ValueNotifier<double> time;

  /// Thời điểm (theo [time]) linh vật bắt đầu ăn mừng; âm = chưa có.
  final ValueNotifier<double> kick;

  static const skyTop = Color(0xFFCFE8FF);
  static const skyMid = Color(0xFFE6F3FF);
  static const skyBottom = Color(0xFFF6FAFF);

  /// (x, y, kích thước, độ sâu 0..1, look). Độ sâu thấp = xa, nhỏ, nhạt, trôi chậm.
  /// Bố cục 3 tầng, đối xứng hai bên linh vật (x, y, kích thước, độ sâu, look).
  /// Gần: 2 viên to bằng nhau cạnh thân. Giữa: 2 viên vừa. Xa: 2 viên nhỏ, nhạt ở góc trên.
  static const _pills = <(double, double, double, double, PillLook)>[
    (
      30,
      92,
      22,
      .35,
      PillLook(PillShape.softgel, Color(0xFFE09A2A), angle: .45)
    ),
    (330, 86, 22, .35, PillLook(PillShape.round, Color(0xFFA9CCF0), angle: 0)),
    (74, 150, 34, .65, PillLook(PillShape.round, Color(0xFFF2DE8C), angle: 0)),
    (
      288,
      144,
      34,
      .65,
      PillLook(PillShape.oval, Color(0xFFF7F4EE), angle: -.5)
    ),
    (
      56,
      240,
      46,
      .95,
      PillLook(PillShape.capsule, Color(0xFF1B9AFC),
          color2: Color(0xFFF7F9FC), angle: -.55)
    ),
    (
      306,
      236,
      46,
      .95,
      PillLook(PillShape.roundScored, Color(0xFFF4F1EA), angle: .3)
    ),
  ];

  /// Tỉ lệ khung thiết kế 360×380 → [size]: vừa cả hai chiều để không bị cắt phía trên
  /// (chữ logo không bị viên thuốc đè). Khung căn giữa ngang và neo theo đáy.
  static double designScale(Size size) =>
      math.min(size.width / 360, size.height / 380);

  double _iv(double a, double b, Curve c) =>
      c.transform(((entrance.value - a) / (b - a)).clamp(0.0, 1.0));

  @override
  void paint(Canvas canvas, Size size) {
    final T = time.value;
    final rect = Offset.zero & size;
    canvas.drawRect(
        rect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [skyTop, skyMid, skyBottom],
            stops: [0, .55, 1],
          ).createShader(rect));

    final s = designScale(size);
    canvas.save();
    canvas.translate((size.width - 360 * s) / 2, size.height - 380 * s);
    canvas.scale(s);

    // quầng sáng mềm phía sau linh vật
    final glow = _iv(.1, .6, Curves.easeOut);
    canvas.drawCircle(
        const Offset(180, 230),
        150 * (1 + .03 * math.sin(T * 1.2)),
        Paint()
          ..shader = RadialGradient(colors: [
            Colors.white.withValues(alpha: .85 * glow),
            Colors.white.withValues(alpha: 0),
          ]).createShader(
              Rect.fromCircle(center: const Offset(180, 230), radius: 150)));

    // mây xa
    final cloudIn = _iv(.0, .45, Curves.easeOutCubic);
    _cloud(canvas, Offset(70 + math.sin(T * .1) * 10, 176), .8, .55 * cloudIn);
    _cloud(canvas, Offset(286 + math.sin(T * .09 + 2) * 10, 118), .65,
        .5 * cloudIn);

    // viên thuốc xa (vẽ trước)
    final kickAge = kick.value < 0 ? 99.0 : T - kick.value;
    final order = [for (var i = 0; i < _pills.length; i++) i]
      ..sort((a, b) => _pills[a].$4.compareTo(_pills[b].$4));
    for (final i in order) {
      final (x, y, sz, depth, look) = _pills[i];
      if (depth > .6) continue;
      _pill(canvas, i, x, y, sz, depth, look, T, kickAge);
    }

    // dải mây làm "mặt đất"
    final bank = _iv(.15, .6, Curves.easeOutCubic);
    canvas.save();
    canvas.translate(0, (1 - bank) * 90);
    final bankPaint = Paint()..color = Colors.white.withValues(alpha: .95);
    final shade = Paint()..color = const Color(0xFFE1EEFB);
    for (var k = 0; k < 9; k++) {
      final cx = -10 + k * 47.0;
      final r = 34 + (k % 3) * 8.0;
      final cy = 330 + math.sin(k * 1.7) * 6 + math.sin(T * .6 + k) * 1.5;
      canvas.drawCircle(Offset(cx, cy + 6), r, shade);
      canvas.drawCircle(Offset(cx, cy), r, bankPaint);
    }
    canvas.drawRect(const Rect.fromLTWH(-20, 336, 400, 200), bankPaint);
    canvas.restore();

    // cụm mây bồng bềnh dưới chân linh vật
    final mound = _iv(.2, .62, Curves.easeOutBack);
    canvas.save();
    canvas.translate(180, 340 + (1 - mound) * 70);
    canvas.scale(.7 + .3 * mound);
    final puff = Paint()..color = Colors.white;
    final puffShade = Paint()..color = const Color(0xFFDCEAF8);
    const puffs = [
      (-62.0, 10.0, 30.0),
      (-30.0, -6.0, 36.0),
      (8.0, -14.0, 40.0),
      (46.0, -4.0, 34.0),
      (74.0, 10.0, 26.0)
    ];
    for (final (x, y, r) in puffs) {
      canvas.drawCircle(Offset(x, y + 7), r, puffShade);
    }
    for (var k = 0; k < puffs.length; k++) {
      final (x, y, r) = puffs[k];
      canvas.drawCircle(Offset(x, y + math.sin(T * .8 + k) * 1.2), r, puff);
    }
    canvas.drawLine(
        const Offset(-14, -42),
        const Offset(14, -46),
        Paint()
          ..color = const Color(0xFFEFF6FD)
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round);
    canvas.restore();

    // viên thuốc gần
    for (final i in order) {
      final (x, y, sz, depth, look) = _pills[i];
      if (depth <= .6) continue;
      _pill(canvas, i, x, y, sz, depth, look, T, kickAge);
    }

    // sao vàng lấp lánh (cùng màu tia vàng của linh vật)
    final st = _iv(.6, .95, Curves.easeOutBack);
    const stars = [(124.0, 112.0, .8), (236.0, 108.0, .8), (174.0, 200.0, .5)];
    for (var k = 0; k < stars.length; k++) {
      final (x, y, sc) = stars[k];
      final tw = math.max(0.0, math.sin(T * 1.8 + k * 1.9));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(T * .4 + k);
      canvas.scale(sc * st * (.5 + .6 * tw));
      final p = Path()
        ..moveTo(0, -9)
        ..quadraticBezierTo(1.8, -1.8, 9, 0)
        ..quadraticBezierTo(1.8, 1.8, 0, 9)
        ..quadraticBezierTo(-1.8, 1.8, -9, 0)
        ..quadraticBezierTo(-1.8, -1.8, 0, -9)
        ..close();
      canvas.drawPath(
          p,
          Paint()
            ..color =
                const Color(0xFFFFC928).withValues(alpha: .35 + .55 * tw));
      canvas.restore();
    }
    canvas.restore();
  }

  void _pill(Canvas canvas, int i, double x, double y, double sz, double depth,
      PillLook look, double T, double kickAge) {
    // hiện ra theo cặp (trái/phải cùng lúc), từ xa đến gần
    final pair = i ~/ 2;
    final appear = _iv(.4 + pair * .08, .72 + pair * .08, Curves.easeOutBack);
    if (appear <= 0) return;
    // lơ lửng chậm, nhẹ; hai viên trong cặp lệch pha để không nhún cùng nhịp
    final ph = i * 1.7;
    final bob = math.sin(T * .7 + ph) * (2.5 + depth * 2);
    final drift = math.sin(T * .33 + ph) * 1.5;
    final tilt = math.sin(T * .5 + ph) * .05;
    // nảy nhẹ khi linh vật tiếp đất, viên gần nảy trước
    final a = kickAge - (2 - pair) * .06;
    final hop = a > 0 && a < 1.2
        ? -math.sin(a * 7).abs() * 8 * depth * math.exp(-a * 3)
        : 0.0;
    final sc = sz * appear;
    canvas.save();
    canvas.translate(x + drift, y + bob + hop);
    final painter = PillGlyphPainter(PillLook(look.shape, look.color,
        color2: look.color2, angle: look.angle + tilt));
    final alpha = .6 + .4 * depth;
    if (alpha < .99) {
      canvas.saveLayer(
          Rect.fromCenter(
              center: Offset.zero, width: sc * 1.6, height: sc * 1.6),
          Paint()..color = Color.fromRGBO(255, 255, 255, alpha));
    }
    canvas.translate(-sc / 2, -sc / 2);
    painter.paint(canvas, Size.square(sc));
    if (alpha < .99) canvas.restore();
    canvas.restore();
  }

  void _cloud(Canvas c, Offset o, double sc, double a) {
    if (a <= 0) return;
    final p = Paint()..color = Colors.white.withValues(alpha: a);
    c.save();
    c.translate(o.dx, o.dy);
    c.scale(sc);
    c.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(-44, -6, 88, 24), const Radius.circular(12)),
        p);
    c.drawCircle(const Offset(-12, -6), 18, p);
    c.drawCircle(const Offset(14, -2), 14, p);
    c.restore();
  }

  @override
  bool shouldRepaint(covariant PillSkyScenePainter old) => false;
}
