import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

/// Icon viên nhộng kiểu Lucide "pill" (Material không có icon tương đương).
class PillIcon extends StatelessWidget {
  const PillIcon({super.key, this.size = 24, this.color = AppColors.brand});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _PillPainter(color),
    );
  }
}

class _PillPainter extends CustomPainter {
  _PillPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * s
      ..strokeCap = StrokeCap.round;

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-math.pi / 4);
    final capsule = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: 20 * s, height: 9 * s),
      Radius.circular(4.5 * s),
    );
    canvas.drawRRect(capsule, paint);
    canvas.drawLine(Offset(0, -4.5 * s), Offset(0, 4.5 * s), paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PillPainter oldDelegate) => oldDelegate.color != color;
}

/// Ô vuông bo góc chứa [PillIcon] — nhận diện "đây là một loại thuốc".
class PillTile extends StatelessWidget {
  const PillTile({super.key, this.muted = false, this.size = 48});

  final bool muted;
  final double size;

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
      ),
    );
  }
}
