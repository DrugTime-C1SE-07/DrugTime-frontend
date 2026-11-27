import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/pill_icon.dart';
import '../../domain/entities/medication.dart';
import 'medication_labels.dart';
import 'pill_appearance_icon.dart';

/// Thẻ một thuốc trong danh sách "Thuốc của tôi" (Figma S06).
///
/// Tên → liều & tần suất → chip sắp hết (nếu có). Giờ uống và tồn kho không hiện
/// trên thẻ nhưng vẫn có trong nhãn đọc màn hình. Thuốc đã ngừng làm nhạt ô viên
/// thuốc; chữ vẫn giữ `inkMuted` để không dưới AA.
class MedicationCard extends StatelessWidget {
  const MedicationCard({super.key, required this.medication, required this.onTap});

  final Medication medication;
  final VoidCallback onTap;

  static const _radius = 12.0;
  static const _stoppedTileOpacity = 0.45;

  static const _nameStyle = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 24 / 17,
    color: AppColors.ink,
  );

  @override
  Widget build(BuildContext context) {
    final med = medication;
    final active = med.isActive;

    // Hình/màu người bệnh chọn (S07-M2b); chưa chọn thì như cũ.
    final Widget tile = med.pillShape == null && med.pillColor == null
        ? const PillTile()
        : PillAppearanceTile(
            key: const Key('medication-card-appearance'),
            shape: med.pillShape,
            color: med.pillColor,
            dosageForm: med.dosageForm);

    return Semantics(
      button: true,
      label: _semanticLabel(med),
      excludeSemantics: true,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(_radius),
        child: InkWell(
          borderRadius: BorderRadius.circular(_radius),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
            child: Row(
              children: [
                active
                    ? tile
                    : Opacity(
                        key: const Key('medication-card-stopped-tile'),
                        opacity: _stoppedTileOpacity,
                        child: tile),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        med.name,
                        style: active
                            ? _nameStyle
                            : _nameStyle.copyWith(color: AppColors.inkMuted),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        active ? med.scheduleSummary : _stoppedLabel(med),
                        style: AppTextStyles.caption,
                      ),
                      if (active && med.isLowStock && med.stockLabel != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        _LowStockChip(
                            label: 'Sắp hết · ${med.stockLabel!.toLowerCase()}'),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                const Icon(Icons.chevron_right, color: AppColors.inkFaint),
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

class _LowStockChip extends StatelessWidget {
  const _LowStockChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 36),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cautionBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.cautionText),
          const SizedBox(width: 6),
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
