import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../widgets/meal_ui.dart';

/// Mốc của chuỗi kết thúc "siêu tân tinh" (tỉ lệ trên tổng [finaleMs]).
const finaleMs = 1600;

class FinalePhase {
  static const collapseEnd = .25; // hút vào
  static const anticipateEnd = .33; // lấy đà
  static const flashPeak = .37; // bùng sáng (1 lần)
  static const flashEnd = .50;
  static const waveEnd = .64;
  static const bursts = [.38, .46, .53]; // pháo hoa: chính, phụ, phụ
  static const burstLife = .45;
  static const plateStart = .42;
  static const titleStart = .58;
}

double finaleSeg(double f, double a, double b) =>
    ((f - a) / (b - a)).clamp(0.0, 1.0);

/// Độ sáng lớp chớp: tăng nhanh tới đỉnh tại [FinalePhase.flashPeak] rồi tắt dần; đúng một đỉnh.
double flashAlpha(double f) {
  if (f < FinalePhase.anticipateEnd || f > FinalePhase.flashEnd) return 0;
  if (f < FinalePhase.flashPeak) {
    return .85 *
        Curves.easeOut.transform(
            finaleSeg(f, FinalePhase.anticipateEnd, FinalePhase.flashPeak));
  }
  return .85 *
      (1 -
          Curves.easeOutCubic.transform(
              finaleSeg(f, FinalePhase.flashPeak, FinalePhase.flashEnd)));
}

class _Spark {
  _Spark(this.angle, this.speed, this.color, this.size, this.kind);
  final double angle, speed, size;
  final Color color;
  final int kind; // 0 chấm, 1 sao 4 cánh, 2 vệt
}

final _rnd = math.Random(42);
const _sparkColors = [
  MealColors.teal,
  MealColors.blue,
  MealColors.gold,
  MealColors.pink,
  MealColors.violet,
  Colors.white,
  Color(0xFF5DBB4A)
];

List<_Spark> _burst(int n, double spread) => List.generate(n, (i) {
      final ang = i / n * math.pi * 2 + (_rnd.nextDouble() - .5) * .3;
      final k = _rnd.nextDouble();
      return _Spark(
          ang,
          (.55 + .45 * _rnd.nextDouble()) * spread,
          _sparkColors[_rnd.nextInt(_sparkColors.length)],
          2.2 + _rnd.nextDouble() * 2.6,
          k < .7 ? 0 : (k < .88 ? 1 : 2));
    });

final _bursts = [_burst(46, 1), _burst(28, .7), _burst(28, .7)];
const _burstOrigins = [Offset(0, 0), Offset(-.28, -.18), Offset(.3, -.12)];

/// Vẽ chớp sáng, sóng xung kích và pháo hoa. [center] tương đối khung vẽ.
class FinalePainter extends CustomPainter {
  FinalePainter({required this.f, required this.center});
  final double f;
  final Offset center;

  @override
  void paint(Canvas canvas, Size size) {
    final maxDim = size.longestSide;
    // sóng xung kích
    if (f > FinalePhase.anticipateEnd && f < FinalePhase.waveEnd) {
      final u = Curves.easeOutCubic.transform(
          finaleSeg(f, FinalePhase.anticipateEnd, FinalePhase.waveEnd));
      final r = 24 + u * maxDim * .75;
      canvas.drawCircle(
          center,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 14 * (1 - u) + 1
            ..color = const Color(0xFFFFE7A8).withValues(alpha: .75 * (1 - u)));
      canvas.drawCircle(
          center,
          r * .92,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4 * (1 - u) + .5
            ..color = Colors.white.withValues(alpha: .8 * (1 - u)));
    }
    // pháo hoa: hạt có trọng lực, lực cản, mờ dần
    final spread = size.shortestSide * .9;
    final p = Paint();
    for (var b = 0; b < 3; b++) {
      final tau = (f - FinalePhase.bursts[b]) * finaleMs / 1000;
      const life = FinalePhase.burstLife * finaleMs / 1000;
      if (tau < 0 || tau > life) continue;
      final o = center +
          Offset(_burstOrigins[b].dx * size.width,
              _burstOrigins[b].dy * size.height);
      final fade = math.pow(1 - tau / life, 1.4).toDouble();
      for (final s in _bursts[b]) {
        final dist = s.speed * spread * (tau * (1.25 - .9 * tau));
        final pos = o +
            Offset(math.cos(s.angle) * dist,
                math.sin(s.angle) * dist + 190 * tau * tau);
        p.color = s.color.withValues(alpha: fade);
        switch (s.kind) {
          case 0:
            canvas.drawCircle(pos, s.size * (.6 + .4 * fade), p);
          case 1:
            _star(canvas, pos, s.size * 2.2 * (.5 + .5 * fade), p);
          default:
            final dir = Offset(math.cos(s.angle), math.sin(s.angle));
            canvas.drawLine(
                pos - dir * 9 * fade,
                pos,
                Paint()
                  ..strokeWidth = 2.4
                  ..strokeCap = StrokeCap.round
                  ..color = s.color.withValues(alpha: fade));
        }
      }
    }
  }

  void _star(Canvas c, Offset o, double r, Paint p) {
    final path = Path()
      ..moveTo(o.dx, o.dy - r)
      ..quadraticBezierTo(o.dx + r * .18, o.dy - r * .18, o.dx + r, o.dy)
      ..quadraticBezierTo(o.dx + r * .18, o.dy + r * .18, o.dx, o.dy + r)
      ..quadraticBezierTo(o.dx - r * .18, o.dy + r * .18, o.dx - r, o.dy)
      ..quadraticBezierTo(o.dx - r * .18, o.dy - r * .18, o.dx, o.dy - r)
      ..close();
    c.drawPath(path, p);
  }

  @override
  bool shouldRepaint(FinalePainter old) => old.f != f || old.center != center;
}

/// Lớp chớp sáng toàn màn (trắng – vàng ấm, tối đa ~85%), đúng một lần.
class FlashLayer extends StatelessWidget {
  const FlashLayer({super.key, required this.f, required this.center});
  final double f;
  final Alignment center;

  @override
  Widget build(BuildContext context) {
    final a = flashAlpha(f);
    if (a <= 0) return const SizedBox.shrink();
    final grow = finaleSeg(f, FinalePhase.anticipateEnd, FinalePhase.flashEnd);
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: center,
            radius: .35 + 1.1 * grow,
            colors: [
              const Color(0xFFFFFDF4).withValues(alpha: a),
              const Color(0xFFFFE9AE).withValues(alpha: a * .7),
              const Color(0xFFFFE9AE).withValues(alpha: 0),
            ],
            stops: const [0, .45, 1],
          ),
        ),
      ),
    );
  }
}

/// Vòng cung xoay quanh đĩa món (D0e).
class ArcRingPainter extends CustomPainter {
  ArcRingPainter(this.t, this.a);
  final double t, a;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final pen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3;
    pen.color = MealColors.violet.withValues(alpha: .55 * a);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r + 10), -2.6 + t * .9,
        1.5, false, pen);
    pen.color = MealColors.teal.withValues(alpha: .55 * a);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r + 18), .4 + t * .7, 1.3,
        false, pen);
  }

  @override
  bool shouldRepaint(ArcRingPainter old) => old.t != t || old.a != a;
}
