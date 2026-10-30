import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/drug_interaction_result.dart';
import '../widgets/interaction_pair_card.dart';
import '../widgets/mandatory_disclaimer_card.dart';

/// Tham số điều hướng truyền vào màn hình [DrugInteractionWarningScreen].
class DrugInteractionWarningArgs {
  const DrugInteractionWarningArgs({
    required this.report,
    this.onAcknowledge,
    this.onConsultDoctor,
  });

  final DrugInteractionReport report;
  final VoidCallback? onAcknowledge;
  final VoidCallback? onConsultDoctor;
}

/// Màn hình cảnh báo tương tác thuốc (Task 4.02 / PB24).
///
/// Thiết kế Clean UI/UX đồng bộ chuẩn mực với Prototype DrugTime trên Figma:
/// - Giảm tải nhận thức, ít chữ, nổi bật thông tin nguy cơ & khuyến nghị trong 3 giây.
/// - Tuân thủ bất biến CD06 (3 trạng thái tất định, tuyệt đối không suy đoán "an toàn").
/// - Tuân thủ DoD & QA.04: Mandatory Disclaimer Card mỏng cố định 100% ở chân màn hình, không thể tắt.
class DrugInteractionWarningScreen extends StatelessWidget {
  const DrugInteractionWarningScreen({
    super.key,
    required this.args,
  });

  final DrugInteractionWarningArgs args;

  DrugInteractionReport get report => args.report;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: AppColors.ink,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'Cảnh báo tương tác',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Đóng',
            icon: const Icon(Icons.close_rounded, size: 22, color: AppColors.inkMuted),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
        backgroundColor: AppColors.canvas,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Nội dung chính cuộn mượt
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Phân nhánh hiển thị theo 3 trạng thái
                    _buildStateContent(context),

                    // 2. Card Đơn thuốc đã đối soát (Clean & Compact - chỉ hiển thị khi có truyền danh sách tường minh)
                    if (report.hasExplicitCheckedMedications &&
                        report.status != InteractionStatus.insufficientData) ...[
                      const SizedBox(height: 12),
                      _buildCheckedDrugsCard(context),
                    ],
                  ],
                ),
              ),
            ),

            // Khối cố định ở chân màn hình: Disclaimer Card + Action Buttons
            _buildBottomBar(context),
          ],
        ),
      ),
    );
  }

  /// 1. Nội dung theo 3 trạng thái
  Widget _buildStateContent(BuildContext context) {
    return switch (report.status) {
      InteractionStatus.hasInteractions => _buildHasInteractionsContent(context),
      InteractionStatus.noKnownInteractions =>
        _buildNoKnownInteractionsContent(context),
      InteractionStatus.insufficientData =>
        _buildInsufficientDataContent(context),
    };
  }

  /// Trạng thái 1: Có tương tác thuốc
  Widget _buildHasInteractionsContent(BuildContext context) {
    final count = report.pairs.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Headline nhỏ báo tổng số tương tác
        Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 2),
          child: Text(
            'Phát hiện $count tương tác thuốc cần lưu ý',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.inkMuted,
            ),
          ),
        ),

        // Danh sách các cặp tương tác tinh gọn
        ...report.pairs.map((pair) => InteractionPairCard(pair: pair)),
      ],
    );
  }

  /// Trạng thái 2: Không phát hiện tương tác đã biết (CD06: Tuyệt đối không dùng chữ "an toàn")
  Widget _buildNoKnownInteractionsContent(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: Color(0xFFDCFCE7),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Color(0xFF16A34A),
              size: 32,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'ĐÃ ĐỐI SOÁT QĐ 5948/BYT',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFF15803D),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Không tìm thấy tương tác đã biết trong cơ sở dữ liệu hiện tại',
            key: Key('no_known_interactions_mandatory_text'),
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
              height: 1.35,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          const Text(
            'Các hoạt chất không có tương kỵ nguy hiểm đã biết. Vui lòng luôn tuân thủ đơn thuốc của bác sĩ.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.inkMuted,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Trạng thái 3: Chưa đủ dữ liệu hoạt chất
  Widget _buildInsufficientDataContent(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: Color(0xFFFEF3C7),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.help_outline_rounded,
              color: Color(0xFFD97706),
              size: 30,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Một số thuốc chưa có dữ liệu hoạt chất để kiểm tra tương tác, '
            'vui lòng tham khảo ý kiến bác sĩ hoặc dược sĩ.',
            key: Key('insufficient_data_mandatory_text'),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF92400E),
              height: 1.35,
            ),
            textAlign: TextAlign.center,
          ),
          if (report.insufficientDataMedications.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: report.insufficientDataMedications.map(
                (name) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF92400E),
                    ),
                  ),
                ),
              ).toList(),
            ),
          ],
        ],
      ),
    );
  }

  /// 2. Card Đơn thuốc đã đối soát (Clean & Compact)
  Widget _buildCheckedDrugsCard(BuildContext context) {
    final displayMeds = report.checkedMedications;
    if (displayMeds.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: Color(0xFF16A34A),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Đơn thuốc đã đối soát (${displayMeds.length} thuốc)',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
              const Text(
                'Sửa',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.brand,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: displayMeds.map((name) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.inkMuted,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// 3. Khối chân màn hình cố định
  Widget _buildBottomBar(BuildContext context) {
    final hasInteractions = report.hasInteractions;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 3.1 Mandatory Disclaimer Card (Gọn gàng, không thể tắt/ẩn)
          const MandatoryDisclaimerCard(),
          const SizedBox(height: 10),

          // 3.2 Nút hành động
          if (hasInteractions) ...[
            FilledButton.icon(
              key: const Key('interaction_consult_doctor_button'),
              onPressed: () {
                if (args.onConsultDoctor != null) {
                  args.onConsultDoctor!();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Đang kết nối danh bạ bác sĩ điều trị hoặc tổng đài dược lâm sàng.',
                      ),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.phone_in_talk_outlined, size: 18),
              label: const Text(
                'Tham khảo ý kiến bác sĩ',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: AppColors.onBrand,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Nút "Tôi đã hiểu và tiếp tục" dạng hộp viền đỏ cảnh báo nguy hiểm theo yêu cầu
            OutlinedButton(
              key: const Key('interaction_acknowledge_button'),
              onPressed: () {
                if (args.onAcknowledge != null) {
                  args.onAcknowledge!();
                } else {
                  Navigator.of(context).pop(true);
                }
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                backgroundColor: const Color(0xFFFFF5F5),
                side: const BorderSide(color: AppColors.danger, width: 1.5),
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Tôi đã hiểu và tiếp tục',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.danger,
                ),
              ),
            ),
          ] else ...[
            FilledButton(
              key: const Key('interaction_acknowledge_button'),
              onPressed: () {
                if (args.onAcknowledge != null) {
                  args.onAcknowledge!();
                } else {
                  Navigator.of(context).pop(true);
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: AppColors.onBrand,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Tôi đã hiểu và tiếp tục',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
