import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/pill_icon.dart';
import '../../domain/entities/medication.dart';
import 'medication_labels.dart';

/// Thẻ một thuốc trong danh sách "Thuốc của tôi".
///
/// Thứ tự thông tin theo mức quan trọng: tên → liều & tần suất → giờ uống →
/// tồn kho. Thuốc đã ngừng được làm nhạt nhưng vẫn đọc được (không dưới AA).
class MedicationCard extends StatelessWidget {
  const MedicationCard({super.key, required this.medication, required this.onTap});

  final Medication medication;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final med = medication;
    final active = med.isActive;

    return Semantics(
      button: true,
      label: _semanticLabel(med),
      excludeSemantics: true,
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: const BorderSide(color: AppColors.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PillTile(muted: !active),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        med.name,
                        style: AppTextStyles.heading.copyWith(
                          color: active ? AppColors.ink : AppColors.inkMuted,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        active ? med.scheduleSummary : _stoppedLabel(med),
                        style: AppTextStyles.caption,
                      ),
                      if (active && med.times.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.sm),
                        _TimesRow(label: med.timesLabel),
                      ],
                      if (active && med.stockLabel != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        med.isLowStock
                            ? _LowStockBadge(label: 'Sắp hết · ${med.stockLabel!.toLowerCase()}')
                            : Text(med.stockLabel!, style: AppTextStyles.caption),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.md),
                  child: Icon(Icons.chevron_right, color: AppColors.inkMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _stoppedLabel(Medication med) {
    final ended = med.endedOn;
    return ended == null ? 'Đã ngừng' : 'Đã ngừng · kết thúc ${formatDate(ended)}';
  }

  static String _semanticLabel(Medication med) {
    final parts = <String>[med.name];
    if (!med.isActive) {
      parts.add(_stoppedLabel(med));
    } else {
      parts.add(med.scheduleSummary);
      if (med.times.isNotEmpty) parts.add('Giờ uống ${med.timesLabel}');
      if (med.isLowStock) parts.add('Sắp hết thuốc');
      if (med.stockLabel != null) parts.add(med.stockLabel!);
    }
    return parts.join('. ');
  }
}

class _TimesRow extends StatelessWidget {
  const _TimesRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.schedule, size: 18, color: AppColors.brand),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            label,
            style: AppTextStyles.figureSmall.copyWith(color: AppColors.brand),
          ),
        ),
      ],
    );
  }
}

class _LowStockBadge extends StatelessWidget {
  const _LowStockBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.cautionBg,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.cautionText),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              label,
              style: AppTextStyles.captionStrong.copyWith(color: AppColors.cautionText),
            ),
          ),
        ],
      ),
    );
  }
}
