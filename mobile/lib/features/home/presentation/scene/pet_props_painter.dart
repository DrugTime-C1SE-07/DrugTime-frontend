import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import 'chibi_painter.dart';
import 'chibi_pet.dart';
import 'pet_body.dart';
import 'pet_brain.dart';

/// Vẽ pet trong banner: bóng đổ theo nguồn sáng, thân pet chibi ([ChibiPainter]) và đạo cụ trong bong bóng.
class PetScenePainter extends CustomPainter {
  PetScenePainter({
    required this.brain,
    required this.rig,
    required this.light,
    required this.lightStrength,
    required this.propAge,
    required this.opacity,
    super.repaint,
  }) : _pet = ChibiPainter(rig);

  final PetBrain brain;
  final ChibiRig rig;
  final ChibiPainter _pet;

  /// Vị trí nguồn sáng (mặt trời, hoặc mặt trăng ban đêm), `null` nếu không có.
  final Offset? Function() light;
  final double Function() lightStrength;

  /// Số giây kể từ khi đạo cụ hiện tại xuất hiện (cho confetti).
  final double Function() propAge;
  final double Function() opacity;

  /// Cạnh khung 100×100 của pet theo dp: thân (y 24..96, 72 đơn vị) cao [PetBody.height].
  static const box = PetBody.height * 100 / 72;
  static const _s = box / 100;

  /// Khung chạm của pet (đứng hoặc nằm).
  static Rect hitRect(PetBody body, {required bool lying}) => lying
      ? Rect.fromCenter(
          center: body.feet - const Offset(0, 30 * _s),
          width: 76 * _s,
          height: 60 * _s)
      : body.rect.inflate(6);

  /// Tâm bong bóng đạo cụ (trên đầu, lệch về hướng mặt).
  static Offset bubbleCenter(PetBody body) =>
      body.feet + Offset(body.facing * 22, -PetBody.height - 22);

  /// Khung chăn và gối khi pet nằm ngủ (đầu bên phải).
  static Rect pillowRect(PetBody body) => Rect.fromLTRB(body.feet.dx + 22 * _s,
      body.feet.dy - 16 * _s, body.feet.dx + 54 * _s, body.feet.dy + 2);
  static Rect blanketRect(PetBody body) => Rect.fromLTRB(body.feet.dx - 42 * _s,
      body.feet.dy - 40 * _s, body.feet.dx + 12 * _s, body.feet.dy + 2);

  @override
  void paint(Canvas canvas, Size size) {
    final o = opacity();
    if (o < .01) return;
    final body = brain.body;
    final f = body.feet;
    if (o < 1) {
      canvas.saveLayer(
          Offset.zero & size, Paint()..color = Color.fromRGBO(0, 0, 0, o));
    }

    // bóng đổ dài ngược phía nguồn sáng
    final l = light();
    final k = lightStrength();
    if (l != null && k > .05 && rig.value('pop') > .5) {
      final dx = f.dx - l.dx;
      final dy = (f.dy - l.dy).abs() + 30;
      final len = (24 * dx.abs() / dy).clamp(4.0, 46.0);
      canvas.save();
      canvas.translate(f.dx, f.dy - 1);
      canvas.drawOval(
          Rect.fromLTWH(dx >= 0 ? -6 : -len - 18, -3.5, len + 24, 7),
          Paint()
            ..color = const Color(0xFF0A1430).withValues(alpha: .16 * k)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5));
      canvas.restore();
    }

    canvas.save();
    canvas.translate(f.dx, f.dy - PetBody.height / 2);
    if (brain.spin != 0) canvas.rotate(brain.spin);
    canvas.translate(-50 * _s, PetBody.height / 2 - 96 * _s);
    canvas.scale(_s);
    _pet.paint(canvas);
    canvas.restore();

    _prop(canvas, f, body.facing);
    if (brain.hearts) _hearts(canvas, f);
    final say = brain.speech;
    if (say != null) _speech(canvas, f, say, size);
    if (o < 1) canvas.restore();
  }

  void _prop(Canvas c, Offset f, double facing) {
    final b = bubbleCenter(brain.body);
    switch (brain.prop) {
      case PetProp.none:
        return;
      case PetProp.clock:
        _bubble(c, b, f);
        _clock(c, b);
      case PetProp.cloud:
        _bubble(c, b, f);
        _syncCloud(c, b + const Offset(0, 1));
      case PetProp.magnifier:
        _bubble(c, b, f);
        _magnifier(c, b + const Offset(-2, -2));
      case PetProp.pillBox:
        _bubble(c, b, f);
        _pillBox(c, b);
      case PetProp.flag:
        _flag(c, f + Offset(facing * 26, 0));
      case PetProp.confetti:
        _confetti(c, f + const Offset(0, -PetBody.height * .6), propAge());
    }
  }

  /// Bong bóng lời thoại: bên trái đầu pet (pet quay về phía nút), phía trên đầu phải của nút,
  /// đuôi chỉ về miệng pet — nối pet với nút thành một cụm.
  void _speech(Canvas c, Offset feet, String text, Size size) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
            color: Color(0xFF19231F),
            fontSize: 13,
            fontWeight: FontWeight.w700,
            height: 1.25),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 2,
    )..layout(maxWidth: 150);
    const padX = 12.0, padY = 8.0;
    final w = tp.width + padX * 2, h = tp.height + padY * 2;
    final mouth = feet + const Offset(-14, -PetBody.height * .58);
    final right = feet.dx - 26;
    final bottom = feet.dy - PetBody.height * .62;
    final left =
        (right - w).clamp(8.0, math.max(8.0, size.width - w - 8)).toDouble();
    final box = Rect.fromLTWH(left, bottom - h, w, h);
    final bubble = RRect.fromRectAndRadius(box, const Radius.circular(14));
    final tail = Path()
      ..moveTo(box.right - 16, box.bottom - 2)
      ..quadraticBezierTo(box.right + 2, box.bottom + 2, mouth.dx, mouth.dy)
      ..quadraticBezierTo(
          box.right - 2, box.bottom - 6, box.right - 4, box.center.dy)
      ..close();
    c.drawRRect(
        bubble.shift(const Offset(0, 2)),
        Paint()
          ..color = const Color(0xFF0A1430).withValues(alpha: .14)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    final fill = Paint()..color = const Color(0xFFFFFFFF);
    c.drawPath(tail, fill);
    c.drawRRect(bubble, fill);
    tp.paint(c, Offset(box.left + padX, box.top + padY));
  }

  /// Bong bóng tròn trắng có đuôi chỉ về đầu pet.
  void _bubble(Canvas c, Offset center, Offset feet) {
    const r = 17.0;
    final head = feet + const Offset(0, -PetBody.height + 4);
    final dir = (head - center) / (head - center).distance;
    final side = Offset(-dir.dy, dir.dx);
    final tail = Path()
      ..moveTo(center.dx + side.dx * 6, center.dy + side.dy * 6)
      ..lineTo(center.dx + dir.dx * (r + 8), center.dy + dir.dy * (r + 8))
      ..lineTo(center.dx - side.dx * 6, center.dy - side.dy * 6)
      ..close();
    final shadow = Paint()
      ..color = const Color(0xFF0A1430).withValues(alpha: .14)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    c.drawCircle(center + const Offset(0, 2), r, shadow);
    final fill = Paint()..color = const Color(0xFFFFFFFF);
    c.drawPath(tail, fill);
    c.drawCircle(center, r, fill);
  }

  static final _ink = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2
    ..strokeCap = StrokeCap.round
    ..color = const Color(0xFF274280);

  void _clock(Canvas c, Offset p) {
    c.drawCircle(p, 10, Paint()..color = const Color(0xFFFFFFFF));
    c.drawCircle(p, 10, _ink);
    final now = DateTime.now();
    final m = now.minute / 60 * 2 * math.pi,
        h = (now.hour % 12 + now.minute / 60) / 12 * 2 * math.pi;
    c.drawLine(p, p + Offset(math.sin(h), -math.cos(h)) * 5, _ink);
    c.drawLine(p, p + Offset(math.sin(m), -math.cos(m)) * 7.5, _ink);
    c.drawCircle(p + const Offset(-7, -10), 2.6,
        Paint()..color = const Color(0xFFF59E42));
    c.drawCircle(p + const Offset(7, -10), 2.6,
        Paint()..color = const Color(0xFFF59E42));
  }

  void _syncCloud(Canvas c, Offset p) {
    final fill = Paint()..color = const Color(0xFFFFFFFF);
    for (final (d, r) in [
      (const Offset(-7, 2), 6.5),
      (const Offset(0, -3), 8.5),
      (const Offset(8, 2), 6.0)
    ]) {
      c.drawCircle(p + d, r, fill);
    }
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: p + const Offset(0, 4), width: 30, height: 10),
            const Radius.circular(5)),
        fill);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..color = const Color(0xFF1B9AFC);
    c.drawArc(Rect.fromCircle(center: p + const Offset(0, 1), radius: 4.5),
        brain.now * 3.3 % (2 * math.pi), 4.4, false, arc);
  }

  void _magnifier(Canvas c, Offset p) {
    c.drawLine(
        p + const Offset(6, 6),
        p + const Offset(13, 13),
        Paint()
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFF8A5A2B));
    c.drawCircle(
        p, 8.5, Paint()..color = const Color(0xFFDDF1FF).withValues(alpha: .8));
    c.drawCircle(p, 8.5, _ink..strokeWidth = 2.4);
    _ink.strokeWidth = 2;
  }

  void _pillBox(Canvas c, Offset p) {
    final r = RRect.fromRectAndRadius(
        Rect.fromCenter(center: p, width: 26, height: 18),
        const Radius.circular(5));
    c.drawRRect(r, Paint()..color = const Color(0xFFFFFFFF));
    c.drawRRect(r, _ink);
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: p, width: 14, height: 6),
            const Radius.circular(3)),
        Paint()..color = const Color(0xFFF59E42));
  }

  void _flag(Canvas c, Offset base) {
    final top = base + const Offset(0, -46);
    c.drawLine(
        base,
        top,
        Paint()
          ..strokeWidth = 2.5
          ..color = const Color(0xFF6B4A2B));
    final wave = math.sin(brain.now * 6) * 3;
    final flag = Path()
      ..moveTo(top.dx, top.dy)
      ..quadraticBezierTo(
          top.dx + 12, top.dy + 2 + wave, top.dx + 24, top.dy + 6)
      ..lineTo(top.dx, top.dy + 16)
      ..close();
    c.drawPath(flag, Paint()..color = const Color(0xFFFF5D5D));
    c.drawCircle(top, 2.5, Paint()..color = const Color(0xFFFFC928));
  }

  static const _confettiColors = [
    Color(0xFFFF5D7A),
    Color(0xFFFFC928),
    Color(0xFF1B9AFC),
    Color(0xFF1FB489),
    Color(0xFF8B5CF6),
  ];

  void _confetti(Canvas c, Offset o, double age) {
    if (age > 2.6) return;
    final r = math.Random(11);
    for (var i = 0; i < 26; i++) {
      final ang = -math.pi / 2 + (r.nextDouble() - .5) * math.pi * 1.3;
      final speed = 120 + r.nextDouble() * 140;
      final p = o +
          Offset(math.cos(ang) * speed * age,
              math.sin(ang) * speed * age + 260 * age * age);
      c.save();
      c.translate(p.dx, p.dy);
      c.rotate(age * (4 + i % 5));
      c.drawRect(
          const Rect.fromLTWH(-3, -1.5, 6, 3),
          Paint()
            ..color = _confettiColors[i % _confettiColors.length]
                .withValues(alpha: (1 - age / 2.6).clamp(0.0, 1.0)));
      c.restore();
    }
  }

  void _hearts(Canvas c, Offset f) {
    final t = brain.now;
    for (var i = 0; i < 3; i++) {
      final ph = (t * .7 + i / 3) % 1;
      final p = f +
          Offset(10 + i * 9 + math.sin(ph * 6) * 3,
              -PetBody.height * .7 - ph * 30);
      c.save();
      c.translate(p.dx, p.dy);
      c.scale(.55 + .25 * math.sin(ph * math.pi));
      final path = Path()
        ..moveTo(0, 6)
        ..cubicTo(-14, -4, -8, -16, 0, -8)
        ..cubicTo(8, -16, 14, -4, 0, 6)
        ..close();
      c.drawPath(
          path,
          Paint()
            ..color = const Color(0xFFFF5D7A)
                .withValues(alpha: math.sin(ph * math.pi)));
      c.restore();
    }
  }

  @override
  bool shouldRepaint(PetScenePainter old) =>
      old.brain != brain || old.rig != rig;
}
