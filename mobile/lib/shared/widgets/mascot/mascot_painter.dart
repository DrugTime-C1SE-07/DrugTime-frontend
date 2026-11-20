import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'mascot_controller.dart';
import 'mascot_rig.dart';

// Màu lấy mẫu từ assets/icons/mascot-*.png.
class _C {
  static const white = Color(0xFFFFFFFF);
  static const white2 = Color(0xFFEEF2F7);
  // Màu thân dưới nằm ở MascotPalette; `line` vẫn là viền của các phụ kiện.
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
  MascotPainter(this.rig,
      {this.outfit = MascotOutfit.plain, this.palette = MascotPalette.blue})
      : super(repaint: rig);

  final MascotRig rig;
  final MascotOutfit outfit;
  final MascotPalette palette;

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
    if (outfit == MascotOutfit.chef) {
      _arms(canvas, strokes: !behind, hands: false);
      _bowl(canvas, T);
      _arms(canvas, strokes: false, hands: true);
      _hat(canvas);
      _sparkles(canvas, r.value('spark'), T);
    } else if (outfit == MascotOutfit.medic) {
      _stethoscope(canvas);
      _arms(canvas, strokes: !behind, hands: true);
      _nurseCap(canvas);
    } else if (outfit == MascotOutfit.gardenHat) {
      _arms(canvas, strokes: !behind, hands: true);
      _strawHat(canvas);
    } else if (outfit == MascotOutfit.scarf) {
      _scarf(canvas, T);
      _arms(canvas, strokes: !behind, hands: true);
    } else {
      _arms(canvas, strokes: !behind, hands: true);
    }
    _shield(canvas, r.value('shield'));
    _heart(canvas, r.value('heart'), T);
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
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [palette.base, palette.deep],
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
          ..color = palette.light.withValues(alpha: .7));
    c.restore();
    c.drawRRect(
        _body,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..color = palette.line);
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
        if (side > 0 &&
            (rig.mood == MascotMood.farewell ||
                rig.mood == MascotMood.thumbsUp)) {
          c.save();
          c.translate(hx, hy);
          c.rotate(rig.mood == MascotMood.farewell
              ? math.sin(rig.time * 4.5) * .22
              : -.1);
          final hand = _fill(_C.navy);
          c.drawRRect(
              RRect.fromRectAndRadius(const Rect.fromLTWH(-14, -9, 28, 26),
                  const Radius.circular(9)),
              hand);
          if (rig.mood == MascotMood.farewell) {
            for (var finger = 0; finger < 4; finger++) {
              c.drawRRect(
                  RRect.fromRectAndRadius(
                      Rect.fromLTWH(-14 + finger * 7.0,
                          -24 - (finger == 1 || finger == 2 ? 4 : 0), 6, 27),
                      const Radius.circular(3)),
                  hand);
            }
            c.drawOval(const Rect.fromLTWH(-21, -3, 13, 10), hand);
          } else {
            c.drawRRect(
                RRect.fromRectAndRadius(const Rect.fromLTWH(-10, -30, 10, 29),
                    const Radius.circular(5)),
                hand);
            for (var i = 0; i < 3; i++) {
              c.drawLine(
                  Offset(1, -3 + i * 6),
                  Offset(11, -3 + i * 6),
                  Paint()
                    ..color = palette.light.withValues(alpha: .3)
                    ..strokeWidth = 1.5);
            }
          }
          c.restore();
          continue;
        }
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
            fontWeight: FontWeight.w700,
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

  // ---------------------------------------------------------------- y tá

  static const _medicTeal = Color(0xFF01857A);
  static const _medicTealDark = Color(0xFF01554F);
  static const _heartPink = Color(0xFFFF6F91);

  /// Mũ y tá trắng bo tròn, chữ thập màu thương hiệu; trễ theo thân như mũ đầu bếp.
  void _nurseCap(Canvas c) {
    final r = rig;
    c.save();
    c.translate(150, 66 + r.value('hatY').clamp(-12.0, 12.0));
    c.rotate(-.08 + r.value('hatT').clamp(-.4, .4));
    final cap = Path()
      ..moveTo(-44, 10)
      ..quadraticBezierTo(-46, -22, -26, -30)
      ..quadraticBezierTo(0, -40, 26, -30)
      ..quadraticBezierTo(46, -22, 44, 10)
      ..quadraticBezierTo(0, 2, -44, 10)
      ..close();
    c.drawPath(
        cap.shift(const Offset(0, 3)), _fill(const Color(0xFF0B2A26), .12));
    c.drawPath(
        cap,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_C.white, _hatShade],
          ).createShader(const Rect.fromLTRB(-46, -40, 46, 10)));
    c.drawPath(
        cap,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeJoin = StrokeJoin.round
          ..color = _hatLine);
    // dải viền màu thương hiệu ở chân mũ
    final band = Path()
      ..moveTo(-44, 10)
      ..quadraticBezierTo(0, 2, 44, 10)
      ..lineTo(43, 4)
      ..quadraticBezierTo(0, -4, -43, 4)
      ..close();
    c.drawPath(band, _fill(_medicTeal, .9));
    // chữ thập
    final cross = RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(0, -15), width: 8, height: 22),
        const Radius.circular(2.5));
    c.drawRRect(cross, _fill(_medicTeal));
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: const Offset(0, -15), width: 22, height: 8),
            const Radius.circular(2.5)),
        _fill(_medicTeal));
    c.restore();
  }

  /// Ống nghe vắt quanh cổ, đầu nghe tròn trước ngực.
  void _stethoscope(Canvas c) {
    final tube = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.2
      ..strokeCap = StrokeCap.round
      ..color = _medicTealDark;
    final path = Path()
      ..moveTo(112, 140)
      ..quadraticBezierTo(116, 182, 150, 186)
      ..quadraticBezierTo(184, 182, 188, 140);
    c.drawPath(path, tube);
    c.drawLine(const Offset(150, 186), const Offset(150, 198), tube);
    c.drawCircle(const Offset(150, 204), 8.5, _fill(_C.white2));
    c.drawCircle(
        const Offset(150, 204),
        8.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.2
          ..color = _medicTealDark);
    c.drawCircle(const Offset(147.5, 201.5), 2.4, _fill(_C.white, .9));
    for (final x in [112.0, 188.0]) {
      c.drawCircle(Offset(x, 138), 3.6, _fill(_medicTealDark));
    }
  }

  /// Trái tim nhỏ bay lên từ hai bàn tay khi ôm bụng; [a] = độ hiện, nhịp theo [T].
  void _heart(Canvas c, double a, double T) {
    if (a < .02) return;
    final phase = (T * .55) % 1;
    final y = 196 - phase * 46;
    final o = a * math.sin(phase * math.pi);
    final s = 7 + phase * 3;
    c.save();
    c.translate(150 + math.sin(T * 3) * 4, y);
    final heart = Path()
      ..moveTo(0, s * .9)
      ..cubicTo(-s * 1.6, -s * .2, -s * .6, -s * 1.4, 0, -s * .45)
      ..cubicTo(s * .6, -s * 1.4, s * 1.6, -s * .2, 0, s * .9)
      ..close();
    c.drawPath(heart, _fill(_heartPink, o));
    c.restore();
  }

  // ---------------------------------------------------------------- làm vườn

  static const _straw = Color(0xFFF3CF7A);
  static const _strawDark = Color(0xFFD9A441);
  static const _ribbon = Color(0xFF3DAA6B);
  static const _scarfRed = Color(0xFFE85D75);
  static const _scarfDark = Color(0xFFC23E57);

  /// Mũ cói vành rộng có dải ruy băng xanh lá; trễ theo thân như mũ y tá.
  void _strawHat(Canvas c) {
    final r = rig;
    c.save();
    c.translate(150, 62 + r.value('hatY').clamp(-12.0, 12.0));
    c.rotate(.06 + r.value('hatT').clamp(-.4, .4));
    final brim = Rect.fromCenter(center: Offset.zero, width: 150, height: 30);
    c.drawOval(
        brim.shift(const Offset(0, 3)), _fill(const Color(0xFF3B2A0A), .12));
    c.drawOval(
        brim,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_straw, _strawDark],
          ).createShader(brim));
    final crown = Path()
      ..moveTo(-42, 2)
      ..quadraticBezierTo(-46, -40, 0, -42)
      ..quadraticBezierTo(46, -40, 42, 2)
      ..quadraticBezierTo(0, 8, -42, 2)
      ..close();
    c.drawPath(crown, _fill(_straw));
    c.drawPath(
        Path()
          ..moveTo(-43, -6)
          ..quadraticBezierTo(0, 0, 43, -6)
          ..lineTo(42, 2)
          ..quadraticBezierTo(0, 8, -42, 2)
          ..close(),
        _fill(_ribbon));
    final weave = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = _strawDark.withValues(alpha: .55);
    for (final y in [-30.0, -20.0]) {
      c.drawLine(Offset(-34, y), Offset(34, y), weave);
    }
    c.drawOval(brim, weave..strokeWidth = 2.4);
    c.drawCircle(const Offset(30, -2), 6, _fill(const Color(0xFFFFE07A)));
    c.restore();
  }

  /// Khăn quàng quấn cổ, hai tua đung đưa theo nhịp và theo đà của thân.
  void _scarf(Canvas c, double T) {
    final r = rig;
    final swing = math.sin(T * 2.4) * 3 + r.value('hatT').clamp(-.4, .4) * 20;
    final wrap = Path()
      ..moveTo(92, 150)
      ..quadraticBezierTo(150, 176, 208, 150)
      ..lineTo(206, 166)
      ..quadraticBezierTo(150, 192, 94, 166)
      ..close();
    c.drawPath(wrap, _fill(_scarfRed));
    final tail = Path()
      ..moveTo(176, 168)
      ..quadraticBezierTo(184 + swing, 196, 178 + swing, 218)
      ..lineTo(196 + swing, 214)
      ..quadraticBezierTo(198 + swing * .6, 190, 194, 166)
      ..close();
    c.drawPath(tail, _fill(_scarfDark));
    final stripe = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = _C.white.withValues(alpha: .7);
    c.drawPath(
        Path()
          ..moveTo(100, 160)
          ..quadraticBezierTo(150, 182, 200, 160),
        stripe);
    for (var i = 0; i < 3; i++) {
      final x = 181.0 + swing + i * 5;
      c.drawLine(Offset(x, 216), Offset(x, 224), stripe..strokeWidth = 2);
    }
  }

  // ---------------------------------------------------------------- đầu bếp

  static const _hatLine = Color(0xFF8CC4F0);
  static const _hatShade = Color(0xFFE3EEF9);

  /// Mũ đầu bếp: bốn múi bông + vành, nghiêng trái như icon gốc; trễ theo thân (hatY, hatT).
  void _hat(Canvas c) {
    final r = rig;
    c.save();
    c.translate(146, 72 + r.value('hatY').clamp(-14.0, 14.0));
    c.rotate(-.17 + r.value('hatT').clamp(-.5, .5));
    c.scale(1.12);
    final puff = Path()
      ..addOval(Rect.fromCircle(center: const Offset(-36, -40), radius: 23))
      ..addOval(Rect.fromCircle(center: const Offset(-12, -58), radius: 27))
      ..addOval(Rect.fromCircle(center: const Offset(18, -56), radius: 26))
      ..addOval(Rect.fromCircle(center: const Offset(40, -36), radius: 21))
      ..addRRect(RRect.fromRectAndRadius(
          const Rect.fromLTRB(-50, -46, 52, -10), const Radius.circular(14)));
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeJoin = StrokeJoin.round
      ..color = _hatLine;
    c.drawPath(puff, outline);
    c.drawPath(
        puff,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_C.white, _hatShade],
          ).createShader(const Rect.fromLTRB(-60, -86, 62, -8)));
    final crease = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = _hatLine.withValues(alpha: .45);
    c.drawArc(Rect.fromCircle(center: const Offset(-12, -58), radius: 27), 2.2,
        .9, false, crease);
    c.drawArc(Rect.fromCircle(center: const Offset(18, -56), radius: 26), 2.0,
        .8, false, crease);
    c.drawCircle(const Offset(-22, -66), 6, _fill(_C.white, .9));
    final band = RRect.fromRectAndRadius(
        const Rect.fromLTRB(-46, -18, 48, 10), const Radius.circular(10));
    c.drawRRect(
        band,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_C.white, _hatShade],
          ).createShader(band.outerRect));
    c.drawRRect(band, outline);
    for (final x in [-20.0, 4.0, 28.0]) {
      c.drawLine(Offset(x, -12), Offset(x, 5), crease);
    }
    c.restore();
  }

  /// Bát salad ở tay phải; rau, trứng, cà chua, cá hồi nảy theo 'toss'.
  void _bowl(Canvas c, double T) {
    final r = rig;
    final hx = r.value('hrx'),
        hy = r.value('hry') - r.value('hw') * r.value('y');
    final toss = r.value('toss').clamp(0.0, 1.0);
    c.save();
    // bát to cỡ icon gốc, tay đỡ ở mép dưới bên trái
    c.translate(hx + 22, hy - 24);
    c.rotate(-.12 + r.value('bowlT').clamp(-.6, .6));
    c.scale(1.45);

    void item(double x, double y, double phase, void Function() draw) {
      final up = toss * (7 + phase * 5);
      c.save();
      c.translate(x, y - up);
      c.rotate(toss * (phase - .5) * .5);
      draw();
      c.restore();
    }

    item(-20, -6, .2, () {
      for (final (dx, dy, rr) in [
        (-6.0, 0.0, 11.0),
        (4.0, -4.0, 12.0),
        (12.0, 2.0, 9.0)
      ]) {
        c.drawCircle(Offset(dx, dy), rr, _fill(const Color(0xFF4FAE45)));
        c.drawCircle(
            Offset(dx - 2, dy - 3), rr * .55, _fill(const Color(0xFF7DCB5C)));
      }
    });
    item(18, -8, .9, () {
      final p = Path()
        ..moveTo(-14, 4)
        ..quadraticBezierTo(-10, -10, 8, -9)
        ..quadraticBezierTo(16, -6, 14, 4)
        ..close();
      c.drawPath(p, _fill(const Color(0xFFFF8A5B)));
      final s = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFFFE1D3);
      for (final x in [-6.0, 0.0, 6.0]) {
        c.drawLine(Offset(x - 2, -6), Offset(x + 2, 3), s);
      }
    });
    item(-2, -10, .5, () {
      c.drawCircle(Offset.zero, 8, _fill(const Color(0xFFF2453D)));
      c.drawCircle(const Offset(-2.5, -2.5), 2.6, _fill(_C.white, .55));
    });
    item(-26, -2, .7, () {
      c.drawOval(Rect.fromCenter(center: Offset.zero, width: 20, height: 15),
          _fill(_C.white));
      c.drawCircle(const Offset(1, 0), 5.2, _fill(_C.yellow));
    });
    item(6, -2, .35, () {
      c.drawOval(Rect.fromCenter(center: Offset.zero, width: 16, height: 10),
          _fill(const Color(0xFF9CCB4F)));
      c.drawOval(Rect.fromCenter(center: Offset.zero, width: 9, height: 5),
          _fill(const Color(0xFFCFE69A)));
    });
    final body = Path()
      ..moveTo(-38, 0)
      ..cubicTo(-36, 26, 36, 26, 38, 0)
      ..close();
    c.drawPath(
        body,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_C.white, Color(0xFFCFE6F8)],
          ).createShader(const Rect.fromLTRB(-38, 0, 38, 22)));
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: const Offset(0, 22), width: 26, height: 6),
            const Radius.circular(3)),
        _fill(const Color(0xFFB5D7F2)));
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeJoin = StrokeJoin.round
      ..color = _hatLine;
    c.drawPath(body, line);
    c.drawPath(
        Path()
          ..moveTo(-28, 8)
          ..quadraticBezierTo(-22, 16, -12, 18),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..color = _C.white.withValues(alpha: .9));
    c.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 78, height: 9), line);
    c.restore();
  }

  /// Hai ngôi sao bốn cánh vàng + hai nét "!" vui vẻ cạnh bát, như icon gốc.
  void _sparkles(Canvas c, double a, double T) {
    if (a < .02) return;
    final star = Path()
      ..moveTo(0, -10)
      ..quadraticBezierTo(2, -2, 10, 0)
      ..quadraticBezierTo(2, 2, 0, 10)
      ..quadraticBezierTo(-2, 2, -10, 0)
      ..quadraticBezierTo(-2, -2, 0, -10)
      ..close();
    for (final (x, y, s, ph) in [
      (56.0, 120.0, 1.0, 0.0),
      (214.0, 70.0, .8, 1.9)
    ]) {
      final tw = .75 + .25 * math.sin(T * 3.2 + ph);
      c.save();
      c.translate(x, y);
      c.scale(s * tw);
      c.drawPath(star, _fill(_C.yellow, a));
      c.drawPath(
          star,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..strokeJoin = StrokeJoin.round
            ..color = _C.yellowLine.withValues(alpha: a));
      c.restore();
    }
    final hx = rig.value('hrx');
    final hy = rig.value('hry');
    final dash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = _C.yellow.withValues(alpha: a * (.7 + .3 * math.sin(T * 6)));
    c.drawLine(Offset(hx + 10, hy - 78), Offset(hx + 14, hy - 64), dash);
    c.drawLine(Offset(hx + 30, hy - 74), Offset(hx + 26, hy - 61), dash);
  }

  @override
  bool shouldRepaint(covariant MascotPainter old) =>
      old.rig != rig || old.outfit != outfit || old.palette != palette;
}
