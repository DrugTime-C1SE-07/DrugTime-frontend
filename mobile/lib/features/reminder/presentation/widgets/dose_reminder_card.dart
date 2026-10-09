import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/dose_reminder.dart';
import '../state/dose_reminder_controller.dart';

/// Presents one medicine and its independent confirmation state.
class DoseReminderCard extends StatelessWidget {
  const DoseReminderCard({
    super.key,
    required this.item,
    required this.status,
    this.onConfirm,
    this.isSelectable = false,
    this.isSelected = true,
    this.onToggleSelect,
    this.extraCountBadge,
    this.onTap,
  });

  final DoseReminderItem item;
  final DoseReminderItemStatus status;
  final VoidCallback? onConfirm;
  final bool isSelectable;
  final bool isSelected;
  final ValueChanged<bool>? onToggleSelect;
  final int? extraCountBadge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final confirmed = status == DoseReminderItemStatus.confirmed;
    final saving = status == DoseReminderItemStatus.saving;

    Widget actionWidget;
    if (extraCountBadge != null && extraCountBadge! > 0) {
      actionWidget = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFE0F2F1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '+$extraCountBadge thuốc',
          style: const TextStyle(
            color: Color(0xFF004D40),
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    } else if (saving) {
      actionWidget = const SizedBox(
        width: 32,
        height: 32,
        child: Padding(
          padding: EdgeInsets.all(6),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    } else if (confirmed) {
      actionWidget = IconButton(
        tooltip: '${item.medicationName} đã uống',
        onPressed: null,
        icon: const Icon(
          Icons.check_circle,
          color: AppColors.brand,
        ),
      );
    } else {
      actionWidget = IconButton(
        tooltip: 'Xác nhận ${item.medicationName}',
        onPressed: onConfirm ?? () => onToggleSelect?.call(!isSelected),
        icon: Icon(
          isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
          color:
              isSelected ? const Color(0xFF004D40) : const Color(0xFF7AB0AC),
          size: 26,
        ),
      );
    }

    return Semantics(
      container: true,
      label: '${item.medicationName}, ${item.dosageText}, ${item.instruction}',
      value: confirmed ? 'Đã uống' : (isSelectable ? (isSelected ? 'Đã chọn' : 'Chưa chọn') : 'Chưa xác nhận'),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isSelectable
              ? (!confirmed && !saving ? () => onToggleSelect?.call(!isSelected) : null)
              : onTap,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.brandTint,
                    borderRadius: BorderRadius.circular(AppRadius.field),
                  ),
                  child: const Icon(
                    Icons.medication_outlined,
                    color: AppColors.brand,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.medicationName,
                        style: AppTextStyles.bodyStrong,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '${item.dosageText} · ${item.instruction}',
                        style: AppTextStyles.caption,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                actionWidget,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
