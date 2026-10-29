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
/// Tuân thủ nghiêm ngặt bất biến kiến trúc CD06:
/// - 3 trạng thái kết quả tất định: có tương tác, đã kiểm tra không thấy, chưa đủ dữ liệu.
/// - Tuyệt đối không khẳng định "an toàn".
/// - Mandatory Disclaimer luôn xuất hiện 100% ở chân màn hình, không thể tắt.
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
        title: const Text('Kiểm tra tương tác thuốc'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.ink,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Nội dung chính có thể cuộn
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.page,
                  vertical: AppSpacing.lg,
                ),
                child: _buildStateContent(context),
              ),
            ),

            // Khối cố định ở chân màn hình: Mandatory Disclaimer + Nút hành động
            _buildBottomBar(context),
          ],
        ),
      ),
    );
  }

  /// Xây dựng nội dung tùy theo 3 trạng thái của báo cáo.
  Widget _buildStateContent(BuildContext context) {
    return switch (report.status) {
      InteractionStatus.hasInteractions => _buildHasInteractionsContent(context),
      InteractionStatus.noKnownInteractions =>
        _buildNoKnownInteractionsContent(context),
      InteractionStatus.insufficientData =>
        _buildInsufficientDataContent(context),
    };
  }

  /// Trạng thái 1: Có tương tác thuốc–thuốc.
  Widget _buildHasInteractionsContent(BuildContext context) {
    final count = report.pairs.length;
    final hasContraindication = report.pairs.any(
      (p) => p.severity == InteractionSeverity.contraindicated,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Banner thông báo số lượng tương tác
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: hasContraindication ? AppColors.dangerBg : AppColors.cautionBg,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: hasContraindication
                  ? AppColors.danger.withValues(alpha: 0.4)
                  : AppColors.caution.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              Icon(
                hasContraindication
                    ? Icons.warning_amber_rounded
                    : Icons.info_outline,
                color: hasContraindication
                    ? AppColors.danger
                    : AppColors.cautionText,
                size: 28,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Phát hiện $count tương tác thuốc có thể xảy ra',
                      style: AppTextStyles.bodyStrong.copyWith(
                        color: hasContraindication
                            ? AppColors.danger
                            : AppColors.cautionText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Đơn thuốc của bạn có các hoạt chất có thể ảnh hưởng lẫn nhau. '
                      'Hãy đọc kỹ các cảnh báo dưới đây.',
                      style: AppTextStyles.caption.copyWith(
                        color: hasContraindication
                            ? AppColors.danger
                            : AppColors.cautionText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // Danh sách đầy đủ tất cả các cặp thuốc tương tác
        ...report.pairs.map((pair) => InteractionPairCard(pair: pair)),
      ],
    );
  }

  /// Trạng thái 2: Đã kiểm tra không thấy tương tác trong dữ liệu hiện tại (CD06).
  ///
  /// TUYỆT ĐỐI KHÔNG chứa từ "an toàn".
  Widget _buildNoKnownInteractionsContent(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xxl,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: AppColors.brandTint,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline,
                color: AppColors.brand,
                size: 48,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            const Text(
              'Kết quả kiểm tra',
              style: AppTextStyles.heading,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Không tìm thấy tương tác đã biết trong cơ sở dữ liệu hiện tại',
              key: Key('no_known_interactions_mandatory_text'),
              style: AppTextStyles.bodyStrong,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Hệ thống đã đối soát các hoạt chất trong danh sách thuốc với cơ sở '
              'dữ liệu dược thư quốc gia. Vui lòng luôn tuân thủ chỉ dẫn dùng thuốc '
              'của bác sĩ điều trị.',
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Trạng thái 3: Chưa đủ dữ liệu hoạt chất để kiểm tra (CD06).
  Widget _buildInsufficientDataContent(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xl,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: AppColors.cautionBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.help_outline_rounded,
                color: AppColors.caution,
                size: 48,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            const Text(
              'Chưa đủ dữ liệu hoạt chất',
              style: AppTextStyles.heading,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Một số thuốc chưa có dữ liệu hoạt chất để kiểm tra tương tác, '
              'vui lòng tham khảo ý kiến bác sĩ hoặc dược sĩ.',
              key: Key('insufficient_data_mandatory_text'),
              style: AppTextStyles.bodyStrong,
              textAlign: TextAlign.center,
            ),
            if (report.insufficientDataMedications.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.field),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Các thuốc chưa có dữ liệu hoạt chất:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkMuted,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    ...report.insufficientDataMedications.map(
                      (name) => Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.circle,
                              size: 6,
                              color: AppColors.caution,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              name,
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Khối cố định ở chân màn hình gồm Mandatory Disclaimer Card và các nút bấm.
  Widget _buildBottomBar(BuildContext context) {
    final hasInteractions = report.hasInteractions;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.page),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 1),
        ),
        boxShadow: AppShadows.cardElevation,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Mandatory Disclaimer Card (Luôn luôn xuất hiện 100%, không thể ẩn)
          const MandatoryDisclaimerCard(),
          const SizedBox(height: AppSpacing.md),

          // 2. Nút hành động
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
                        'Vui lòng liên hệ bác sĩ hoặc dược sĩ chuyên môn để được tư vấn điều chỉnh đơn thuốc.',
                      ),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.phone_in_talk_outlined, size: 20),
              label: const Text('Tham khảo ý kiến bác sĩ'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: AppColors.onBrand,
                minimumSize: const Size.fromHeight(AppSizes.primaryButton),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.field),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
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
                foregroundColor: AppColors.ink,
                side: const BorderSide(color: AppColors.border),
                minimumSize: const Size.fromHeight(AppSizes.primaryButton),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.field),
                ),
              ),
              child: const Text('Tôi đã hiểu và tiếp tục'),
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
                minimumSize: const Size.fromHeight(AppSizes.primaryButton),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.field),
                ),
              ),
              child: const Text('Tôi đã hiểu và tiếp tục'),
            ),
          ],
        ],
      ),
    );
  }
}
