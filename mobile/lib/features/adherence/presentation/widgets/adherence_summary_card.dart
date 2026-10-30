import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/adherence_history.dart';

class AdherenceSummaryCard extends StatelessWidget {
  const AdherenceSummaryCard({super.key, required this.summary});

  final AdherenceSummary summary;

  @override
  Widget build(BuildContext context) {
    final rate = summary.rate;
    final rateLabel =
        rate?.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.brandTint,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tỷ lệ tuân thủ (gồm uống trễ)',
              style:
                  AppTextStyles.captionStrong.copyWith(color: AppColors.ink)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            rateLabel == null ? 'Chưa có liều được tính' : '$rateLabel%',
            style: AppTextStyles.title.copyWith(color: AppColors.brand),
          ),
          const SizedBox(height: AppSpacing.sm),
          Semantics(
            label: rate == null
                ? 'Chưa có liều được tính vào tỷ lệ tuân thủ'
                : 'Tỷ lệ tuân thủ $rateLabel phần trăm, gồm uống trễ',
            child: LinearProgressIndicator(
              value: rate == null ? 0 : rate / 100,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
              color: AppColors.brand,
              backgroundColor: AppColors.surface,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.sm,
            children: [
              _Stat('Đã uống', summary.taken, AppColors.safe),
              _Stat('Uống trễ', summary.late, AppColors.cautionText),
              _Stat('Bỏ lỡ', summary.missed, AppColors.danger),
              _Stat('Chờ xác nhận', summary.pending, AppColors.inkMuted),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.count, this.color);

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 9, color: color),
          const SizedBox(width: AppSpacing.xs),
          Flexible(child: Text('$label $count', style: AppTextStyles.caption)),
        ],
      );
}
