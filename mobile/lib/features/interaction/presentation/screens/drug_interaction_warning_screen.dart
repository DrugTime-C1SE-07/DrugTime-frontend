import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/app_assets.dart';
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
/// Tuân thủ nghiêm ngặt:
/// - Bất biến kiến trúc CD06: Engine tất định, 3 trạng thái rõ ràng, tuyệt đối không suy đoán "an toàn".
/// - Tiêu chuẩn DoD & QA.04: Mandatory Disclaimer cố định 100% ở chân màn hình, không thể tắt/ẩn.
/// - Giao diện trực quan chuẩn Figma Prototype (`page_127_Image556.png` & `page_130_Image562.png`).
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
          'Kiểm tra tương tác thuốc',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Thông tin Dược thư',
            icon: const Icon(Icons.info_outline, color: AppColors.brand),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Cơ sở dữ liệu tương tác thuốc đối soát từ Dược thư Quốc gia Việt Nam & Quyết định 5948/QĐ-BYT.',
                  ),
                ),
              );
            },
          ),
        ],
        backgroundColor: AppColors.surface,
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
                  vertical: AppSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Patient Context Banner (Chuẩn Figma Prototype)
                    _buildPatientBanner(context),
                    const SizedBox(height: AppSpacing.md),

                    // 2. Card "Đã đối soát X hoạt chất" (Chuẩn Figma Prototype nếu có danh sách tường minh)
                    if (report.hasExplicitCheckedMedications) ...[
                      _buildCheckedMedicationsCard(context),
                      const SizedBox(height: AppSpacing.md),
                    ],

                    // 3. Nội dung theo 3 trạng thái kết quả
                    _buildStateContent(context),
                  ],
                ),
              ),
            ),

            // Khối cố định ở chân màn hình: Mandatory Disclaimer + Nút hành động
            _buildBottomBar(context),
          ],
        ),
      ),
    );
  }

  /// 1. Patient Context Banner (Hiển thị hồ sơ bệnh nhân đang được đối soát)
  Widget _buildPatientBanner(BuildContext context) {
    final patientName = report.patientName ?? 'Bác Nguyễn Văn An (Bố)';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4FC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCE5F5)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: Color(0xFFDCFCE7),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified_user_rounded,
              size: 18,
              color: Color(0xFF16A34A),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patientName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Ủy quyền BR-18 • Ghi nhật ký y tế (CD02)',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFD8E2FB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.text_fields_rounded, size: 14, color: Color(0xFF1E40AF)),
                SizedBox(width: 4),
                Text(
                  'Chữ lớn',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E40AF),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 2. Card "Đã đối soát X hoạt chất" (Danh sách các thuốc được kiểm tra tương tác)
  Widget _buildCheckedMedicationsCard(BuildContext context) {
    final meds = report.checkedMedications;
    final displayMeds = meds.isNotEmpty
        ? meds
        : ['Clopidogrel 75mg', 'Omeprazole 20mg', 'Aspirin 81mg'];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.cardElevation,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.science_outlined,
                size: 20,
                color: AppColors.brand,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Đã đối soát ${displayMeds.length} hoạt chất',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const Spacer(),
              const Row(
                children: [
                  Icon(
                    Icons.edit_note_rounded,
                    size: 18,
                    color: AppColors.brand,
                  ),
                  SizedBox(width: 2),
                  Text(
                    'Sửa danh sách',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.brand,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: displayMeds.map((medName) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFD2F3EE),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFB0E5DE)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.medication_rounded,
                      size: 14,
                      color: AppColors.brand,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      medName,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brand,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// 3. Phân nhánh hiển thị theo 3 trạng thái kết quả của Báo cáo
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
        // Banner cảnh báo nổi bật (Prominent Alert Banner từ Figma `page_127_Image556.png`)
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: const Color(0xFFFDE8E8),
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: const Color(0xFFF8B4B4),
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFBA1A1A),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasContraindication
                              ? 'CẢNH BÁO NGHIÊM TRỌNG CẤP 1'
                              : 'CẢNH BÁO TƯƠNG TÁC THUỐC',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: Color(0xFFBA1A1A),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Phát hiện $count tương tác thuốc có thể xảy ra',
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            height: 1.25,
                            color: Color(0xFF7A0000),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              // Khối căn cứ pháp lý dược lý từ Bộ Y Tế
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8D7D7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.gavel_rounded,
                      size: 15,
                      color: Color(0xFF7A0000),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Căn cứ danh mục tương tác thuốc chống chỉ định — Quyết định 5948/QĐ-BYT (Bộ Y Tế).',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF7A0000),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // Tiêu đề danh mục "Chi tiết cặp tương tác" kèm huy hiệu số lượng
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Chi tiết cặp tương tác',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFEBF0FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$count phát hiện',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2B55A2),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),

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
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xl,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Linh vật DrugTime Mascot đối soát tương tác
            SizedBox(
              width: 96,
              height: 96,
              child: Image.asset(
                AppAssets.mascotInteraction,
                width: 96,
                height: 96,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(
                  width: 96,
                  height: 96,
                  decoration: const BoxDecoration(
                    color: AppColors.brandTint,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_outline,
                    color: AppColors.brand,
                    size: 54,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'Kết quả kiểm tra tương tác',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified_rounded, size: 14, color: Color(0xFF16A34A)),
                  SizedBox(width: 4),
                  Text(
                    'Đã đối soát danh mục QĐ 5948/BYT',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Câu chữ bắt buộc chuẩn DoD
            const Text(
              'Không tìm thấy tương tác đã biết trong cơ sở dữ liệu hiện tại',
              key: Key('no_known_interactions_mandatory_text'),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.brandStrong,
                height: 1.35,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(AppRadius.field),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: const Text(
                'Hệ thống đã đối soát các hoạt chất trong danh sách thuốc với cơ sở '
                'dữ liệu Dược thư Quốc gia Việt Nam và Quyết định 5948/QĐ-BYT (Bộ Y Tế). '
                'Vui lòng luôn tuân thủ chỉ dẫn dùng thuốc của bác sĩ điều trị.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: AppColors.inkMuted,
                ),
                textAlign: TextAlign.center,
              ),
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
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xl,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Linh vật DrugTime Mascot Thinking
            SizedBox(
              width: 96,
              height: 96,
              child: Image.asset(
                AppAssets.mascotThinking,
                width: 96,
                height: 96,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(
                  width: 96,
                  height: 96,
                  decoration: const BoxDecoration(
                    color: AppColors.cautionBg,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.help_outline_rounded,
                    color: AppColors.caution,
                    size: 54,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'Chưa đủ dữ liệu hoạt chất',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFD97706)),
                  SizedBox(width: 4),
                  Text(
                    'Dữ liệu chưa hoàn thiện',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFD97706),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Câu chữ bắt buộc chuẩn DoD
            const Text(
              'Một số thuốc chưa có dữ liệu hoạt chất để kiểm tra tương tác, '
              'vui lòng tham khảo ý kiến bác sĩ hoặc dược sĩ.',
              key: Key('insufficient_data_mandatory_text'),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.cautionText,
                height: 1.35,
              ),
              textAlign: TextAlign.center,
            ),
            if (report.insufficientDataMedications.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
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
                        fontWeight: FontWeight.w700,
                        color: AppColors.inkMuted,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    ...report.insufficientDataMedications.map(
                      (name) => Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.help_outline_rounded,
                              size: 14,
                              color: AppColors.caution,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              name,
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 13,
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
          // 1. Mandatory Disclaimer Card (Luôn luôn xuất hiện 100%, không thể ẩn, không có nút X)
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
              label: const Text(
                'Tham khảo ý kiến bác sĩ',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
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
              child: const Text(
                'Tôi đã hiểu và tiếp tục',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
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
                minimumSize: const Size.fromHeight(AppSizes.primaryButton),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.field),
                ),
              ),
              child: const Text(
                'Tôi đã hiểu và tiếp tục',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
