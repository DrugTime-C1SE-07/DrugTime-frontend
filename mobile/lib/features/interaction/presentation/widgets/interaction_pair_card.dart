import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/drug_interaction_result.dart';

/// Card hiển thị chi tiết một cặp tương tác thuốc–thuốc.
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
          color: severity.badgeColor.withValues(alpha: 0.3),
          width: 1.2,
        ),
        boxShadow: AppShadows.cardElevation,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Tên 2 thuốc + Badge mức độ nghiêm trọng
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: severity.badgeBackgroundColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppRadius.card - 1),
                topRight: Radius.circular(AppRadius.card - 1),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.medication_outlined,
                            size: 16,
                            color: AppColors.inkMuted,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              '${pair.firstDrugName}  ⮂  ${pair.secondDrugName}',
                              style: AppTextStyles.bodyStrong.copyWith(
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                // Badge mức độ nghiêm trọng
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: severity.badgeColor,
                    borderRadius: BorderRadius.circular(AppRadius.field),
                  ),
                  child: Text(
                    severity.label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Body: Cơ chế / Mô tả lâm sàng
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cơ chế tương tác:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkMuted,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  pair.description,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),

                // Lời khuyên / Khuyến cáo xử trí
                if (pair.recommendation != null &&
                    pair.recommendation!.trim().isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(AppRadius.field),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.medical_services_outlined,
                          size: 18,
                          color: AppColors.brand,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Hướng dẫn xử trí:',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.brandStrong,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                pair.recommendation!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.4,
                                  color: AppColors.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Nguồn tham chiếu (Dược thư quốc gia, v.v.)
                if (pair.referenceSource != null &&
                    pair.referenceSource!.trim().isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Nguồn: ${pair.referenceSource}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: AppColors.inkDisabled,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
