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
  });

  final DoseReminderItem item;
  final DoseReminderItemStatus status;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    final confirmed = status == DoseReminderItemStatus.confirmed;
    final saving = status == DoseReminderItemStatus.saving;

    return Semantics(
      container: true,
      label: '${item.medicationName}, ${item.dosageText}, ${item.instruction}',
      value: confirmed ? 'Đã uống' : 'Chưa xác nhận',
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Padding(
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
              if (saving)
                const SizedBox(
                  width: 32,
                  height: 32,
                  child: Padding(
                    padding: EdgeInsets.all(6),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                IconButton(
                  tooltip: confirmed
                      ? '${item.medicationName} đã uống'
                      : 'Xác nhận ${item.medicationName}',
                  onPressed: confirmed ? null : onConfirm,
                  icon: Icon(
                    confirmed ? Icons.check_circle : Icons.check_circle_outline,
                    color: confirmed ? AppColors.brand : AppColors.inkMuted,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
