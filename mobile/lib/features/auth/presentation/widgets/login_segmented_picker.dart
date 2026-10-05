import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/login_method.dart';

/// Segmented Picker khớp với thiết kế `SegmentedPicker/login-method`:
/// - Rộng 331px, Cao 42px, Padding 4px, Gap 4px, Nền [AppColors.surfaceMuted] (#F2F1ED), Bo tròn 9999px
/// - Segment active: 159.5px x 34px, Nền [AppColors.surface] (#FFFFFF) với bóng đổ [AppShadows.cardElevation].
class LoginSegmentedPicker extends StatelessWidget {
  const LoginSegmentedPicker({
    super.key,
    required this.selectedMethod,
    required this.onMethodChanged,
  });

  final LoginMethod selectedMethod;
  final ValueChanged<LoginMethod> onMethodChanged;

  @override
  Widget build(BuildContext context) {
    const double containerWidth = 331.0;
    const double containerHeight = 42.0;
    const double padding = 4.0;
    const double segmentWidth = 159.5;
    const double segmentHeight = 34.0;

    final isPhone = selectedMethod == LoginMethod.phone;

    return Container(
      width: containerWidth,
      height: containerHeight,
      padding: const EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(9999.0),
      ),
      child: Stack(
        children: [
          // Con trượt động màu trắng (Pill Indicator)
          AnimatedAlign(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOutCubic,
            alignment: isPhone ? Alignment.centerLeft : Alignment.centerRight,
            child: Container(
              width: segmentWidth,
              height: segmentHeight,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(9999.0),
                boxShadow: AppShadows.cardElevation,
              ),
            ),
          ),
          // Hai nút bấm chọn
          Row(
            children: [
              // Tab 1: Số điện thoại
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onMethodChanged(LoginMethod.phone),
                  child: SizedBox(
                    height: segmentHeight,
                    child: Center(
                      child: Text(
                        'Số điện thoại',
                        style: TextStyle(
                          fontSize: 14.0,
                          fontWeight: isPhone ? FontWeight.w500 : FontWeight.w400,
                          height: 20.0 / 14.0,
                          color: isPhone ? AppColors.ink : AppColors.inkMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4.0),
              // Tab 2: Email
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onMethodChanged(LoginMethod.email),
                  child: SizedBox(
                    height: segmentHeight,
                    child: Center(
                      child: Text(
                        'Email',
                        style: TextStyle(
                          fontSize: 14.0,
                          fontWeight: !isPhone ? FontWeight.w500 : FontWeight.w400,
                          height: 20.0 / 14.0,
                          color: !isPhone ? AppColors.ink : AppColors.inkMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
