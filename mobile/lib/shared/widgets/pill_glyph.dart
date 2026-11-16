import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Hình dạng viên thuốc vẽ thật (matte, có độ dày, gờ vát, vạch bẻ).
enum PillShape { round, roundScored, oval, capsule, softgel, effervescent }

/// "Chân dung" một viên thuốc: hình dạng + màu (capsule có 2 nửa).
class PillLook {
  const PillLook(this.shape, this.color, {this.color2, this.angle = -0.55});

  final PillShape shape;
  final Color color;

  /// Nửa thân của viên nhộng; null thì dùng màu nhạt hơn của [color].
  final Color? color2;

  /// Góc nghiêng (radian). Ánh sáng luôn cố định từ góc trên-trái.
  final double angle;
}

/// Viên thuốc vẽ bằng [PillGlyphPainter]; chỉ trang trí, không mang ngữ nghĩa.
class PillGlyph extends StatelessWidget {
  const PillGlyph(this.look, {super.key, this.size = 48});

  final PillLook look;
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size.square(size),
        painter: PillGlyphPainter(look),
      );
}

const _white = Color(0xFFFFFFFF);
const _black = Color(0xFF000000);
Color _a(Color c, double o) => c.withValues(alpha: o);
Color _shade(Color c, double t) => Color.lerp(c, _black, t)!;
Color _tint(Color c, double t) => Color.lerp(c, _white, t)!;

class PillGlyphPainter extends CustomPainter {
  PillGlyphPainter(this.look);

  final PillLook look;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final c = size.center(Offset.zero);
    final m = Matrix4.translationValues(c.dx, c.dy, 0)
      ..multiply(Matrix4.rotationZ(look.angle));
    Path w(Path local) => local.transform(m.storage);
    Offset p(Offset o) => MatrixUtils.transformPoint(m, o);

    switch (look.shape) {
      case PillShape.round:
      case PillShape.roundScored:
        final r = s * .34;
        _tablet(canvas, s, w(_circle(r)), w(_circle(r - s * .045)), look.color,
            score: look.shape == PillShape.roundScored
                ? (p(Offset(0, -r * .78)), p(Offset(0, r * .78)))
                : null);
      case PillShape.oval:
        final l = s * .84, d = s * .40, i = s * .045;
        _tablet(canvas, s, w(_stadium(l, d)), w(_stadium(l - 2 * i, d - 2 * i)),
            look.color,
            score: (p(Offset(0, -d * .36)), p(Offset(0, d * .36))));
      case PillShape.effervescent:
        final r = s * .42;
        _tablet(canvas, s, w(_circle(r)), w(_circle(r - s * .022)), look.color,
            thickness: .045, dome: .45, speckleSeed: 7);
      case PillShape.capsule:
        _capsule(canvas, s, c, w, p);
      case PillShape.softgel:
        _softgel(canvas, s, w, p);
    }
  }

  // ---------------------------------------------------------------- tablet
  void _tablet(
    Canvas canvas,
    double s,
    Path outer,
    Path inner,
    Color base, {
    (Offset, Offset)? score,
    double thickness = .032,
    double dome = 1,
    int? speckleSeed,
  }) {
    final b = outer.getBounds();
    final t = s * thickness;
    _castShadow(canvas, outer, s, t);

    // Thành viên thuốc (độ dày) — thứ làm nó trông như vật thể thật.
    final side =
        Path.combine(PathOperation.union, outer, outer.shift(Offset(0, t)));
    canvas.drawPath(side, Paint()..color = _shade(base, .20));
    canvas.drawPath(
        side,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * .007
          ..color = _a(_shade(base, .5), .30));

    // Mặt trên + đổ bóng vòm mờ (matte, không bóng loáng).
    canvas.drawPath(outer, Paint()..color = base);
    canvas.drawPath(
        outer,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-.4, -.5),
            radius: 1.1,
            colors: [
              _a(_white, .50 * dome),
              _a(_white, 0),
              _a(_black, .10 * dome)
            ],
            stops: const [0, .5, 1],
          ).createShader(b));

    if (speckleSeed != null) _speckles(canvas, outer, b, base, s, speckleSeed);

    // Gờ vát quanh mép: sáng trên-trái, tối dưới-phải.
    final ring = Path.combine(PathOperation.difference, outer, inner);
    canvas.drawPath(
        ring,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_a(_white, .60), _a(_white, 0), _a(_black, .16)],
            stops: const [0, .45, 1],
          ).createShader(b));
    canvas.drawPath(
        inner,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * .005
          ..color = _a(_black, .07));

    if (score != null) _deboss(canvas, score.$1, score.$2, s);

    canvas.drawPath(
        outer,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * .008
          ..color = _a(_shade(base, .5), .35));
  }

  // --------------------------------------------------------------- capsule
  void _capsule(Canvas canvas, double s, Offset c, Path Function(Path) w,
      Offset Function(Offset) p) {
    final l = s * .88, d = s * .34;
    final capColor = look.color;
    final bodyColor = look.color2 ?? _tint(look.color, .75);

    final body = w(Path()
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTRB(-l / 2, -d / 2, l * .08, d / 2),
          Radius.circular(d / 2))));
    final capRect = Rect.fromLTRB(-l * .04, -d * .53, l / 2, d * .53);
    final cap = w(Path()
      ..addRRect(RRect.fromRectAndCorners(capRect,
          topLeft: Radius.circular(d * .14),
          bottomLeft: Radius.circular(d * .14),
          topRight: Radius.circular(d * .53),
          bottomRight: Radius.circular(d * .53))));
    final all = Path.combine(PathOperation.union, body, cap);

    _castShadow(canvas, all, s, s * .01);

    canvas.drawPath(body, Paint()..color = bodyColor);
    // Bóng của mép nắp đổ lên thân.
    canvas.save();
    canvas.clipPath(body);
    canvas.drawPath(
        w(Path()..addRect(Rect.fromLTRB(-l * .04 - s * .035, -d, -l * .04, d))),
        Paint()
          ..color = _a(_black, .16)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * .01));
    canvas.restore();
    canvas.drawPath(cap, Paint()..color = capColor);

    // Shading hình trụ: vuông góc với trục, sáng phía trên.
    final a = look.angle;
    final n = Offset(-math.sin(a), math.cos(a)) * (d * .55);
    final shade = Paint()
      ..shader = ui.Gradient.linear(
        c - n,
        c + n,
        [
          _a(_black, .08),
          _a(_white, .42),
          _a(_white, 0),
          _a(_black, .05),
          _a(_black, .24),
        ],
        const [0, .24, .5, .78, 1],
      );
    canvas.drawPath(all, shade);

    // Mép nắp (đường nối 2 nửa).
    final e1 = p(Offset(-l * .04, -d * .5)), e2 = p(Offset(-l * .04, d * .5));
    canvas.drawLine(
        e1,
        e2,
        Paint()
          ..color = _a(_shade(capColor, .5), .45)
          ..strokeWidth = s * .008);

    for (final part in [body, cap]) {
      canvas.drawPath(
          part,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = s * .008
            ..color = _a(_black, .14));
    }
  }

  // --------------------------------------------------------------- softgel
  void _softgel(Canvas canvas, double s, Path Function(Path) w,
      Offset Function(Offset) p) {
    final ww = s * .78, hh = s * .46;
    final local = Rect.fromCenter(center: Offset.zero, width: ww, height: hh);
    final shape = w(Path()..addOval(local));
    final b = shape.getBounds();
    final base = look.color;

    _castShadow(canvas, shape, s, s * .01, tint: base);
    canvas.drawPath(shape, Paint()..color = _shade(base, .10));
    // Lõi dầu sáng bên trong (cảm giác trong suốt).
    canvas.drawPath(
        shape,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(.15, .25),
            radius: .75,
            colors: [
              _a(_tint(base, .55), .95),
              _a(_tint(base, .2), .4),
              _a(base, 0)
            ],
            stops: const [0, .55, 1],
          ).createShader(b));
    // Viền tối dày hơn ở mép.
    canvas.drawPath(
        shape,
        Paint()
          ..shader = RadialGradient(
            radius: .72,
            colors: [_a(_black, 0), _a(_shade(base, .55), .55)],
            stops: const [.72, 1],
          ).createShader(b));
    // Đường seam dọc thân.
    canvas.drawLine(
        p(Offset(-ww * .44, 0)),
        p(Offset(ww * .44, 0)),
        Paint()
          ..color = _a(_shade(base, .35), .25)
          ..strokeWidth = s * .006);
    // Viên mềm thật sự bóng: một điểm phản chiếu nhỏ, không phải vệt kính.
    canvas.drawPath(
        w(Path()
          ..addOval(Rect.fromCenter(
              center: Offset(-ww * .16, -hh * .24),
              width: ww * .30,
              height: hh * .14))),
        Paint()
          ..color = _a(_white, .70)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * .008));
    canvas.drawCircle(p(Offset(ww * .26, -hh * .18)), s * .012,
        Paint()..color = _a(_white, .55));
    canvas.drawPath(
        shape,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * .008
          ..color = _a(_shade(base, .6), .35));
  }

  // --------------------------------------------------------------- helpers
  static Path _circle(double r) =>
      Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: r));

  static Path _stadium(double l, double d) => Path()
    ..addRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: l, height: d),
        Radius.circular(d / 2)));

  void _castShadow(Canvas canvas, Path shape, double s, double t,
      {Color? tint}) {
    final col = tint == null ? const Color(0xFF1B1B1B) : _shade(tint, .6);
    canvas.drawPath(
        shape.shift(Offset(s * .015, t + s * .035)),
        Paint()
          ..color = _a(col, .20)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * .035));
    canvas.drawPath(
        shape.shift(Offset(0, t + s * .008)),
        Paint()
          ..color = _a(col, .16)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * .008));
  }

  void _deboss(Canvas canvas, Offset a, Offset b, double s) {
    final off = Offset(s * .006, s * .008);
    canvas.drawLine(
        a + off,
        b + off,
        Paint()
          ..color = _a(_white, .65)
          ..strokeWidth = s * .014
          ..strokeCap = StrokeCap.round);
    canvas.drawLine(
        a,
        b,
        Paint()
          ..color = _a(_black, .20)
          ..strokeWidth = s * .014
          ..strokeCap = StrokeCap.round);
  }

  void _speckles(
      Canvas canvas, Path clip, Rect b, Color base, double s, int seed) {
    final rnd = math.Random(seed);
    canvas.save();
    canvas.clipPath(clip);
    for (var i = 0; i < 46; i++) {
      final ang = rnd.nextDouble() * math.pi * 2;
      final rad = math.sqrt(rnd.nextDouble()) * b.width * .42;
      final o = b.center + Offset(math.cos(ang), math.sin(ang)) * rad;
      final dark = rnd.nextBool();
      canvas.drawCircle(o, s * (.005 + rnd.nextDouble() * .008),
          Paint()..color = dark ? _a(_shade(base, .35), .35) : _a(_white, .7));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(PillGlyphPainter old) =>
      old.look.shape != look.shape ||
      old.look.color != look.color ||
      old.look.color2 != look.color2 ||
      old.look.angle != look.angle;
}
