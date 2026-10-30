import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/drug_interaction_result.dart';

/// Card hiển thị chi tiết một cặp tương tác thuốc–thuốc theo phong cách Figma Prototype.
class InteractionPairCard extends StatelessWidget {
  const InteractionPairCard({
    super.key,
    required this.pair,
  });

  final DrugInteractionPair pair;

  @override
  Widget build(BuildContext context) {
    final severity = pair.severity;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: AppColors.border,
          width: 1,
        ),
        boxShadow: AppShadows.cardElevation,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Dải băng Header mức độ nghiêm trọng (Chuẩn màu & Icon từ Figma Prototype)
            _buildSeverityHeader(severity),

            // 2. Nội dung chi tiết cặp tương tác
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Hàng hiển thị 2 tên thuốc
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F4FC),
                      borderRadius: BorderRadius.circular(AppRadius.field),
                      border: Border.all(color: const Color(0xFFDCE5F5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.medication_rounded,
                          size: 18,
                          color: AppColors.brand,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            pair.firstDrugName,
                            style: AppTextStyles.bodyStrong.copyWith(
                              fontSize: 14,
                              color: AppColors.ink,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(
                            Icons.swap_horiz_rounded,
                            size: 20,
                            color: AppColors.brand,
                          ),
                        ),
                        const Icon(
                          Icons.medication_rounded,
                          size: 18,
                          color: AppColors.brand,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            pair.secondDrugName,
                            style: AppTextStyles.bodyStrong.copyWith(
                              fontSize: 14,
                              color: AppColors.ink,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Khối Cơ chế tương tác dược lý / lâm sàng
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: severity == InteractionSeverity.contraindicated ||
                              severity == InteractionSeverity.severe
                          ? const Color(0xFFFDF2F2)
                          : const Color(0xFFFEF9EE),
                      borderRadius: BorderRadius.circular(AppRadius.field),
                      border: Border.all(
                        color: severity == InteractionSeverity.contraindicated ||
                                severity == InteractionSeverity.severe
                            ? const Color(0xFFFDE2E2)
                            : const Color(0xFFFDE8C7),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.science_outlined,
                              size: 16,
                              color: severity == InteractionSeverity.contraindicated ||
                                      severity == InteractionSeverity.severe
                                  ? AppColors.danger
                                  : AppColors.cautionText,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              'Cơ chế dược lực học & lâm sàng:',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: severity == InteractionSeverity.contraindicated ||
                                        severity == InteractionSeverity.severe
                                    ? AppColors.danger
                                    : AppColors.cautionText,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          pair.description,
                          style: AppTextStyles.body.copyWith(
                            fontSize: 13.5,
                            height: 1.45,
                            color: AppColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Khối Hướng dẫn xử trí lâm sàng (nếu có)
                  if (pair.recommendation != null &&
                      pair.recommendation!.trim().isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F6F4),
                        borderRadius: BorderRadius.circular(AppRadius.field),
                        border: Border.all(color: const Color(0xFFCCECE7)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.medical_services_outlined,
                                size: 16,
                                color: AppColors.brand,
                              ),
                              SizedBox(width: AppSpacing.xs),
                              Text(
                                'Hướng dẫn xử trí lâm sàng:',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.brandStrong,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            pair.recommendation!,
                            style: AppTextStyles.body.copyWith(
                              fontSize: 13.5,
                              height: 1.45,
                              color: AppColors.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Nguồn tra cứu chuẩn Dược thư / Bộ Y Tế
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      const Icon(
                        Icons.menu_book_outlined,
                        size: 13,
                        color: AppColors.inkMuted,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          pair.referenceSource ??
                              'Căn cứ: Quyết định 5948/QĐ-BYT & Dược thư Quốc gia Việt Nam',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontStyle: FontStyle.italic,
                            color: AppColors.inkMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Xây dựng banner header tương ứng với 4 mức nghiêm trọng từ Figma Prototype.
  Widget _buildSeverityHeader(InteractionSeverity severity) {
    final (bgColor, icon, title, badgeColor, badgeLabel) = switch (severity) {
      InteractionSeverity.contraindicated => (
          const Color(0xFFBA1A1A),
          Icons.do_not_disturb_on_rounded,
          'CHỐNG CHỈ ĐỊNH PHỐI HỢP',
          const Color(0xFF8E1414),
          severity.label,
        ),
      InteractionSeverity.severe => (
          const Color(0xFFDC2626),
          Icons.warning_rounded,
          'TƯƠNG TÁC NGHIÊM TRỌNG',
          const Color(0xFF991B1B),
          severity.label,
        ),
      InteractionSeverity.moderate => (
          const Color(0xFFD97706),
          Icons.report_problem_rounded,
          'THẬN TRỌNG KHI KẾT HỢP',
          const Color(0xFFB45309),
          severity.label,
        ),
      InteractionSeverity.mild => (
          const Color(0xFF4B5563),
          Icons.info_rounded,
          'THEO DÕI THÊM',
          const Color(0xFF374151),
          severity.label,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      color: bgColor,
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.white),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              badgeLabel,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
