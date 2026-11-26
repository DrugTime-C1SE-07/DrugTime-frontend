import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../medication/presentation/widgets/medication_labels.dart';
import '../../domain/ocr_models.dart';

/// The one medicine recognised on the box (`matched` or `low_confidence`), sized for older
/// users: status pill (Figma S07-O2r), large name and one "label: value" row per field, the
/// same layout as the drug information sheet (S07-M2i). The buttons live in [OcrResultActions],
/// pinned below the scrollable card so they never scroll away (QD-39: the user always confirms).
class OcrSingleResultCard extends StatelessWidget {
  const OcrSingleResultCard({
    super.key = const Key('ocr-single-result'),
    required this.candidate,
    required this.strengthUnverified,
    this.checkReminder = false,
  });

  final OcrCandidate candidate;

  /// `strength_unverified`: the box's mg was not read, so ask the user to check it.
  final bool strengthUnverified;

  /// `low_confidence`: the server is not sure, so ask to compare name and mg with the
  /// box before confirming (adhoc-20261116 01 §6.1, QD-39). Replaces the mg hint.
  final bool checkReminder;

  @override
  Widget build(BuildContext context) {
    String? present(String? value) =>
        value == null || value.trim().isEmpty ? null : value.trim();
    final strength = present(candidate.strengthText);
    final scorePercent = (candidate.score * 100).round();
    final statusLabel = checkReminder
        ? (candidate.score > 0
            ? 'Cần đối chiếu · $scorePercent% khớp'
            : 'Cần đối chiếu')
        : (candidate.score > 0
            ? 'Đã nhận diện · $scorePercent% khớp'
            : 'Đã nhận diện');
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.cardElevation,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              key: const Key('ocr-status-pill'),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs + 2,
              ),
              decoration: BoxDecoration(
                color: checkReminder ? AppColors.cautionBg : AppColors.safeBg,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    checkReminder
                        ? Icons.warning_amber_rounded
                        : Icons.check_circle_outline,
                    size: 16,
                    color: checkReminder ? AppColors.caution : AppColors.safe,
                  ),
                  const SizedBox(width: AppSpacing.xs + 2),
                  Flexible(
                    child: Text(
                      statusLabel,
                      style: AppTextStyles.captionStrong.copyWith(
                        color: checkReminder
                            ? AppColors.cautionText
                            : AppColors.safe,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Semantics(
            header: true,
            child: Text(candidate.name, style: AppTextStyles.display),
          ),
          const SizedBox(height: AppSpacing.md),
          OcrInfoRow(
              label: 'Hàm lượng',
              value: strength == null ? null : formatStrength(strength)),
          OcrInfoRow(label: 'Dạng bào chế', value: present(candidate.dosageForm)),
          OcrInfoRow(
              label: 'Hoạt chất',
              value: present(candidate.activeIngredient),
              last: true),
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
        ],
      ),
    );
  }
}

/// One "label: value" line; a missing value reads "Chưa có thông tin" instead of vanishing,
/// so every result has the same rows.
class OcrInfoRow extends StatelessWidget {
  const OcrInfoRow({
    super.key,
    required this.label,
    required this.value,
    this.last = false,
  });

  final String label;
  final String? value;
  final bool last;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 112,
              child: Text(label,
                  style: AppTextStyles.body.copyWith(color: AppColors.inkMuted)),
            ),
            Expanded(
              child: Text(
                value ?? 'Chưa có thông tin',
                textAlign: TextAlign.end,
                style: value == null
                    ? AppTextStyles.body.copyWith(color: AppColors.inkMuted)
                    : AppTextStyles.bodyStrong,
              ),
            ),
          ],
        ),
      );
}

/// Buttons under the scan result, pinned to the bottom of the sheet.
class OcrResultActions extends StatelessWidget {
  const OcrResultActions({
    super.key = const Key('ocr-result-actions'),
    required this.onConfirm,
    required this.onNotThis,
    required this.onRetake,
  });

  final VoidCallback onConfirm, onNotThis, onRetake;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
          TextButton(onPressed: onRetake, child: const Text('Chụp lại')),
        ],
      );
}
