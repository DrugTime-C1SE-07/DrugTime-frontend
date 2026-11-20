import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/utils/app_assets.dart';

/// Linh vật cầm kính lúp cho sheet "Đang nhận diện thuốc" (nhận xét 1 của
/// adhoc-20261120-add-medication-ux). Ghép `mascot-thinking.png` với kính lúp vẽ bằng code:
/// linh vật nhún nhẹ, kính lúp quét ngang như đang soi vỏ thuốc.
///
/// Animation lặp **hữu hạn** ([cycles] vòng, dài hơn hẳn một lần OCR thật) để không chạy mãi
/// khi sheet bị bỏ quên và để `pumpAndSettle` trong test kết thúc. Đứng yên khi hệ thống bật
/// giảm chuyển động.
class ScanningMascot extends StatefulWidget {
  const ScanningMascot({super.key, this.size = 96, this.cycles = 12});

  final double size;
  final int cycles;

  static const period = Duration(milliseconds: 1600);

  @override
  State<ScanningMascot> createState() => ScanningMascotState();
}

class ScanningMascotState extends State<ScanningMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller =
      AnimationController(vsync: this, duration: ScanningMascot.period);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      controller
        ..stop()
        ..value = 0.5;
    } else if (!controller.isAnimating && controller.value == 0) {
      controller.repeat(reverse: true, count: widget.cycles * 2);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return Semantics(
      key: const Key('scanning-mascot'),
      label: 'Linh vật đang soi vỏ thuốc',
      image: true,
      child: SizedBox(
        width: size * 1.35,
        height: size,
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final t = Curves.easeInOut.transform(controller.value);
            return Stack(clipBehavior: Clip.none, children: [
              Positioned(
                left: 0,
                bottom: 2 + 4 * math.sin(t * math.pi),
                width: size,
                height: size,
                child: Image.asset(AppAssets.mascotThinking,
                    fit: BoxFit.contain, excludeFromSemantics: true),
              ),
              Positioned(
                left: size * (0.45 + 0.4 * t),
                top: size * (0.12 + 0.08 * math.sin(t * math.pi * 2)),
                child: Transform.rotate(
                  angle: -0.35 + 0.25 * t,
                  child: CustomPaint(
                    size: Size.square(size * 0.48),
                    painter: const MagnifierPainter(),
                  ),
                ),
              ),
            ]);
          },
        ),
      ),
    );
  }
}

/// Kính lúp: tròng kính có ánh sáng phản chiếu và tay cầm.
class MagnifierPainter extends CustomPainter {
  const MagnifierPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final center = Offset(s * 0.4, s * 0.4);
    final radius = s * 0.28;
    canvas.drawCircle(center, radius, Paint()..color = const Color(0x6670D9CC));
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.08
        ..color = const Color(0xFF17396F),
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.6),
      math.pi * 1.1,
      math.pi * 0.45,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = s * 0.05
        ..color = Colors.white,
    );
    final handleStart = center + Offset(radius * 0.72, radius * 0.72);
    canvas.drawLine(
      handleStart,
      Offset(s * 0.92, s * 0.92),
      Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = s * 0.13
        ..color = const Color(0xFFF0A257),
    );
  }

  @override
  bool shouldRepaint(MagnifierPainter oldDelegate) => false;
}
