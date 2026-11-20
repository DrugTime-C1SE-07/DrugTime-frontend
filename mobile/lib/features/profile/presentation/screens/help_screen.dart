import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/profile_flow_widgets.dart';

/// Màn hình Trợ giúp & FAQ — theo thiết kế Figma S08
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: profileFlowCanvas,
      appBar: const ProfileFlowHeader('Trợ giúp & Hỗ trợ'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            // Hero support card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.brandTint,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFC7E3DF)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.help_outline,
                      color: AppColors.brand,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Chúng tôi có thể giúp gì cho bạn?',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF01554F),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Tìm câu trả lời nhanh hoặc liên hệ đội ngũ hỗ trợ y tế DrugTime.',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.35,
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // FAQ Section
            const Text(
              'CÂU HỎI THƯỜNG GẶP (FAQ)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: Color(0xFF254A45),
              ),
            ),
            const SizedBox(height: 8),
            Material(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Column(
                  children: [
                    _FaqTile(
                      question: 'Làm thế nào để thêm thuốc vào lịch uống?',
                      answer:
                          'Tại tab "Thuốc" hoặc "Trang chủ", bạn nhấn nút "+ Thêm thuốc". Bạn có thể chụp quét vỏ thuốc bằng camera (OCR) để tự nhận diện hoặc nhập tên thuốc và giờ uống thủ công.',
                    ),
                    Divider(height: 1, color: AppColors.border),
                    _FaqTile(
                      question: 'Tính năng kiểm tra tương tác hoạt động thế nào?',
                      answer:
                          'Hệ thống tự động đối chiếu các hoạt chất trong tủ thuốc của bạn với cơ sở dữ liệu dược thư để phát hiện tương tác thuốc - thuốc và thuốc - thức ăn, giúp phân loại mức độ nguy cơ từ cần theo dõi đến tránh phối hợp.',
                    ),
                    Divider(height: 1, color: AppColors.border),
                    _FaqTile(
                      question: 'Làm sao để người thân theo dõi lịch uống thuốc?',
                      answer:
                          'Vào tab "Hồ sơ" > "Người giám sát", nhấn "Mời người thân". Bạn có thể chia sẻ mã QR hoặc link mời để người thân liên kết và nhận cảnh báo nếu bạn bỏ lỡ liều.',
                    ),
                    Divider(height: 1, color: AppColors.border),
                    _FaqTile(
                      question: 'Làm gì khi lỡ quên hoặc trễ giờ uống thuốc?',
                      answer:
                          'Khi vào màn hình "Lịch nhắc", bạn chọn liều thuốc bị trễ hoặc bỏ lỡ và nhấn nút "Uống bù" để cập nhật trạng thái đã dùng thuốc chính xác.',
                    ),
                    Divider(height: 1, color: AppColors.border),
                    _FaqTile(
                      question: 'Dữ liệu y tế của tôi có được bảo mật không?',
                      answer:
                          'Mọi thông tin lịch uống và hồ sơ bệnh nền của bạn được mã hóa và bảo vệ nghiêm ngặt. Chỉ những người thân được bạn cấp quyền rõ ràng mới có thể xem thông tin tuân thủ liều.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Support Contact Section
            const Text(
              'KÊNH HỖ TRỢ TRỰC TIẾP',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: Color(0xFF254A45),
              ),
            ),
            const SizedBox(height: 8),
            Material(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE7F3ED),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.email_outlined,
                        color: Color(0xFF21684D),
                        size: 22,
                      ),
                    ),
                    title: const Text(
                      'Email hỗ trợ',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    subtitle: const Text(
                      'hotro@drugtime.vn',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.brand,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios,
                        size: 14, color: AppColors.inkMuted),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Đã sao chép email: hotro@drugtime.vn'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, color: AppColors.border),
                  ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1DA),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.phone_outlined,
                        color: Color(0xFF874607),
                        size: 22,
                      ),
                    ),
                    title: const Text(
                      'Tổng đài tư vấn',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    subtitle: const Text(
                      '1900 8888 (08:00 - 18:00)',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.inkMuted,
                      ),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios,
                        size: 14, color: AppColors.inkMuted),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Tổng đài hỗ trợ: 1900 8888'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
            const SizedBox(height: 28),

            // App version info footer
            const Center(
              child: Column(
                children: [
                  Text(
                    'DrugTime Mobile v1.0.0 (Build 42)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.inkMuted,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '© 2026 DrugTime Team. Nền tảng tuân thủ điều trị.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xB35B6169),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        iconColor: AppColors.brand,
        collapsedIconColor: AppColors.inkMuted,
        title: Text(
          question,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
        children: [
          Text(
            answer,
            style: const TextStyle(
              fontSize: 13,
              height: 1.45,
              color: Color(0xFF5B6169),
            ),
          ),
        ],
      ),
    );
  }
}
