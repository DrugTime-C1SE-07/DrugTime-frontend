import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'chibi_pet.dart';

class _C {
  static const white = Color(0xFFFFFFFF);
  static const white2 = Color(0xFFEAF1F8);
  static const blue = Color(0xFF2AA3FF);
  static const blue2 = Color(0xFF0C7BEA);
  static const line = Color(0xFF1D4F99);
  static const navy = Color(0xFF243E7A);
  static const eye = Color(0xFF0A1430);
  static const mouth = Color(0xFF8A1022);
  static const tongue = Color(0xFFFF5A6A);
  static const cheek = Color(0xFFFF9EAE);
}

/// Vẽ pet chibi trong khung 100×100 (bàn chân ở (50, 96)) theo giá trị của [rig].
///
/// Hình viên thuốc tròn, mắt to, tay chân là đốm tròn nhỏ để rõ dáng khi vẽ nhỏ.
class ChibiPainter {
  ChibiPainter(this.rig);
  final ChibiRig rig;

  static const feet = Offset(50, 96);
  static const _body = Rect.fromLTWH(22, 24, 56, 70);
  static final _bodyRR =
      RRect.fromRectAndRadius(_body, const Radius.circular(28));

  Paint _fill(Color c, [double a = 1]) =>
      Paint()..color = c.withValues(alpha: c.a * a.clamp(0.0, 1.0));

  void paint(Canvas c) {
    final r = rig;
    final pop = r.value('pop');
    if (pop < .01) return;
    final T = r.time;
    c.save();
    c.translate(feet.dx, feet.dy);
    c.scale(math.max(0, pop));
    c.translate(-feet.dx, -feet.dy);

    final face = r.value('face').clamp(-1.0, 1.0);
    if (face != 1) {
      c.translate(50, 0);
      c.scale(face.abs() < .15 ? .15 * (face < 0 ? -1 : 1) : face, 1);
      c.translate(-50, 0);
    }
    final lie = r.value('lie').clamp(0.0, 1.0);
    final y = r.value('y');

    // bóng mềm dưới chân
    final lift = (-y / 18).clamp(0.0, 1.0);
    c.drawOval(
        Rect.fromCenter(
            center: const Offset(50, 96),
            width: (46 + lie * 30) * (1 - lift * .4),
            height: 7),
        _fill(_C.eye, .12 * (1 - lift * .5)));

    _pillow(c, (lie - .4) / .6, r.value('pillow'));

    c.save();
    c.translate(0, y);
    if (lie > .001) {
      // nằm: xoay quanh tâm thân, đầu sang phải, hạ xuống chạm đất
      c.translate(0, 8 * lie);
      c.translate(50, 59);
      c.rotate(lie * math.pi / 2);
      c.translate(-50, -59);
    }
    _feet(c);
    c.save();
    final sq = r.value('sq');
    c.translate(50, 94);
    c.rotate(r.value('tilt'));
    c.scale(1 + sq, 1 - sq);
    c.translate(-50, -94);
    _arms(c, front: false);
    _bodyShape(c);
    // khi nằm, giữ mặt thẳng để vẫn đọc được biểu cảm (kiểu Finch, Pokémon Sleep)
    c.save();
    if (lie > .001) {
      c.translate(50, 54);
      c.rotate(-lie * math.pi / 2);
      c.translate(-50, -54);
    }
    _cheeks(c);
    _eyes(c);
    _brows(c);
    _mouth(c);
    c.restore();
    _arms(c, front: true);
    _sweat(c, r.value('sweat'), T);
    c.restore();
    c.restore();

    _blanket(c, r.value('blanket'), lie, T);
    _zzz(c, r.value('zzz'), T, lie);
    _stars(c, r.value('stars'), T, y);
    _heart(c, r.value('heart'), T);
    c.restore();
  }

  void _bodyShape(Canvas c) {
    c.drawRRect(
        _bodyRR,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_C.white, _C.white2],
          ).createShader(_body));
    c.save();
    c.clipRRect(_bodyRR);
    final lower = Path()
      ..moveTo(18, 64)
      ..quadraticBezierTo(50, 72, 82, 64)
      ..lineTo(82, 96)
      ..lineTo(18, 96)
      ..close();
    c.drawPath(
        lower,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_C.blue, _C.blue2],
          ).createShader(const Rect.fromLTWH(18, 64, 64, 32)));
    // điểm sáng bóng bên trái, vùng tối bên phải tạo khối
    c.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(28, 30, 7, 22), const Radius.circular(4)),
        _fill(_C.white, .9));
    c.drawRect(const Rect.fromLTWH(68, 20, 14, 80), _fill(_C.navy, .07));
    c.restore();
    c.drawRRect(
        _bodyRR,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..color = _C.line);
  }

  void _cheeks(Canvas c) {
    final a = rig.value('cheek');
    final puff = rig.value('puff').clamp(0.0, 1.0);
    for (final x in [33.0, 67.0]) {
      c.drawOval(
          Rect.fromCenter(
              center: Offset(x + (x < 50 ? -puff * 2 : puff * 2), 60),
              width: 10 + puff * 6,
              height: 6 + puff * 4),
          _fill(_C.cheek, a.clamp(0.0, 1.0) * .85));
    }
  }

  void _eyes(Canvas c) {
    final r = rig;
    final open = (r.value('eye').clamp(0.0, 1.2) * r.blink).toDouble();
    final s = r.value('eyeS');
    final lx = r.value('lx'), ly = r.value('ly');
    final happy = r.value('smile') > .6;
    for (final x in [39.0, 61.0]) {
      final center = Offset(x, 49);
      if (open < .25) {
        // nhắm: cười thì cong lên (^ ^), không thì cong xuống
        final up = happy ? -1.0 : 1.0;
        c.drawPath(
            Path()
              ..moveTo(x - 5, 49)
              ..quadraticBezierTo(x, 49 + up * 4, x + 5, 49),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.4
              ..strokeCap = StrokeCap.round
              ..color = _C.eye);
        continue;
      }
      final w = 11.0 * s, h = 14.0 * s * open;
      final eye = Rect.fromCenter(
          center: center + Offset(lx * 1.5, ly * 1.5), width: w, height: h);
      c.drawOval(eye, _fill(_C.eye));
      // mống mắt xanh phía dưới
      c.save();
      c.clipPath(Path()..addOval(eye));
      c.drawCircle(eye.center + Offset(0, h * .32), w * .42,
          _fill(const Color(0xFF2E66D8), .9));
      c.restore();
      if (open > .5) {
        c.drawCircle(
            eye.center + Offset(-w * .18, -h * .2), w * .2, _fill(_C.white));
        c.drawCircle(
            eye.center + Offset(w * .2, h * .12), w * .09, _fill(_C.white, .9));
      }
    }
  }

  void _brows(Canvas c) {
    final b = rig.value('brow');
    if (b.abs() < .05) return;
    // b > 0: hơi cau (sốt ruột); b < 0: nhướn lo lắng
    final p = Paint()
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = _C.eye.withValues(alpha: b.abs().clamp(0.0, 1.0));
    // đầu trong của lông mày: hạ xuống khi cau (b > 0), nâng lên khi lo (b < 0)
    for (final (x, inner) in [(39.0, 5.0), (61.0, -5.0)]) {
      c.drawLine(Offset(x - inner, 38), Offset(x + inner, 38 + 3.5 * b), p);
    }
  }

  void _mouth(Canvas c) {
    final smile = rig.value('smile'), mo = rig.value('mouth').clamp(0.0, 1.2);
    final puff = rig.value('puff').clamp(0.0, 1.0);
    const cx = 50.0, cy = 60.0;
    if (puff > .5 && mo < .2) {
      // phồng má: miệng chu tròn nhỏ
      c.drawOval(
          Rect.fromCenter(
              center: const Offset(cx, cy + 1), width: 4, height: 3.5),
          _fill(_C.mouth));
      return;
    }
    final w = 6.0 + mo * 2;
    if (mo < .12) {
      c.drawPath(
          Path()
            ..moveTo(cx - w, cy)
            ..quadraticBezierTo(cx, cy + smile * 6, cx + w, cy),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2
            ..strokeCap = StrokeCap.round
            ..color = _C.eye);
      return;
    }
    final low = cy + math.max(-2.0, smile * 3) + mo * 9;
    final p = Path()
      ..moveTo(cx - w, cy)
      ..cubicTo(cx - w * .8, low, cx + w * .8, low, cx + w, cy)
      ..quadraticBezierTo(cx, cy + math.max(0.0, smile), cx - w, cy)
      ..close();
    c.drawPath(p, _fill(_C.mouth));
    if (mo > .3) {
      c.save();
      c.clipPath(p);
      c.drawOval(
          Rect.fromCenter(
              center: Offset(cx + .5, low - 1.5),
              width: w * 1.3,
              height: 3 + mo * 5),
          _fill(_C.tongue));
      c.restore();
    }
  }

  /// Tay là đốm tròn quay quanh vai: góc 0 = buông xuống, π/2 = dang ngang, π = giơ lên.
  void _arms(Canvas c, {required bool front}) {
    for (final (key, side) in [('armL', -1.0), ('armR', 1.0)]) {
      final a = rig.value(key);
      final shoulder = Offset(50 + side * 24, 66);
      final hand = shoulder + Offset(side * math.sin(a) * 10, math.cos(a) * 10);
      // góc ôm (≈1,1..1,7): tay vòng ra trước thân; buông thấp: nấp sau thân
      final inFront = a > 1.1 && a < 1.7;
      if (front ? a < 1.1 : a >= 1.1) continue;
      final p = inFront ? Offset(50 + side * 12, 70) : hand;
      c.drawCircle(p, 6, _fill(_C.navy));
      c.drawCircle(p + const Offset(-1.8, -1.8), 1.6, _fill(_C.white, .25));
    }
  }

  void _feet(Canvas c) {
    for (final (key, x) in [('footL', 40.0), ('footR', 60.0)]) {
      final lift = rig.value(key);
      final p = Offset(x, 94 - lift);
      c.drawOval(
          Rect.fromCenter(center: p, width: 16, height: 9), _fill(_C.navy));
      c.drawOval(
          Rect.fromCenter(
              center: p + const Offset(-3, -2), width: 5, height: 2.4),
          _fill(_C.white, .2));
    }
  }

  void _pillow(Canvas c, double a, double shift) {
    if (a < .02) return;
    final o = a.clamp(0.0, 1.0);
    final center = Offset(84 + shift, 90);
    final p = Path()
      ..moveTo(center.dx - 19, center.dy + 2)
      ..quadraticBezierTo(
          center.dx - 21, center.dy - 8, center.dx - 10, center.dy - 8)
      ..quadraticBezierTo(
          center.dx, center.dy - 11, center.dx + 10, center.dy - 8)
      ..quadraticBezierTo(
          center.dx + 21, center.dy - 8, center.dx + 19, center.dy + 2)
      ..quadraticBezierTo(
          center.dx + 20, center.dy + 8, center.dx, center.dy + 7)
      ..quadraticBezierTo(
          center.dx - 20, center.dy + 8, center.dx - 19, center.dy + 2)
      ..close();
    c.drawPath(
        p,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFFFFFFFF).withValues(alpha: o),
              const Color(0xFFDCD6EE).withValues(alpha: o),
            ],
          ).createShader(
              Rect.fromCenter(center: center, width: 40, height: 18)));
    c.drawPath(
        p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1
          ..color = const Color(0xFFA9A0C8).withValues(alpha: o));
  }

  /// Chăn mềm phủ từ chân (trái) lên; mép trên cong theo thân, có viền gập màu kem.
  /// [cover] 1 = tới cổ, ≥ 1,3 = trùm kín đầu.
  void _blanket(Canvas c, double cover, double lie, double T) {
    if (cover < .02 || lie < .3) return;
    final a = lie.clamp(0.0, 1.0);
    // khi nằm, cằm ở x ≈ 44, đỉnh đầu ở x ≈ 85 (khung 100)
    final k = cover.clamp(0.0, 1.4);
    final right = k <= 1 ? 14 + 30 * k : 44 + (k - 1) / .3 * 44;
    final peak = cover > 1.1 ? 36.0 : 44.0;
    final breathe = math.sin(T * 1.1) * 1.2;
    final top = Path()
      ..moveTo(9, 97)
      ..cubicTo(6, 70, 14, 58 + breathe * .3, 26, peak + 6 + breathe)
      ..quadraticBezierTo(
          (right + 26) / 2, peak - 4 + breathe, right - 4, peak + 8)
      ..cubicTo(right + 6, peak + 16, right + 7, 80, right + 5, 97)
      ..close();
    final bounds = Rect.fromLTRB(6, peak - 6, right + 8, 98);
    c.drawPath(
        top,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFFFCF7A).withValues(alpha: a),
              const Color(0xFFF4A04A).withValues(alpha: a),
            ],
          ).createShader(bounds));
    c.save();
    c.clipPath(top);
    // nếp gấp mềm
    final fold = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFD9822E).withValues(alpha: .35 * a);
    for (final fx in [.35, .62]) {
      final x = 9 + (right - 9) * fx;
      c.drawPath(
          Path()
            ..moveTo(x, peak + 14)
            ..quadraticBezierTo(x - 4, 76, x + 2, 97),
          fold);
    }
    // hoa văn sao nhỏ
    final star = _fill(_C.white, .7 * a);
    var row = 0;
    for (var yy = peak + 16; yy < 96; yy += 11, row++) {
      for (var x = 16.0 + (row.isOdd ? 6 : 0); x < right; x += 12) {
        c.drawCircle(Offset(x, yy), 1.2, star);
      }
    }
    // viền gập màu kem ở mép trên
    c.drawPath(
        Path()
          ..moveTo(10, 66)
          ..cubicTo(14, 56 + breathe * .3, 20, peak + 8 + breathe, 26,
              peak + 6 + breathe)
          ..quadraticBezierTo(
              (right + 26) / 2, peak - 4 + breathe, right - 4, peak + 8),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFFFFF4DC).withValues(alpha: a));
    c.restore();
    c.drawPath(
        top,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0xFFC46A1C).withValues(alpha: .8 * a));
  }

  void _zzz(Canvas c, double a, double T, double lie) {
    if (a < .02) return;
    for (var i = 0; i < 3; i++) {
      final ph = (T * .45 + i / 3) % 1;
      final tp = TextPainter(
        text: TextSpan(
          text: 'z',
          style: TextStyle(
            fontSize: 8.0 + i * 3,
            fontWeight: FontWeight.w800,
            color: _C.navy.withValues(alpha: a * math.sin(ph * math.pi)),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(c, Offset(80 + ph * 12 + i * 2, 54 - lie * 0 - ph * 24 - 4));
    }
  }

  void _stars(Canvas c, double a, double T, double y) {
    if (a < .02) return;
    for (var i = 0; i < 4; i++) {
      final ang = -math.pi / 2 + (i - 1.5) * .7;
      final r = 34 + math.sin(T * 6 + i) * 3;
      final p = Offset(50 + math.cos(ang) * r, 56 + y + math.sin(ang) * r);
      final s = 3.2 * a * (.7 + .3 * math.sin(T * 8 + i * 2));
      final star = Path()
        ..moveTo(p.dx, p.dy - s * 2)
        ..quadraticBezierTo(p.dx, p.dy, p.dx + s * 2, p.dy)
        ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy + s * 2)
        ..quadraticBezierTo(p.dx, p.dy, p.dx - s * 2, p.dy)
        ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy - s * 2);
      c.drawPath(star, _fill(const Color(0xFFFFC928), a));
    }
  }

  void _sweat(Canvas c, double a, double T) {
    if (a < .02) return;
    c.save();
    c.translate(74, 36 + (T * .8 % 1) * 5);
    final p = Path()
      ..moveTo(0, -5)
      ..quadraticBezierTo(3.5, 0, 0, 3)
      ..quadraticBezierTo(-3.5, 0, 0, -5)
      ..close();
    c.drawPath(p, _fill(const Color(0xFF8FD3F0), a));
    c.restore();
  }

  void _heart(Canvas c, double a, double T) {
    if (a < .02) return;
    for (var i = 0; i < 2; i++) {
      final ph = (T * .6 + i * .5) % 1;
      c.save();
      c.translate(64 + i * 10 + math.sin(ph * 6) * 2, 22 - ph * 18);
      c.scale((.35 + .15 * math.sin(ph * math.pi)) * a);
      final p = Path()
        ..moveTo(0, 6)
        ..cubicTo(-14, -4, -8, -16, 0, -8)
        ..cubicTo(8, -16, 14, -4, 0, 6)
        ..close();
      c.drawPath(p, _fill(const Color(0xFFFF5D7A), a * math.sin(ph * math.pi)));
      c.restore();
    }
  }
}
