import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';

/// Thẻ tuyên bố miễn trừ trách nhiệm y tế bắt buộc (Mandatory Disclaimer).
///
/// Bắt buộc xuất hiện trên 100% màn hình cảnh báo tương tác thuốc (DoD & QA.04).
/// Cố định ở chân màn hình, TUYỆT ĐỐI không có nút tắt/đóng (X) hay thao tác ẩn.
/// Thiết kế chuẩn theo Figma prototype `page_127_Image556.png`.
class MandatoryDisclaimerCard extends StatelessWidget {
  const MandatoryDisclaimerCard({
    super.key,
    this.padding = const EdgeInsets.all(AppSpacing.md),
  });

  /// Câu chữ tuyên bố miễn trừ trách nhiệm chuẩn theo yêu cầu dự án (DoD & QA.04).
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
        color: const Color(0xFFFEEBD9), // Nền màu cam đào chuẩn Figma Prototype
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: const Color(0xFFFAD2B0),
          width: 1.2,
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.health_and_safety_rounded,
                color: Color(0xFF8A4500),
                size: 20,
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'LƯU Ý Y TẾ BẮT BUỘC',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: Color(0xFF8A4500),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.xs),
          Text(
            disclaimerText,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              height: 1.45,
              color: Color(0xFF7A3E00),
            ),
          ),
        ],
      ),
    );
  }
}
