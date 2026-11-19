import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'meal_ui.dart';

/// Ăn mừng khi chọn món: dấu tích bật ra (nảy) + hạt màu nguyên liệu và sao bay ra.
class ChooseBurst extends StatefulWidget {
  const ChooseBurst({super.key, this.size = 220});
  final double size;

  @override
  State<ChooseBurst> createState() => _ChooseBurstState();
}

class _ChooseBurstState extends State<ChooseBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100))
    ..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return const _Check(scale: 1);
    }
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final v = _c.value;
        final check = Curves.elasticOut.transform((v / .7).clamp(0, 1));
        final fade = v < .75 ? 1.0 : 1 - (v - .75) / .25;
        return Opacity(
          opacity: fade.clamp(0, 1),
          child: SizedBox.square(
            dimension: widget.size,
            child: Stack(alignment: Alignment.center, children: [
              CustomPaint(
                  size: Size.square(widget.size), painter: _BurstPainter(v)),
              _Check(scale: check),
            ]),
          ),
        );
      },
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({required this.scale});
  final double scale;
  @override
  Widget build(BuildContext context) => Transform.scale(
        scale: scale,
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: MealColors.teal,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: [
              BoxShadow(
                  color: MealColors.teal.withValues(alpha: .45), blurRadius: 24)
            ],
          ),
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 40),
        ),
      );
}

class _BurstPainter extends CustomPainter {
  _BurstPainter(this.v);
  final double v;
  static const _colors = [
    Color(0xFF5DBB4A),
    Color(0xFFEF4136),
    MealColors.gold,
    Color(0xFFF57C22),
    MealColors.teal,
    MealColors.pink
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final u = Curves.easeOutCubic.transform((v / .8).clamp(0, 1));
    final p = Paint();
    for (var i = 0; i < 16; i++) {
      final ang = i / 16 * math.pi * 2 + (i.isEven ? .1 : -.1);
      final dist = 40 + u * (size.width * .42) * (i.isEven ? 1 : .8);
      final pos =
          c + Offset(math.cos(ang) * dist, math.sin(ang) * dist + 30 * u * u);
      p.color = _colors[i % _colors.length].withValues(alpha: 1 - u * .6);
      if (i % 4 == 0) {
        canvas.save();
        canvas.translate(pos.dx, pos.dy);
        canvas.rotate(u * 3);
        final r = 7 * (1 - u * .4);
        canvas.drawPath(
            Path()
              ..moveTo(0, -r)
              ..quadraticBezierTo(r * .2, -r * .2, r, 0)
              ..quadraticBezierTo(r * .2, r * .2, 0, r)
              ..quadraticBezierTo(-r * .2, r * .2, -r, 0)
              ..quadraticBezierTo(-r * .2, -r * .2, 0, -r)
              ..close(),
            p..color = MealColors.gold);
        canvas.restore();
      } else {
        canvas.drawCircle(pos, 5 * (1 - u * .5), p);
      }
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.v != v;
}
