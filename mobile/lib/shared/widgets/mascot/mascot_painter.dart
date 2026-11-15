import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'mascot_controller.dart';
import 'mascot_rig.dart';

// Màu lấy mẫu từ assets/icons/mascot-*.png.
class _C {
  static const white = Color(0xFFFFFFFF);
  static const white2 = Color(0xFFEEF2F7);
  static const blue = Color(0xFF1B9AFC);
  static const blue2 = Color(0xFF0A7FEF);
  static const blueLight = Color(0xFFB4E4FC);
  static const line = Color(0xFF1D5BB0);
  static const navy = Color(0xFF274280);
  static const eye = Color(0xFF0A1430);
  static const mouth = Color(0xFF840316);
  static const tongue = Color(0xFFFC3645);
  static const cheek = Color(0xFFFDB5B5);
  static const yellow = Color(0xFFFFC928);
  static const yellowLine = Color(0xFFE9A400);
  static const shield = Color(0xFF1FB489);
  static const shield2 = Color(0xFF139A73);
}

/// Vẽ linh vật trong khung 300×300 từ giá trị hiện tại của [rig].
class MascotPainter extends CustomPainter {
  MascotPainter(this.rig) : super(repaint: rig);

  final MascotRig rig;

  static final _body = RRect.fromRectAndRadius(
      const Rect.fromLTWH(83, 56, 134, 196), const Radius.circular(67));
  static final _star = Path()
    ..moveTo(0, -4)
    ..quadraticBezierTo(.9, -.9, 4, 0)
    ..quadraticBezierTo(.9, .9, 0, 4)
    ..quadraticBezierTo(-.9, .9, -4, 0)
    ..quadraticBezierTo(-.9, -.9, 0, -4)
    ..close();
  static final _burst = Path()
    ..moveTo(-4.5, 0)
    ..lineTo(4.5, 0)
    ..lineTo(6.5, -24)
    ..quadraticBezierTo(0, -28, -6.5, -24)
    ..close();

  Paint _fill(Color c, [double a = 1]) =>
      Paint()..color = c.withValues(alpha: c.a * a);

  @override
  void paint(Canvas canvas, Size size) {
    final r = rig;
    final pop = r.value('pop');
    if (pop < .01) return;
    final T = rig.time;
    canvas.save();
    canvas.scale(size.width / 300);
    // pop toàn thân quanh bàn chân
    canvas.translate(150, 262);
    canvas.scale(math.max(0, pop));
    canvas.translate(-150, -262);

    final y = r.value('y');
    final lift = (-y / 30).clamp(0.0, 1.0);
    canvas.drawOval(
        Rect.fromCenter(
            center: const Offset(150, 274),
            width: 116 * (1 - lift * .4),
            height: 16),
        _fill(_C.eye,
            .10 * (1 - lift * .5) * r.value('shadowA').clamp(0.0, 1.0)));

    _bursts(canvas, r.value('burst'), T, y);
    _zzz(canvas, r.value('zzz'), T);

    canvas.save();
    canvas.translate(0, y);
    _feet(canvas);

    canvas.save();
    final sq = r.value('sq');
    canvas.translate(150, 254);
    canvas.rotate(r.value('tilt'));
    canvas.scale(1 + sq, 1 - sq);
    canvas.translate(-150, -254);
    final behind = r.value('hw') > .5;
    if (behind) _arms(canvas, strokes: true, hands: false);
    _bodyShape(canvas);
    _cheeks(canvas, r.value('cheek'));
    _eyes(canvas, T);
    _mouth(canvas);
    _sweat(canvas, r.value('sweat'), T);
    _think(canvas, r.value('think'), T);
    _arms(canvas, strokes: !behind, hands: true);
    _shield(canvas, r.value('shield'));
    canvas.restore();
    canvas.restore();
    canvas.restore();
  }

  void _feet(Canvas c) {
    final navy = _fill(_C.navy);
    for (final x in [112.0, 166.0]) {
      c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(x, 236, 22, 22), const Radius.circular(9)),
          navy);
    }
    for (final x in [121.0, 179.0]) {
      c.drawOval(
          Rect.fromCenter(center: Offset(x, 260), width: 42, height: 22), navy);
      c.drawOval(
          Rect.fromCenter(center: Offset(x - 7, 256), width: 14, height: 6),
          _fill(_C.white, .18));
    }
  }

  void _bodyShape(Canvas c) {
    final b = _body.outerRect;
    c.drawRRect(
        _body,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_C.white, _C.white2],
          ).createShader(b));
    c.save();
    c.clipRRect(_body);
    final lower = Path()
      ..moveTo(73, 160)
      ..quadraticBezierTo(150, 179, 227, 160)
      ..lineTo(227, 262)
      ..lineTo(73, 262)
      ..close();
    c.drawPath(
        lower,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_C.blue, _C.blue2],
          ).createShader(const Rect.fromLTWH(73, 160, 154, 102)));
    c.drawRect(const Rect.fromLTWH(195, 50, 30, 212), _fill(_C.navy, .07));
    final hl = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    c.drawPath(
        Path()
          ..moveTo(98, 112)
          ..quadraticBezierTo(96, 90, 109, 74),
        hl
          ..color = _C.white.withValues(alpha: .9)
          ..strokeWidth = 7);
    c.drawPath(
        Path()
          ..moveTo(98, 194)
          ..quadraticBezierTo(98, 216, 105, 230),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 6
          ..color = _C.blueLight.withValues(alpha: .7));
    c.restore();
    c.drawRRect(
        _body,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..color = _C.line);
  }

  void _cheeks(Canvas c, double a) {
    for (final x in [104.0, 196.0]) {
      c.drawOval(Rect.fromCenter(center: Offset(x, 143), width: 23, height: 16),
          _fill(_C.cheek, a.clamp(0, 1)));
    }
  }

  void _eyes(Canvas c, double T) {
    final r = rig;
    final isCover = rig.mood == MascotMood.cover;
    final peek = rig.peek ? 1.0 : 0.0;
    final es = r.value('eyeS'),
        pd = r.value('pd'),
        lx = r.value('lx'),
        ly = r.value('ly');
    for (var i = 0; i < 2; i++) {
      final isR = i == 1;
      final sx = isR ? 176.0 : 124.0;
      const sy = 114.0;
      var open = r.value('open').clamp(0.0, 1.2) * r.blink;
      final peeking = isCover && isR && peek > .3;
      if (peeking) open = .9;
      if (isCover && !peeking) continue;
      final shut = open < .3;
      if (shut) {
        c.drawPath(
            Path()
              ..moveTo(sx - 10, 114)
              ..quadraticBezierTo(sx, 120, sx + 10, 114),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeCap = StrokeCap.round
              ..strokeWidth = 5
              ..color = _C.eye);
      } else {
        final socket = Rect.fromCenter(
            center: Offset(sx, sy), width: 25 * es, height: 32 * open * es);
        c.drawOval(socket, _fill(const Color(0xFF060B1E)));
        c.save();
        c.clipPath(Path()..addOval(socket));
        final ir = 9.6 * es;
        final g = Offset(sx + lx * 4.2 * es, sy + ly * 4.6 * es + 1.2);
        final irisRect = Rect.fromCircle(center: g, radius: ir);
        c.drawCircle(
            g,
            ir,
            Paint()
              ..shader = const RadialGradient(
                center: Alignment(0, .32),
                radius: .62,
                colors: [
                  Color(0xFF6FB0FF),
                  Color(0xFF2A62D6),
                  Color(0xFF0F2A72),
                  Color(0xFF081740)
                ],
                stops: [0, .42, .8, 1],
              ).createShader(irisRect));
        c.drawCircle(
            g,
            ir,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.6
              ..color = const Color(0xFF040918));
        c.drawOval(
            Rect.fromCenter(
                center: g + Offset(lx * .6, ly * .4),
                width: 9.2 * es * pd,
                height: 10.4 * es * pd),
            _fill(const Color(0xFF01030C)));
        c.drawOval(
            Rect.fromCenter(
                center: g + Offset(0, ir * .6),
                width: ir * 1.44,
                height: ir * .72),
            _fill(const Color(0xFFA6CEFF), .55));
        c.restore();
        c.drawOval(
            socket,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5
              ..color = _C.eye);
        if (open >= .55) {
          // điểm sáng gần như đứng yên khi con ngươi đảo → mắt "ướt", long lanh
          final hx = sx + lx * .8, hy = sy + ly * .6;
          final tw = 1 + .07 * math.sin(T * 3.1 + i);
          final o = open.clamp(0.0, 1.0);
          c.save();
          c.translate(hx - 4.6 * es, hy - 6 * es * o);
          c.rotate(-25 * math.pi / 180);
          c.drawOval(
              Rect.fromCenter(
                  center: Offset.zero,
                  width: 10 * tw * es,
                  height: 12 * tw * es * math.min(1, o * 1.2)),
              _fill(_C.white));
          c.restore();
          c.drawCircle(Offset(hx + 4.8 * es, hy + 5.5 * es * o), 2.3 * es,
              _fill(_C.white));
          final twinkle = math.max(0.0, math.sin(T * 2.6 + i * 1.7));
          c.save();
          c.translate(hx + 5.6 * es, hy - 7.8 * es * o);
          c.rotate((T * 50 + i * 40) * math.pi / 180);
          final sc = (.45 + .55 * twinkle) * (1 + .7 * r.value('star'));
          c.scale(sc);
          c.drawPath(_star, _fill(_C.white, .5 + .5 * twinkle));
          c.restore();
        }
      }
      // lông mày
      final brow = r.value('brow').clamp(0.0, 1.0);
      if (brow > .02) {
        final by = 90 + r.value('browY') + (isR ? r.value('browRY') : 0);
        c.save();
        c.translate(sx, by);
        c.rotate((isR ? 1 : -1) * r.value('browT') * math.pi / 180);
        c.drawLine(
            const Offset(-8, 0),
            const Offset(8, 0),
            Paint()
              ..strokeWidth = 4
              ..strokeCap = StrokeCap.round
              ..color = _C.eye.withValues(alpha: brow));
        c.restore();
      }
    }
  }

  void _mouth(Canvas c) {
    final r = rig;
    final smile = r.value('smile'), mo = r.value('mopen'), w = r.value('mw');
    const cx = 150.0;
    final cy0 = 143 - smile * 2;
    if (mo < .08) {
      c.drawPath(
          Path()
            ..moveTo(cx - w, cy0)
            ..quadraticBezierTo(cx, cy0 + smile * 12, cx + w, cy0),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4
            ..strokeCap = StrokeCap.round
            ..color = _C.eye);
      return;
    }
    final ww = w * (1 + mo * .35);
    final lowY = cy0 + math.max(-4.0, smile * 6) + mo * 24;
    final upY = cy0 + math.max(0.0, smile) * 2.5;
    final p = Path()
      ..moveTo(cx - ww, cy0)
      ..cubicTo(cx - ww * .8, lowY, cx + ww * .8, lowY, cx + ww, cy0)
      ..quadraticBezierTo(cx, upY, cx - ww, cy0)
      ..close();
    c.drawPath(p, _fill(_C.mouth));
    c.drawPath(
        p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round
          ..color = _C.mouth);
    if (mo > .2) {
      c.save();
      c.clipPath(p);
      c.drawOval(
          Rect.fromCenter(
              center: Offset(cx + 2, lowY - 4),
              width: ww * 1.24,
              height: 8 + mo * 14),
          _fill(_C.tongue));
      c.restore();
    }
  }

  void _arms(Canvas c, {required bool strokes, required bool hands}) {
    final r = rig;
    final hw = r.value('hw'), y = r.value('y');
    final navy = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 21
      ..strokeCap = StrokeCap.round
      ..color = _C.navy;
    for (final (sx, sy, side, hx, hy) in [
      (93.0, 190.0, -1.0, r.value('hlx'), r.value('hly') - hw * y),
      (207.0, 190.0, 1.0, r.value('hrx'), r.value('hry') - hw * y),
    ]) {
      final mx = (sx + hx) / 2, my = (sy + hy) / 2;
      final dx = hx - sx,
          dy = hy - sy,
          len = math.max(1.0, math.sqrt(dx * dx + dy * dy));
      final bend = 8 * side;
      if (strokes) {
        c.drawPath(
            Path()
              ..moveTo(sx, sy)
              ..quadraticBezierTo(
                  mx + dy / len * bend, my - dx / len * bend, hx, hy),
            navy);
      }
      if (hands) {
        c.drawCircle(Offset(hx, hy), 15.5, _fill(_C.navy));
        c.drawCircle(Offset(hx - 4, hy - 4), 3.5, _fill(_C.white, .2));
      }
    }
  }

  void _shield(Canvas c, double a) {
    if (a < .02) return;
    final r = rig;
    c.save();
    c.translate(r.value('hlx') - 14, r.value('hly') - 22);
    c.rotate(-10 * math.pi / 180);
    c.scale(1.05 + .3 * a);
    final p = Path()
      ..moveTo(0, -30)
      ..quadraticBezierTo(16, -20, 30, -22)
      ..quadraticBezierTo(32, 12, 0, 32)
      ..quadraticBezierTo(-32, 12, -30, -22)
      ..quadraticBezierTo(-16, -20, 0, -30)
      ..close();
    c.drawPath(
        p,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _C.shield.withValues(alpha: a),
              _C.shield2.withValues(alpha: a)
            ],
          ).createShader(const Rect.fromLTRB(-32, -30, 32, 32)));
    c.drawPath(
        p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0xFFE6F6FF).withValues(alpha: a));
    c.drawPath(
        p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = _C.line.withValues(alpha: a));
    final cross = Path()
      ..addRect(const Rect.fromLTWH(-4, -14, 8, 28))
      ..addRect(const Rect.fromLTWH(-14, -4, 28, 8));
    c.drawPath(cross, _fill(_C.white, a));
    c.restore();
  }

  void _bursts(Canvas c, double a, double T, double y) {
    if (a < .02) return;
    const defs = [
      (50.0, 100.0, -40.0),
      (36.0, 140.0, -72.0),
      (250.0, 100.0, 40.0),
      (264.0, 140.0, 72.0)
    ];
    for (var i = 0; i < defs.length; i++) {
      final (x, by, rot) = defs[i];
      final pulse = 1 + .12 * math.sin(T * 9 + i);
      c.save();
      c.translate(x, by + y * .4);
      c.rotate(rot * math.pi / 180);
      c.scale(pulse * (.6 + .4 * a.clamp(0, 1.3)));
      c.drawPath(_burst, _fill(_C.yellow, a.clamp(0, 1)));
      c.drawPath(
          _burst,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..strokeJoin = StrokeJoin.round
            ..color = _C.yellowLine.withValues(alpha: a.clamp(0, 1)));
      c.restore();
    }
  }

  void _zzz(Canvas c, double a, double T) {
    if (a < .02) return;
    for (var i = 0; i < 3; i++) {
      final ph = (T * .45 + i / 3) % 1;
      final tp = TextPainter(
        text: TextSpan(
          text: 'z',
          style: TextStyle(
            fontSize: 18.0 + i * 5,
            fontWeight: FontWeight.w800,
            color: _C.navy.withValues(alpha: a * math.sin(ph * math.pi)),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(c, Offset(216 + ph * 30 + i * 4, 56 - ph * 50));
    }
  }

  void _sweat(Canvas c, double a, double T) {
    if (a < .02) return;
    c.save();
    c.translate(214, 84 + (T * .8 % 1) * 10);
    final p = Path()
      ..moveTo(0, -13)
      ..quadraticBezierTo(9, 0, 0, 7)
      ..quadraticBezierTo(-9, 0, 0, -13)
      ..close();
    c.drawPath(p, _fill(const Color(0xFF8FD3F0), a));
    c.drawPath(
        p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = _C.line.withValues(alpha: a));
    c.restore();
  }

  void _think(Canvas c, double a, double T) {
    if (a < .02) return;
    const dots = [(226.0, 78.0, 4.0), (240.0, 60.0, 6.0), (258.0, 38.0, 9.0)];
    for (var i = 0; i < dots.length; i++) {
      final (x, y, rr) = dots[i];
      final o = a * (.35 + .65 * math.max(0.0, math.sin(T * 4 - i * .9)));
      c.drawCircle(Offset(x, y), rr, _fill(_C.white, o));
      c.drawCircle(
          Offset(x, y),
          rr,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..color = _C.line.withValues(alpha: o));
    }
  }

  @override
  bool shouldRepaint(covariant MascotPainter old) => old.rig != rig;
}
