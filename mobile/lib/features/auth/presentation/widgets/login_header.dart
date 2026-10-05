import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/app_assets.dart';

/// Header widget cho màn hình Đăng nhập Mobile (S00c):
/// - Ảnh mascot DrugTime ([AppAssets.mascotHello]) cao 150px
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
          // mascot DrugTime (ảnh gốc 1223x1286; giải mã ở độ phân giải vừa đủ hiển thị)
          Image.asset(
            AppAssets.mascotHello,
            height: 150.0,
            cacheHeight: 450,
            fit: BoxFit.contain,
            semanticLabel: 'DrugTime',
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
}
