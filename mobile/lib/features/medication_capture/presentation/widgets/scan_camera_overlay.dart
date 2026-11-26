import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/capture_models.dart';

/// Computes the single source-of-truth scan frame rectangle inside [viewport].
///
/// Always reserves [topMargin] above and [guideReserve] below the frame so
/// [ScanGuidePill] never overlaps the scan frame or overflows on short screens.
Rect? computeScanFrameRect(
  Size viewport, {
  double horizontalMargin = 36,
  double maxFrameHeight = 220,
  double topMargin = 12,
  double guideReserve = 72,
}) {
  final vw = viewport.width;
  final vh = viewport.height;
  if (vw <= 0 || vh <= 0) return null;
  final frameW = (vw - horizontalMargin * 2).clamp(0.0, vw);
  final maxH = math.max(0.0, vh - topMargin - guideReserve);
  final frameH = math.min(maxFrameHeight, maxH);
  if (frameW <= 0 || frameH <= 0) return null;
  final usableH = vh - guideReserve;
  final top = math.max(topMargin, (usableH - frameH) / 2);
  final left = (vw - frameW) / 2;
  return Rect.fromLTWH(left, top, frameW, frameH);
}

/// Converts [frame] inside [viewport] into normalized [CaptureCropRect].
CaptureCropRect? toCaptureCropRect(Rect? frame, Size viewport) {
  if (frame == null || viewport.width <= 0 || viewport.height <= 0) return null;
  return CaptureCropRect(
    left: frame.left / viewport.width,
    top: frame.top / viewport.height,
    width: frame.width / viewport.width,
    height: frame.height / viewport.height,
    viewportAspectRatio: viewport.width / viewport.height,
  );
}

/// Darkens everything outside [cutout] using [AppColors.cameraScrim].
class ScanScrimPainter extends CustomPainter {
  const ScanScrimPainter({
    required this.cutout,
    this.scrimColor = AppColors.cameraScrim,
  });

  final Rect cutout;
  final Color scrimColor;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(cutout, const Radius.circular(8)));
    canvas.drawPath(path, Paint()..color = scrimColor);
  }

  @override
  bool shouldRepaint(covariant ScanScrimPainter oldDelegate) =>
      oldDelegate.cutout != cutout || oldDelegate.scrimColor != scrimColor;
}

/// Four L-shaped corner brackets around the scan frame (Figma S07-O1: 28px).
class ScanCornersPainter extends CustomPainter {
  const ScanCornersPainter({
    this.color = AppColors.cameraAccent,
    this.cornerLength = 28,
    this.strokeWidth = 3,
  });

  final Color color;
  final double cornerLength;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final length =
        math.min(cornerLength, math.min(size.width, size.height) / 3);
    for (final point in [
      Offset.zero,
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ]) {
      final dx = point.dx == 0 ? length : -length;
      final dy = point.dy == 0 ? length : -length;
      canvas.drawLine(point, point + Offset(dx, 0), paint);
      canvas.drawLine(point, point + Offset(0, dy), paint);
    }
  }

  @override
  bool shouldRepaint(covariant ScanCornersPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.cornerLength != cornerLength ||
      oldDelegate.strokeWidth != strokeWidth;
}

/// Finite looping horizontal scan beam inside the camera frame.
class ScanBeam extends StatefulWidget {
  const ScanBeam({super.key});

  static const int _cycles = 30;
  static const period = Duration(milliseconds: 1400);

  @override
  State<ScanBeam> createState() => _ScanBeamState();
}

class _ScanBeamState extends State<ScanBeam>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: ScanBeam.period);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller
        ..stop()
        ..value = 0.5;
    } else if (!_controller.isAnimating && _controller.value == 0) {
      _controller.repeat(reverse: true, count: ScanBeam._cycles * 2);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_controller.value);
        return Align(
          key: const Key('scan-beam'),
          alignment: Alignment(0, -1 + 2 * t),
          child: child,
        );
      },
      child: Container(
        height: 3,
        decoration: BoxDecoration(
          color: AppColors.cameraAccent,
          borderRadius: BorderRadius.circular(2),
          boxShadow: [
            BoxShadow(
              color: AppColors.cameraAccent.withValues(alpha: 0.45),
              blurRadius: 8,
            ),
          ],
        ),
      ),
    );
  }
}

/// Dark translucent pill placed below the scan frame (Figma S07-O1 `guide`).
class ScanGuidePill extends StatelessWidget {
  const ScanGuidePill({super.key = const Key('scan-hint')});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: AppColors.cameraCanvas.withValues(alpha: 0.85),
          border: Border.all(color: AppColors.cameraOutline),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              LucideIcons.scanLine,
              size: 18,
              color: AppColors.cameraAccent,
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                'Đặt tên thuốc vào trong khung',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTextStyles.captionStrong.copyWith(
                  color: AppColors.onCamera,
                ),
              ),
            ),
          ],
        ),
      );
}

/// Complete camera overlay (scrim + corners + scan beam + guide pill) sharing [frameRect].
class ScanCameraOverlay extends StatelessWidget {
  const ScanCameraOverlay({super.key, required this.frameRect});

  final Rect frameRect;

  @override
  Widget build(BuildContext context) => Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                key: const Key('scan-scrim'),
                painter: ScanScrimPainter(cutout: frameRect),
              ),
            ),
          ),
          Positioned.fromRect(
            rect: frameRect,
            child: const IgnorePointer(
              child: CustomPaint(
                key: Key('scan-camera-corners'),
                painter: ScanCornersPainter(),
              ),
            ),
          ),
          Positioned.fromRect(
            rect: frameRect,
            child: const IgnorePointer(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: ScanBeam(),
              ),
            ),
          ),
          Positioned(
            top: frameRect.bottom + AppSpacing.md,
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            child: const IgnorePointer(
              child: Center(child: ScanGuidePill()),
            ),
          ),
        ],
      );
}
