import 'package:flutter/material.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/pill_icon.dart';
import '../../domain/entities/adherence_history.dart';
import '../utils/adherence_history_format.dart';

class DoseHistoryTile extends StatelessWidget {
  const DoseHistoryTile(
      {super.key,
      required this.dose,
      this.showDate = false,
      this.upcoming = false,
      this.onTap});
  final HistoryDose dose;
  final bool showDate;
  final bool upcoming;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (color, background, icon) = upcoming
        ? (AppColors.brand, AppColors.brandTint, Icons.schedule)
        : switch (dose.status) {
            HistoryDoseStatus.taken => (
                AppColors.safe,
                AppColors.safeBg,
                Icons.check_circle_outline
              ),
            HistoryDoseStatus.late => (
                AppColors.cautionText,
                AppColors.cautionBg,
                Icons.schedule
              ),
            HistoryDoseStatus.missed => (
                AppColors.danger,
                AppColors.dangerBg,
                Icons.error_outline
              ),
            HistoryDoseStatus.pending => (
                AppColors.inkMuted,
                AppColors.surfaceMuted,
                Icons.hourglass_empty
              ),
            HistoryDoseStatus.unverified => (
                AppColors.inkMuted,
                AppColors.surfaceMuted,
                Icons.cloud_off_outlined
              ),
          };
    final badge = upcoming ? 'Sắp tới' : HistoryFormat.status(dose.status);
    final clock = HistoryFormat.time(dose.scheduledAt);
    final state = Container(
      constraints: const BoxConstraints(minHeight: 40),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
          color: background, borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(upcoming ? Icons.schedule : icon, size: 16, color: color),
        const SizedBox(width: 6),
        Flexible(
            child: Text(badge,
                style: AppTextStyles.captionStrong.copyWith(color: color))),
      ]),
    );
    final name =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(dose.medicationName, style: AppTextStyles.bodyStrong),
      const SizedBox(height: 4),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.schedule, size: 14, color: AppColors.inkMuted),
          const SizedBox(width: 4),
          Flexible(
              child: Text(
            showDate
                ? '${HistoryFormat.shortDay(HistoryFormat.today(dose.scheduledAt), reference: HistoryFormat.today(dose.scheduledAt))} · $clock'
                : clock,
            style:
                AppTextStyles.captionStrong.copyWith(color: AppColors.inkMuted),
          )),
        ]),
      ),
    ]);
    final rail =
        dose.status == HistoryDoseStatus.missed ? AppColors.danger : null;
    return Semantics(
      container: true,
      button: onTap != null,
      onTap: onTap,
      label:
          '${dose.medicationName}, ${upcoming ? 'Sắp tới' : dose.status.label}, giờ dự kiến ${HistoryFormat.time(dose.scheduledAt)}, ${showDate ? HistoryFormat.day(HistoryFormat.today(dose.scheduledAt)) : ''}, ${HistoryFormat.actual(dose)}',
      child: ExcludeSemantics(
        child: LayoutBuilder(builder: (context, constraints) {
          final compact = constraints.maxWidth < 290 ||
              MediaQuery.textScalerOf(context).scale(16) > 20;
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Material(
              color: rail ?? AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.field),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: EdgeInsets.only(left: rail == null ? 0 : 4),
                child: Material(
                  color: AppColors.surface,
                  child: InkWell(
                    onTap: onTap,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          const PillTile(),
                          const SizedBox(width: 12),
                          Expanded(
                              child: compact
                                  ? Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                          name,
                                          const SizedBox(height: 8),
                                          state
                                        ])
                                  : name),
                          if (!compact) ...[
                            const SizedBox(width: 8),
                            state,
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
