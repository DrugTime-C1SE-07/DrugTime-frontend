import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';

class FloatingPills extends StatefulWidget {
  const FloatingPills({super.key});

  @override
  State<FloatingPills> createState() => _FloatingPillsState();
}

class _FloatingPillsState extends State<FloatingPills>
    with SingleTickerProviderStateMixin {
  late final _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4800),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.isCurrentOf(context) ?? true);
    if (active) {
      if (!_motion.isAnimating) _motion.repeat();
    } else {
      _motion.stop();
      _motion.value = 0;
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _PillPainter(_motion),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _PillPainter extends CustomPainter {
  _PillPainter(this.motion) : super(repaint: motion);

  final Animation<double> motion;

  @override
  void paint(Canvas canvas, Size size) {
    final angle = motion.value * 2 * math.pi;
    const amplitude = 1.0;
    _draw(
      canvas,
      Offset(size.width * .13, size.height * .27),
      56,
      -.55,
      angle * 1,
      amplitude,
      const Color(0xFFED871F),
    );
    _draw(
      canvas,
      Offset(size.width * .87, size.height * .32),
      48,
      .72,
      angle * 2 + 1.8,
      amplitude,
      const Color(0xFF7FD8C9),
    );
    _draw(
      canvas,
      Offset(size.width * .15, size.height * .63),
      40,
      .4,
      angle * 3 + 3.2,
      amplitude,
      const Color(0xFFF5C542),
    );
    _draw(canvas, Offset(size.width * .87, size.height * .75), 60, -.5,
        angle * 2 + 2, amplitude, const Color(0xFFED871F));
    _draw(canvas, Offset(size.width * .80, size.height * .22), 30, 1.8,
        angle * 3 + 1, amplitude, const Color(0xFFBDE3DB));
  }

  void _draw(
    Canvas canvas,
    Offset anchor,
    double length,
    double tilt,
    double phase,
    double amplitude,
    Color accent,
  ) {
    canvas.save();
    canvas.translate(
      anchor.dx + 2.5 * amplitude * math.cos(phase),
      anchor.dy + 5 * amplitude * math.sin(phase),
    );
    canvas.rotate(tilt + .14 * amplitude * math.sin(phase + .5));
    final bounds = Rect.fromCenter(
      center: Offset.zero,
      width: length,
      height: length * .48,
    );
    final shape = RRect.fromRectAndRadius(
      bounds,
      Radius.circular(bounds.height / 2),
    );
    canvas.drawShadow(
      Path()..addRRect(shape),
      AppColors.brand.withValues(alpha: .24),
      2,
      false,
    );
    canvas.drawRRect(shape, Paint()..color = Colors.white);
    canvas.save();
    canvas.clipRRect(shape);
    canvas.drawRect(
      Rect.fromLTRB(0, bounds.top, bounds.right, bounds.bottom),
      Paint()..color = accent,
    );
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PillPainter oldDelegate) =>
      motion != oldDelegate.motion;
}
