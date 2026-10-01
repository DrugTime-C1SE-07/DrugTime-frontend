import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../app/theme/app_theme.dart';

/// Pixel-perfect vector icons mapped directly from the CSS design specifications.

/// Shield Check Icon (16x16, stroke 1.33px #01554F)
class ShieldCheckIcon extends StatelessWidget {
  final double size;
  final Color color;
  final double strokeWidth;

  const ShieldCheckIcon({
    super.key,
    this.size = 16.0,
    this.color = AppColors.brand,
    this.strokeWidth = 1.33,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _ShieldCheckPainter(color: color, strokeWidth: strokeWidth),
    );
  }
}

class _ShieldCheckPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _ShieldCheckPainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    // Shield outline
    final path = Path()
      ..moveTo(w * 0.5, h * 0.12)
      ..lineTo(w * 0.88, h * 0.24)
      ..cubicTo(w * 0.88, h * 0.6, w * 0.7, h * 0.82, w * 0.5, h * 0.92)
      ..cubicTo(w * 0.3, h * 0.82, w * 0.12, h * 0.6, w * 0.12, h * 0.24)
      ..close();

    canvas.drawPath(path, paint);

    // Checkmark inside shield
    final checkPath = Path()
      ..moveTo(w * 0.34, h * 0.52)
      ..lineTo(w * 0.46, h * 0.64)
      ..lineTo(w * 0.68, h * 0.38);

    canvas.drawPath(checkPath, paint);
  }

  @override
  bool shouldRepaint(covariant _ShieldCheckPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}

/// Lock Icon (16x16, stroke 1.33px #01554F)
class LockIcon extends StatelessWidget {
  final double size;
  final Color color;
  final double strokeWidth;

  const LockIcon({
    super.key,
    this.size = 16.0,
    this.color = AppColors.brand,
    this.strokeWidth = 1.33,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _LockPainter(color: color, strokeWidth: strokeWidth),
    );
  }
}

class _LockPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _LockPainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    // Lock body
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.18, h * 0.45, w * 0.64, h * 0.45),
      const Radius.circular(2.5),
    );
    canvas.drawRRect(bodyRect, paint);

    // Lock shackle
    final shacklePath = Path()
      ..moveTo(w * 0.32, h * 0.45)
      ..lineTo(w * 0.32, h * 0.28)
      ..arcToPoint(
        Offset(w * 0.68, h * 0.28),
        radius: Radius.circular(w * 0.18),
      )
      ..lineTo(w * 0.68, h * 0.45);

    canvas.drawPath(shacklePath, paint);

    // Keyhole dot
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w * 0.5, h * 0.64), w * 0.06, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _LockPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}

/// Message Circle Icon for Helper Row (13x13, stroke 1.08px #5B6169)
class MessageCircleIcon extends StatelessWidget {
  final double size;
  final Color color;
  final double strokeWidth;

  const MessageCircleIcon({
    super.key,
    this.size = 13.0,
    this.color = AppColors.inkMuted,
    this.strokeWidth = 1.08,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _MessageCirclePainter(color: color, strokeWidth: strokeWidth),
    );
  }
}

class _MessageCirclePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _MessageCirclePainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    final path = Path()
      ..moveTo(w * 0.88, h * 0.5)
      ..arcToPoint(
        Offset(w * 0.5, h * 0.88),
        radius: Radius.circular(w * 0.38),
      )
      ..lineTo(w * 0.2, h * 0.92)
      ..lineTo(w * 0.24, h * 0.64)
      ..arcToPoint(
        Offset(w * 0.88, h * 0.5),
        radius: Radius.circular(w * 0.38),
      );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _MessageCirclePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}

/// Status Bar Signal Icon (16x16, 5 signal bars #211D1D)
class StatusBarSignalIcon extends StatelessWidget {
  final double size;
  final Color color;

  const StatusBarSignalIcon({
    super.key,
    this.size = 16.0,
    this.color = AppColors.ink,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _SignalPainter(color: color),
    );
  }
}

class _SignalPainter extends CustomPainter {
  final Color color;

  _SignalPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;
    const barCount = 4;
    final barWidth = w * 0.16;
    final gap = (w - (barCount * barWidth)) / (barCount - 1);

    for (int i = 0; i < barCount; i++) {
      final barHeight = h * (0.28 + (i * 0.22));
      final x = i * (barWidth + gap);
      final y = h - barHeight;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, barHeight),
          const Radius.circular(1.0),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SignalPainter oldDelegate) => oldDelegate.color != color;
}

/// Status Bar Wifi Icon (16x16, #211D1D)
class StatusBarWifiIcon extends StatelessWidget {
  final double size;
  final Color color;

  const StatusBarWifiIcon({
    super.key,
    this.size = 16.0,
    this.color = AppColors.ink,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _WifiPainter(color: color),
    );
  }
}

class _WifiPainter extends CustomPainter {
  final Color color;

  _WifiPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.33
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;

    // Small dot
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w * 0.5, h * 0.82), 1.2, dotPaint);

    // Inner arc
    canvas.drawArc(
      Rect.fromCircle(center: Offset(w * 0.5, h * 0.8), radius: w * 0.28),
      -math.pi * 0.75,
      math.pi * 0.5,
      false,
      paint,
    );

    // Outer arc
    canvas.drawArc(
      Rect.fromCircle(center: Offset(w * 0.5, h * 0.8), radius: w * 0.44),
      -math.pi * 0.75,
      math.pi * 0.5,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _WifiPainter oldDelegate) => oldDelegate.color != color;
}

/// Status Bar Battery Icon (18x18, #211D1D)
class StatusBarBatteryIcon extends StatelessWidget {
  final double size;
  final Color color;

  const StatusBarBatteryIcon({
    super.key,
    this.size = 18.0,
    this.color = AppColors.ink,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _BatteryPainter(color: color),
    );
  }
}

class _BatteryPainter extends CustomPainter {
  final Color color;

  _BatteryPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    // Battery outer frame
    final frame = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.08, h * 0.28, w * 0.72, h * 0.44),
      const Radius.circular(2.5),
    );
    canvas.drawRRect(frame, paint);

    // Battery terminal nub
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.82, h * 0.40, w * 0.10, h * 0.20),
        const Radius.circular(1.0),
      ),
      fillPaint,
    );

    // Battery fill level (approx 85%)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.14, h * 0.34, w * 0.50, h * 0.32),
        const Radius.circular(1.5),
      ),
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _BatteryPainter oldDelegate) => oldDelegate.color != color;
}

/// Back Arrow Icon (24x24, stroke 2px #211D1D)
/// Conforms to Figma vector math:
/// - Stem: left: 20.83%, right: 20.83%, top: 50%, bottom: 50%
/// - Upper diagonal: left: 20.83%, right: 54.17%, top: 50%, bottom: 25%
/// - Lower diagonal: left: 20.83%, right: 54.17%, top: 25%, bottom: 50%
class ArrowLeftIcon extends StatelessWidget {
  final double size;
  final Color color;
  final double strokeWidth;

  const ArrowLeftIcon({
    super.key,
    this.size = 24.0,
    this.color = AppColors.ink,
    this.strokeWidth = 2.0,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _ArrowLeftPainter(color: color, strokeWidth: strokeWidth),
    );
  }
}

class _ArrowLeftPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _ArrowLeftPainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    // Stem: (20.83% -> 79.17% at 50% height)
    final startX = w * 0.2083;
    final endX = w * (1.0 - 0.2083);
    final midY = h * 0.5;

    canvas.drawLine(Offset(startX, midY), Offset(endX, midY), paint);

    // Diagonal chevron: (45.83% width at 25% height)
    final arrowTipX = startX;
    final arrowBaseX = w * (1.0 - 0.5417);
    final topY = h * 0.25;
    final bottomY = h * 0.75;

    final path = Path()
      ..moveTo(arrowBaseX, topY)
      ..lineTo(arrowTipX, midY)
      ..lineTo(arrowBaseX, bottomY);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ArrowLeftPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}

/// Clock Icon for Resend Timer (14x14, stroke 1.17px #5B6169)
/// Conforms to Figma vector math:
/// - Outer circle: left: 12.5%, right: 12.5%, top: 12.5%, bottom: 12.5%
/// - Clock hands: center to top-half and right-half
class ClockIcon extends StatelessWidget {
  final double size;
  final Color color;
  final double strokeWidth;

  const ClockIcon({
    super.key,
    this.size = 14.0,
    this.color = AppColors.inkMuted,
    this.strokeWidth = 1.17,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _ClockPainter(color: color, strokeWidth: strokeWidth),
    );
  }
}

class _ClockPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _ClockPainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;
    final center = Offset(w * 0.5, h * 0.5);
    final radius = w * 0.375;

    // Circle dial
    canvas.drawCircle(center, radius, paint);

    // Hands: 12:15 angle (vertical to 12, horizontal to 3)
    final handsPath = Path()
      ..moveTo(center.dx, center.dy - radius * 0.55)
      ..lineTo(center.dx, center.dy)
      ..lineTo(center.dx + radius * 0.45, center.dy);

    canvas.drawPath(handsPath, paint);
  }

  @override
  bool shouldRepaint(covariant _ClockPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}

