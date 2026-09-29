import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/login_method.dart';
import 'mascot_protect_widget.dart';

/// Header của màn hình Xác thực OTP:
/// - Kích thước: 327px x 181px, gap 14px, căn giữa
/// - MascotSlot: 96px x 88px (Viên thuốc bảo vệ an toàn y tế)
/// - Heading: 20px Inter bold 700, #211D1D ("Xác thực OTP")
/// - Subheading: 13px Inter regular 400, #5B6169 kèm thông tin đích gửi
class OtpHeader extends StatelessWidget {
  const OtpHeader({
    super.key,
    required this.method,
    required this.targetIdentifier,
  });

  final LoginMethod method;
  final String targetIdentifier;

  @override
  Widget build(BuildContext context) {
    final isPhone = method == LoginMethod.phone;
    final maskedTarget = isPhone
        ? AuthValidator.maskPhone(targetIdentifier)
        : AuthValidator.maskEmail(targetIdentifier);

    return SizedBox(
      width: 327.0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // mascot-slot (96x88)
          const MascotProtectWidget(),
          const SizedBox(height: 14.0),

          // heading (20px bold)
          const Text(
            'Xác thực OTP',
            style: TextStyle(
              fontSize: 20.0,
              fontWeight: FontWeight.w700,
              height: 27.0 / 20.0,
              color: AppColors.ink,
              fontFamily: 'Inter',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6.0),

          // subheading (13px regular with masked target)
          Text.rich(
            TextSpan(
              text: isPhone
                  ? 'Đã gửi mã OTP đến số '
                  : 'Đã gửi mã OTP đến email ',
              style: const TextStyle(
                fontSize: 13.0,
                fontWeight: FontWeight.w400,
                height: 19.0 / 13.0,
                color: AppColors.inkMuted,
                fontFamily: 'Inter',
              ),
              children: [
                TextSpan(
                  text: maskedTarget,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
