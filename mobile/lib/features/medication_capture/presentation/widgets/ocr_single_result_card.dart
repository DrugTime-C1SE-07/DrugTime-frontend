import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/ocr_models.dart';

/// The one medicine recognised on the box (`matched`), sized for older users:
/// large name, explicit confirmation, and a way out when it is not the right one
/// (QD-39: the user always confirms).
class OcrSingleResultCard extends StatelessWidget {
  const OcrSingleResultCard({
    super.key = const Key('ocr-single-result'),
    required this.candidate,
    required this.strengthUnverified,
    required this.onConfirm,
    required this.onNotThis,
    this.checkReminder = false,
  });

  final OcrCandidate candidate;

  /// `strength_unverified`: the box's mg was not read, so ask the user to check it.
  final bool strengthUnverified;

  /// `low_confidence`: the server is not sure, so ask to compare name and mg with the
  /// box before confirming (adhoc-20261116 01 §6.1, QD-39). Replaces the mg hint.
  final bool checkReminder;
  final VoidCallback onConfirm, onNotThis;

  @override
  Widget build(BuildContext context) {
    String? present(String? value) =>
        value == null || value.trim().isEmpty ? null : value;
    final strength = present(candidate.strengthText);
    final form = present(candidate.dosageForm);
    final ingredient = present(candidate.activeIngredient);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(candidate.name, style: AppTextStyles.display),
                ),
              ),
              if (candidate.score > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.brandTint,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${(candidate.score * 100).round()}% khớp',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.brand,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          if (strength != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text('Hàm lượng: $strength', style: AppTextStyles.title),
          ],
          if (form != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text('Dạng: $form', style: AppTextStyles.body),
          ],
          if (ingredient != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text('Hoạt chất: $ingredient',
                style: AppTextStyles.body.copyWith(color: AppColors.inkMuted)),
          ],
          if (checkReminder || strengthUnverified) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.cautionBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                const Icon(Icons.warning_amber_rounded,
                    color: AppColors.caution),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                      checkReminder
                          ? 'Hãy đối chiếu tên và số mg với vỏ hộp'
                          : 'Hãy xem số mg trên vỏ hộp',
                      style: AppTextStyles.bodyStrong
                          .copyWith(color: AppColors.cautionText)),
                ),
              ]),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(AppSizes.primaryButton)),
            onPressed: onConfirm,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Đúng thuốc này'),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(AppSizes.primaryButton)),
            onPressed: onNotThis,
            child: const Text('Không phải thuốc này'),
          ),
        ],
      ),
    );
  }
}
