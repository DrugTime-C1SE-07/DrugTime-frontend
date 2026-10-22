import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/adherence_history.dart';

class AdherenceDoseCard extends StatelessWidget {
  const AdherenceDoseCard({super.key, required this.dose});

  final AdherenceDose dose;

  @override
  Widget build(BuildContext context) {
    final (icon, color, background) = switch (dose.status) {
      AdherenceDoseStatus.taken => (
          Icons.check_circle_outline,
          AppColors.safe,
          AppColors.safeBg
        ),
      AdherenceDoseStatus.late => (
          Icons.schedule,
          AppColors.cautionText,
          AppColors.cautionBg
        ),
      AdherenceDoseStatus.missed => (
          Icons.error_outline,
          AppColors.danger,
          AppColors.dangerBg
        ),
      AdherenceDoseStatus.pending => (
          Icons.hourglass_empty,
          AppColors.inkMuted,
          AppColors.surfaceMuted
        ),
    };
    final scheduled = _time(dose.scheduledAt);
    final taken = dose.takenAt == null ? null : _time(dose.takenAt!);
    return Semantics(
      container: true,
      label: '${dose.medicationName}, dự kiến $scheduled, ${dose.status.label}'
          '${taken == null ? '' : ', ghi nhận lúc $taken'}',
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: AppSizes.tapTarget,
              height: AppSizes.tapTarget,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(AppRadius.field),
              ),
              child: Icon(icon, color: color, size: 25),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dose.medicationName,
                      style: AppTextStyles.bodyStrong,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: AppSpacing.xs),
                  Text('Dự kiến $scheduled', style: AppTextStyles.caption),
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: background,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      taken == null
                          ? dose.status.label
                          : '${dose.status.label} lúc $taken',
                      style: AppTextStyles.captionStrong.copyWith(color: color),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _time(DateTime value) {
  final wall = vietnamWallTime(value);
  return '${wall.hour.toString().padLeft(2, '0')}:'
      '${wall.minute.toString().padLeft(2, '0')}';
}
