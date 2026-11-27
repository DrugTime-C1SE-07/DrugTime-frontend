import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/medication.dart';
import 'medication_labels.dart';
import 'pill_appearance_icon.dart';

/// Thẻ một thuốc trong danh sách "Thuốc của tôi" (Figma S06).
///
/// Tên → liều & tần suất → chip sắp hết (nếu có). Giờ uống và tồn kho không hiện
/// trên thẻ nhưng vẫn có trong nhãn đọc màn hình. Thuốc đã ngừng làm nhạt ô viên
/// thuốc; chữ vẫn giữ `inkMuted` để không dưới AA.
class MedicationCard extends StatelessWidget {
  const MedicationCard(
      {super.key, required this.medication, required this.onTap});

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

    // Hình/màu người bệnh chọn (S07-M2b); chưa chọn màu thì gán một màu cố định theo id
    // để mỗi thuốc vẫn dễ phân biệt.
    final chosen = med.pillShape != null || med.pillColor != null;
    final color = med.pillColor ?? MedicationCard.fallbackPillColor(med.id);
    final Widget tile = PillAppearanceTile(
        key: chosen ? const Key('medication-card-appearance') : null,
        shape: med.pillShape,
        color: color,
        dosageForm: med.dosageForm,
        background:
            Color.alphaBlend(color.color.withAlpha(56), AppColors.surface));
    final lowStock = active && med.isLowStock && med.stockLabel != null;

    return Semantics(
      button: true,
      label: _semanticLabel(med),
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_radius),
          boxShadow: AppShadows.cardElevation,
        ),
        // Sắp hết: viền trái màu cảnh báo, như thẻ "bỏ lỡ" của "Lịch nhắc".
        child: Material(
          key: lowStock ? const Key('medication-card-low-stock-rail') : null,
          color: lowStock ? AppColors.caution : AppColors.surface,
          borderRadius: BorderRadius.circular(_radius),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: EdgeInsets.only(left: lowStock ? 4 : 0),
            child: Material(
              color: AppColors.surface,
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
                                  : _nameStyle.copyWith(
                                      color: AppColors.inkMuted),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              active ? med.scheduleSummary : _stoppedLabel(med),
                              style: AppTextStyles.caption,
                            ),
                            if (lowStock) ...[
                              const SizedBox(height: AppSpacing.xs),
                              _LowStockChip(
                                  label:
                                      'Sắp hết · ${med.stockLabel!.toLowerCase()}'),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      const Icon(Icons.chevron_right,
                          color: AppColors.inkFaint),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Màu tự gán khi người dùng chưa chọn: ổn định theo id (không dùng `hashCode`,
  /// vốn không bảo đảm giống nhau giữa các lần chạy).
  @visibleForTesting
  static PillColor fallbackPillColor(String id) {
    const palette = [
      PillColor.blue,
      PillColor.green,
      PillColor.yellow,
      PillColor.pink,
      PillColor.orange,
      PillColor.purple,
    ];
    final sum = id.codeUnits.fold<int>(0, (a, c) => (a * 31 + c) & 0x7fffffff);
    return palette[sum % palette.length];
  }

  static String _stoppedLabel(Medication med) {
    final ended = med.endedOn;
    return ended == null
        ? 'Đã ngừng'
        : 'Đã ngừng · kết thúc ${formatDate(ended)}';
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
          const Icon(Icons.warning_amber_rounded,
              size: 16, color: AppColors.cautionText),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: AppTextStyles.captionStrong
                  .copyWith(color: AppColors.cautionText),
            ),
          ),
        ],
      ),
    );
  }
}
