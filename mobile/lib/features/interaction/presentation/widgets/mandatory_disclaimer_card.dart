import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';

/// Thẻ tuyên bố miễn trừ trách nhiệm y tế bắt buộc (Mandatory Disclaimer).
///
/// Bắt buộc xuất hiện trên 100% màn hình cảnh báo tương tác thuốc (DoD & QA.04).
/// Cố định ở chân màn hình, TUYỆT ĐỐI không có nút tắt/đóng (X) hay thao tác ẩn.
class MandatoryDisclaimerCard extends StatelessWidget {
  const MandatoryDisclaimerCard({
    super.key,
    this.padding = const EdgeInsets.all(AppSpacing.md),
  });

  /// Câu chữ tuyên bố miễn trừ trách nhiệm chuẩn theo yêu cầu dự án.
  static const String disclaimerText =
      'Lưu ý: Thông tin cảnh báo tương tác thuốc chỉ mang tính chất tham khảo, '
      'không thay thế cho chỉ định hoặc tư vấn chuyên môn của bác sĩ/dược sĩ.';

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('mandatory_disclaimer_card'),
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.cautionBg,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: AppColors.caution.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.shield_outlined,
            color: AppColors.cautionText,
            size: 20,
          ),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              disclaimerText,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                height: 1.4,
                color: AppColors.cautionText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
