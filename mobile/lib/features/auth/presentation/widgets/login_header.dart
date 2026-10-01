import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';

/// Header widget cho màn hình Đăng nhập Mobile (S00c):
/// - Logo slot 60x60 bo góc 16px, nền [AppColors.brandTint]
/// - Tiêu đề 22px, bold 700 [AppColors.ink]
/// - Phụ đề 13px, regular 400, line-height 19px [AppColors.inkMuted]
class LoginHeader extends StatelessWidget {
  const LoginHeader({
    super.key,
    this.heading = 'Đăng nhập',
    this.subheading =
        'Nhập số điện thoại hoặc email để nhận mã xác thực OTP đăng nhập vào tài khoản DrugTime của bạn.',
  });

  final String heading;
  final String subheading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // logo-slot-mini (60x60)
          Container(
            width: 60.0,
            height: 60.0,
            decoration: BoxDecoration(
              color: AppColors.brandTint,
              borderRadius: BorderRadius.circular(16.0),
              border: Border.all(color: AppColors.border, width: 1.0),
            ),
            child: Center(
              child: _buildBrandedLogo(),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // heading (22px / line-height 30px / 700 bold)
          Text(
            heading,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22.0,
              fontWeight: FontWeight.w700,
              height: 30.0 / 22.0,
              color: AppColors.ink,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // subheading (13px / line-height 19px / 400 regular)
          Text(
            subheading,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13.0,
              fontWeight: FontWeight.w400,
              height: 19.0 / 13.0,
              color: AppColors.inkMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandedLogo() {
    return CustomPaint(
      size: const Size(36.0, 36.0),
      painter: _DrugTimeLogoPainter(),
    );
  }
}

class _DrugTimeLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Viên thuốc xoay góc 45 độ
    final pillPaint = Paint()
      ..color = AppColors.brand
      ..style = PaintingStyle.fill;

    canvas.save();
    canvas.translate(w * 0.5, h * 0.5);
    canvas.rotate(-0.6);

    // Nửa trái
    final rectLeft = RRect.fromRectAndCorners(
      Rect.fromLTWH(-w * 0.38, -h * 0.18, w * 0.38, h * 0.36),
      topLeft: Radius.circular(h * 0.18),
      bottomLeft: Radius.circular(h * 0.18),
    );
    canvas.drawRRect(rectLeft, pillPaint);

    // Nửa phải
    final rectRight = RRect.fromRectAndCorners(
      Rect.fromLTWH(0, -h * 0.18, w * 0.38, h * 0.36),
      topRight: Radius.circular(h * 0.18),
      bottomRight: Radius.circular(h * 0.18),
    );
    canvas.drawRRect(rectRight, pillPaint..color = const Color(0xFF0D7A71));

    // Đường ngăn giữa viên thuốc
    final linePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(0, -h * 0.18), Offset(0, h * 0.18), linePaint);

    // Chữ thập y tế nhỏ bên trái
    final plusPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(-w * 0.22, -h * 0.07), Offset(-w * 0.22, h * 0.07), plusPaint);
    canvas.drawLine(Offset(-w * 0.29, 0), Offset(-w * 0.15, 0), plusPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
