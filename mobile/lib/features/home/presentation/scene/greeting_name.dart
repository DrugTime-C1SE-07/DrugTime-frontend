import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Tên người dùng dưới lời chào: chữ lớn, đậm, có bóng mềm để đọc rõ trên mọi màu trời,
/// và một nét bút dạ quang vẽ dần dưới tên khi vừa hiện (kiểu Headspace, Calm, Finch).
class GreetingName extends StatelessWidget {
  const GreetingName(this.name,
      {super.key, required this.ink, this.fontSize = 32});

  final String name;

  /// Màu chữ đọc rõ trên nền trời hiện tại (trắng ban đêm, gần đen ban ngày).
  final Color ink;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final night = ink.computeLuminance() > .5;
    final highlight = night ? const Color(0xFFB9A8FF) : const Color(0xFFFFD54F);
    final style = TextStyle(
      color: ink,
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      letterSpacing: -.6,
      height: 1.12,
      shadows: [
        Shadow(
          color: (night ? const Color(0xFF0B0F2A) : Colors.white)
              .withValues(alpha: .55),
          blurRadius: 10,
        ),
      ],
    );
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: math.min(1, t * 1.6),
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 8),
          child: CustomPaint(
            painter: _Swoosh(highlight, ((t - .25) / .75).clamp(0.0, 1.0)),
            child: child,
          ),
        ),
      ),
      child: Text(name,
          maxLines: 2, overflow: TextOverflow.ellipsis, style: style),
    );
  }
}

/// Nét bút dạ quang dưới dòng cuối của tên, vẽ dần từ trái sang phải theo [progress].
class _Swoosh extends CustomPainter {
  _Swoosh(this.color, this.progress);
  final Color color;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || size.width < 8) return;
    final w = math.min(size.width, 240.0) * progress;
    final y = size.height - size.height * .22;
    final path = Path()
      ..moveTo(2, y + 3)
      ..quadraticBezierTo(w * .45, y - 4, w, y + 1);
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = size.height * .18
          ..color = color.withValues(alpha: .55));
  }

  @override
  bool shouldRepaint(_Swoosh old) =>
      old.progress != progress || old.color != color;
}
