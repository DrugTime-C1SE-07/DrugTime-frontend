import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../app/theme/app_colors.dart' as design_tokens;

/// Icon viên nhộng kiểu Lucide "pill" (Material không có icon tương đương).
class PillIcon extends StatelessWidget {
  const PillIcon(
      {super.key,
      this.size = 24,
      this.color = AppColors.brand,
      this.fillColor});

  final double size;
  final Color color;
  final Color? fillColor;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _PillPainter(color, fillColor),
    );
  }
}

class _PillPainter extends CustomPainter {
  _PillPainter(this.color, this.fillColor);

  final Color color;
  final Color? fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final outline = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * s
      ..strokeCap = StrokeCap.round;
    final capsule = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: 20 * s, height: 9 * s),
      Radius.circular(4.5 * s),
    );

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-math.pi / 4);
    if (fillColor case final fill?) {
      canvas.save();
      canvas.clipRRect(capsule);
      canvas.drawRect(
        Rect.fromLTRB(-10 * s, -5 * s, 0, 5 * s),
        Paint()..color = fill,
      );
      canvas.restore();
    }
    // Repaint both strokes after fill so antialiasing cannot leave a seam or
    // let the color cover the outer contour or the capsule divider.
    canvas.drawRRect(capsule, outline);
    canvas.drawLine(Offset(0, -4.5 * s), Offset(0, 4.5 * s), outline);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PillPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.fillColor != fillColor;
}

/// Ô vuông bo góc chứa [PillIcon] — nhận diện "đây là một loại thuốc".
class PillTile extends StatelessWidget {
  const PillTile(
      {super.key, this.muted = false, this.size = 48, this.colored = false});

  final bool muted;
  final double size;
  final bool colored;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: muted ? AppColors.surfaceMuted : AppColors.brandTint,
        borderRadius: BorderRadius.circular(AppRadius.field),
      ),
      child: PillIcon(
        size: size / 2,
        color: muted ? AppColors.inkDisabled : AppColors.brand,
        fillColor:
            colored && !muted ? design_tokens.AppColors.pillFill : null,
      ),
    );
  }
}
