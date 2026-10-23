import 'package:flutter/material.dart';
import '../../../../app/router.dart';
import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/adherence_history.dart';
import '../../domain/entities/adherence_history_failure.dart';
import '../state/adherence_history_controller.dart';
import '../utils/adherence_history_format.dart';
import 'history_feedback.dart';
import 'history_motion.dart';

import 'history_inline_row.dart';

class HistorySummary extends StatelessWidget {
  const HistorySummary(
      {super.key, required this.summary, this.day, this.today, this.onViewDay});
  final AdherenceSummary? summary;
  final DateTime? day, today;
  final VoidCallback? onViewDay;
  @override
  Widget build(BuildContext context) {
    final data = summary;
    final date = day;
    final title = date == null
        ? 'Tháng này'
        : '${date == today ? 'Hôm nay · ' : ''}${HistoryFormat.shortDay(date, reference: today!)}';
    return Container(
        key: const Key('history-summary'),
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
            color: onViewDay == null ? AppColors.brandTint : AppColors.surface,
            border:
                onViewDay == null ? null : Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppRadius.card)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          HistoryInlineRow(spread: true, children: [
            Text(title, style: AppTextStyles.captionStrong),
            if (data != null)
              Text('${data.taken + data.late}/${data.total} đã uống',
                  style: AppTextStyles.captionStrong
                      .copyWith(color: AppColors.brand)),
          ]),
          if (data == null)
            Text(onViewDay == null ? 'Chưa tính' : 'Chưa có lịch sử',
                style: AppTextStyles.caption)
          else ...[
            Semantics(
                container: true,
                label: 'Tỷ lệ tuân thủ trên các liều đã có kết quả',
                value: HistoryFormat.rate(data.rate),
                child: ExcludeSemantics(
                    child: Row(children: [
                  if (data.rate != null) ...[
                    Expanded(
                        child: ClipRRect(
                            borderRadius:
                                BorderRadius.circular(AppRadius.field),
                            child: HistoryProgress(
                                value: data.rate! / 100,
                                color: AppColors.brand,
                                backgroundColor: AppColors.surface))),
                    const SizedBox(width: AppSpacing.md),
                  ],
                  Text(HistoryFormat.rate(data.rate),
                      style: AppTextStyles.captionStrong),
                ]))),
            if (data.pending > 0) ...[
              const SizedBox(height: AppSpacing.sm),
              HistoryInlineRow(children: [
                Text('${data.pending} chờ · Tạm tính',
                    style: AppTextStyles.caption)
              ]),
            ],
          ],
          if (onViewDay != null) ...[
            const SizedBox(height: AppSpacing.md),
            TextButton.icon(
                key: const Key('history-view-day'),
                onPressed: onViewDay,
                style: TextButton.styleFrom(
                    backgroundColor: AppColors.brandTint,
                    minimumSize: const Size(48, 48),
                    foregroundColor: AppColors.brand),
                label: const Text('Xem ngày'),
                icon: const Icon(Icons.arrow_forward, size: 20)),
          ],
        ]));
  }
}

class HistoryLoadState extends StatelessWidget {
  const HistoryLoadState({super.key, required this.controller, this.onRetry});
  final AdherenceHistoryController controller;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    final error = controller.error;
    if (controller.loading) {
      return const HistoryLoading();
    }
    if (error == null) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ExcludeSemantics(
          child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                  color: AppColors.brandTint,
                  borderRadius: BorderRadius.circular(AppRadius.card)),
              child: Icon(
                  error.removesAccess
                      ? Icons.lock_outline
                      : Icons.wifi_off_outlined,
                  size: 32,
                  color: AppColors.brand))),
      const SizedBox(height: AppSpacing.md),
      Text(error.message,
          key: const Key('history-error'), style: AppTextStyles.body),
      const SizedBox(height: AppSpacing.md),
      if (error.kind == HistoryFailureKind.consent)
        TextButton(
          onPressed: () async {
            await Navigator.of(context).pushNamed(AppRoutes.privacySettings);
            if (context.mounted) await controller.load();
          },
          child: const Text('Mở quyền riêng tư'),
        )
      else if (error.kind != HistoryFailureKind.unconfigured &&
          error.kind != HistoryFailureKind.unauthorized)
        FilledButton(
            onPressed: onRetry ?? controller.load,
            child: const Text('Thử lại')),
    ]);
  }
}
