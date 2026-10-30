import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../app/theme/app_theme.dart';

class CaptureIconButton extends StatelessWidget {
  const CaptureIconButton({
    super.key,
    required this.label,
    required this.icon,
    this.onPressed,
    this.active = false,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: label,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          minimumSize: const Size.square(AppSizes.tapTarget),
          backgroundColor:
              active ? AppColors.cameraAccent : AppColors.cameraControl,
          foregroundColor:
              active ? AppColors.onCameraAccent : AppColors.onCamera,
          disabledForegroundColor: AppColors.inkDisabled,
          shape: const CircleBorder(),
        ),
        icon: Icon(icon),
      );
}

/// A neutral guide only: the complete image is kept for review.
class CaptureViewfinder extends StatelessWidget {
  const CaptureViewfinder({super.key});

  @override
  Widget build(BuildContext context) => const ExcludeSemantics(
        child: SizedBox.expand(
          child: CustomPaint(painter: _FinderPainter()),
        ),
      );
}

class _FinderPainter extends CustomPainter {
  const _FinderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const ratio = 1.15;
    final maxWidth = math.min(480.0, math.max(0.0, size.width - 48));
    final maxHeight = math.max(0.0, size.height - 32);
    final width = math.min(maxWidth, maxHeight * ratio);
    final frame = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: width,
      height: width / ratio,
    );
    final radius = math.min(20.0, width / 6);
    final window = RRect.fromRectAndRadius(frame, Radius.circular(radius));
    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(Offset.zero & size)
        ..addRRect(window),
      Paint()..color = AppColors.cameraScrim,
    );
    if (width < 48) return;
    canvas.drawRRect(
      window,
      Paint()
        ..color = AppColors.onCamera.withValues(alpha: .32)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    final corner = Path()
      ..moveTo(0, 36)
      ..lineTo(0, radius)
      ..quadraticBezierTo(0, 0, radius, 0)
      ..lineTo(36, 0);
    final paint = Paint()
      ..color = AppColors.cameraAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final corners = [
      frame.topLeft,
      frame.topRight,
      frame.bottomRight,
      frame.bottomLeft,
    ];
    for (var i = 0; i < corners.length; i++) {
      canvas.save();
      canvas.translate(corners[i].dx, corners[i].dy);
      canvas.rotate(i * math.pi / 2);
      canvas.drawPath(corner, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_FinderPainter oldDelegate) => false;
}

Future<void> showCaptureHelp(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Chụp ảnh rõ hơn', style: AppTextStyles.heading),
              const SizedBox(height: 24),
              for (final tip in [
                (Icons.wb_sunny_outlined, 'Đủ sáng, tránh ánh chói'),
                (
                  Icons.photo_size_select_large_outlined,
                  'Giữ trọn thuốc trong khung'
                ),
                (Icons.pan_tool_outlined, 'Giữ máy chắc khi chụp'),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(children: [
                    ExcludeSemantics(
                      child: Icon(tip.$1, color: AppColors.brand),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(tip.$2, style: AppTextStyles.body)),
                  ]),
                ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Đã hiểu'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
