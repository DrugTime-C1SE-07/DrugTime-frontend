import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/app_assets.dart';

/// Mascot widget cho màn hình Xác thực OTP:
/// Kích thước: 96px x 88px matching `mascot-slot` trong Figma CSS.
/// Tự động load ảnh `assets/icons/mascot-protect.png`. Nếu asset chưa có sẵn,
/// CustomPainter sẽ vẽ Mascot "Bảo Vệ" (Viên thuốc hiệp sĩ bảo vệ sức khỏe)
/// đảm bảo giao diện luôn hiển thị sinh động và không bị vỡ.
class MascotProtectWidget extends StatelessWidget {
  const MascotProtectWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96.0,
      height: 88.0,
      child: Image.asset(
        AppAssets.mascotProtect,
        width: 96.0,
        height: 88.0,
        fit: BoxFit.contain,
        semanticLabel: 'Linh vật bảo vệ sức khỏe DrugTime',
        errorBuilder: (_, __, ___) => const _MascotVectorFallback(),
      ),
    );
  }
}

class _MascotVectorFallback extends StatelessWidget {
  const _MascotVectorFallback();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(96.0, 88.0),
      painter: _MascotProtectPainter(),
    );
  }
}

class _MascotProtectPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Bóng đổ nhẹ dưới chân mascot
    final shadowPaint = Paint()
      ..color = const Color.fromRGBO(0, 0, 0, 0.08)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.5, h * 0.90), width: w * 0.65, height: h * 0.12),
      shadowPaint,
    );

    // Thân mascot: Viên thuốc con nhộng đứng nghiêng đáng yêu
    final bodyPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final bodyStroke = Paint()
      ..color = AppColors.brandStrong
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final capsuleRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(w * 0.5, h * 0.48), width: w * 0.54, height: h * 0.72),
      Radius.circular(w * 0.27),
    );
    canvas.drawRRect(capsuleRect, bodyPaint);

    // Nửa trên màu xanh ngọc thương hiệu (Teal Cap)
    canvas.save();
    canvas.clipRRect(capsuleRect);
    final capPaint = Paint()
      ..color = AppColors.brand
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h * 0.44),
      capPaint,
    );

    // Mũ bảo vệ / khiên huy hiệu nhỏ trên trán
    final badgePaint = Paint()
      ..color = const Color(0xFFF59E0B) // Gold badge
      ..style = PaintingStyle.fill;
    final starPath = Path()
      ..moveTo(w * 0.5, h * 0.20)
      ..lineTo(w * 0.55, h * 0.27)
      ..lineTo(w * 0.5, h * 0.32)
      ..lineTo(w * 0.45, h * 0.27)
      ..close();
    canvas.drawPath(starPath, badgePaint);

    canvas.restore();

    // Viền bao quanh viên thuốc
    canvas.drawRRect(capsuleRect, bodyStroke);

    // Đôi mắt to tròn thân thiện
    final eyePaint = Paint()
      ..color = AppColors.ink
      ..style = PaintingStyle.fill;
    final eyeHighlight = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Mắt trái
    canvas.drawCircle(Offset(w * 0.41, h * 0.52), 3.2, eyePaint);
    canvas.drawCircle(Offset(w * 0.40, h * 0.51), 1.0, eyeHighlight);

    // Mắt phải
    canvas.drawCircle(Offset(w * 0.59, h * 0.52), 3.2, eyePaint);
    canvas.drawCircle(Offset(w * 0.58, h * 0.51), 1.0, eyeHighlight);

    // Má hồng baby
    final blushPaint = Paint()
      ..color = const Color(0xFFF87171).withOpacity(0.5)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w * 0.34, h * 0.56), 3.0, blushPaint);
    canvas.drawCircle(Offset(w * 0.66, h * 0.56), 3.0, blushPaint);

    // Nụ cười mỉm
    final smilePaint = Paint()
      ..color = AppColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    final smilePath = Path()
      ..moveTo(w * 0.46, h * 0.57)
      ..quadraticBezierTo(w * 0.5, h * 0.62, w * 0.54, h * 0.57);
    canvas.drawPath(smilePath, smilePaint);

    // Khiên bảo vệ cầm bên tay phải
    final shieldPaint = Paint()
      ..color = AppColors.brand
      ..style = PaintingStyle.fill;
    final shieldBorder = Paint()
      ..color = AppColors.brandStrong
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    final shieldPath = Path()
      ..moveTo(w * 0.76, h * 0.50)
      ..lineTo(w * 0.90, h * 0.55)
      ..cubicTo(w * 0.90, h * 0.72, w * 0.82, h * 0.82, w * 0.76, h * 0.86)
      ..cubicTo(w * 0.70, h * 0.82, w * 0.62, h * 0.72, w * 0.62, h * 0.55)
      ..close();
    canvas.drawPath(shieldPath, shieldPaint);
    canvas.drawPath(shieldPath, shieldBorder);

    // Dấu check trên khiên
    final checkPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final checkPath = Path()
      ..moveTo(w * 0.70, h * 0.66)
      ..lineTo(w * 0.75, h * 0.71)
      ..lineTo(w * 0.83, h * 0.60);
    canvas.drawPath(checkPath, checkPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
