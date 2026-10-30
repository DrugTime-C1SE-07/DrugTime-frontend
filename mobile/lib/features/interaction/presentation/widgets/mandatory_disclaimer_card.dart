import 'package:flutter/material.dart';

/// Thẻ tuyên bố miễn trừ trách nhiệm y tế bắt buộc (Mandatory Disclaimer).
///
/// Thiết kế tinh gọn, thanh lịch (Clean UX) theo chuẩn Figma prototype mới nhất:
/// - Xuất hiện 100% ở chân màn hình, TUYỆT ĐỐI không có nút tắt/đóng (X).
/// - Dạng dải banner mỏng màu hổ phách/vàng ấm, chữ ngắn gọn, giảm tải nhận thức.
class MandatoryDisclaimerCard extends StatelessWidget {
  const MandatoryDisclaimerCard({
    super.key,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
      decoration: const BoxDecoration(
        color: Color(0xFFFEF3E2),
        borderRadius: BorderRadius.all(Radius.circular(10)),
        border: Border.fromBorderSide(
          BorderSide(
            color: Color(0xFFFDE68A),
            width: 1,
          ),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.shield_outlined,
            color: Color(0xFFD97706),
            size: 16,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              disclaimerText,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                height: 1.35,
                color: Color(0xFF92400E),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
