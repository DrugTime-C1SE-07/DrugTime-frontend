import 'package:flutter/material.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/pill_icon.dart';
import '../../domain/entities/adherence_history.dart';
import '../utils/adherence_history_format.dart';
import 'history_inline_row.dart';
import 'history_motion.dart';

class DoseHistoryTile extends StatelessWidget {
  const DoseHistoryTile({super.key, required this.dose, this.showDate = false});
  final HistoryDose dose;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final (color, background, icon) = switch (dose.status) {
      HistoryDoseStatus.taken => (
          AppColors.safe,
          AppColors.safeBg,
          Icons.check
        ),
      HistoryDoseStatus.late => (
          AppColors.cautionText,
          AppColors.cautionBg,
          Icons.schedule
        ),
      HistoryDoseStatus.missed => (
          AppColors.danger,
          AppColors.dangerBg,
          Icons.priority_high
        ),
      HistoryDoseStatus.pending => (
          AppColors.inkMuted,
          AppColors.surfaceMuted,
          Icons.hourglass_empty
        ),
    };
    final taken = dose.takenAt;
    final actualDay = taken == null ||
            HistoryFormat.today(taken) == HistoryFormat.today(dose.scheduledAt)
        ? ''
        : ' · ${HistoryFormat.shortDay(HistoryFormat.today(taken), reference: HistoryFormat.today(dose.scheduledAt))}';
    final badge = taken == null
        ? HistoryFormat.status(dose.status)
        : '${HistoryFormat.status(dose.status)} · ${HistoryFormat.time(taken)}$actualDay';
    final statusIcon = ExcludeSemantics(
        child: Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: dose.status == HistoryDoseStatus.taken
              ? AppColors.safe
              : background),
      child: Icon(icon,
          size: 20,
          color: dose.status == HistoryDoseStatus.taken
              ? AppColors.onBrand
              : color),
    ));
    final text =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(dose.medicationName, style: AppTextStyles.bodyStrong),
      if (showDate) ...[
        const SizedBox(height: AppSpacing.xs),
        HistoryInlineRow(children: [
          Text(
              '${HistoryFormat.shortDay(HistoryFormat.today(dose.scheduledAt), reference: HistoryFormat.today(dose.scheduledAt))} · ${HistoryFormat.time(dose.scheduledAt)}',
              style: AppTextStyles.caption)
        ]),
      ],
      const SizedBox(height: AppSpacing.sm),
      Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(AppRadius.field)),
        child: HistoryInlineRow(children: [
          Icon(icon, size: 14, color: color),
          Text(badge, style: AppTextStyles.caption.copyWith(color: color)),
        ]),
      ),
    ]);
    return Semantics(
      container: true,
      label:
          '${dose.medicationName}, ${dose.status.label}, giờ dự kiến ${HistoryFormat.time(dose.scheduledAt)}, ${showDate ? HistoryFormat.day(HistoryFormat.today(dose.scheduledAt)) : ''}, ${HistoryFormat.actual(dose)}',
      child: ExcludeSemantics(
          child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppRadius.card)),
        child: LayoutBuilder(builder: (context, constraints) {
          final stacked = constraints.maxWidth < 280 ||
              MediaQuery.textScalerOf(context).scale(16) > 22;
          if (stacked) {
            return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const PillTile(),
                    const Spacer(),
                    HistoryEntrance(child: statusIcon)
                  ]),
                  const SizedBox(height: AppSpacing.md),
                  text,
                ]);
          }
          return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            const PillTile(),
            const SizedBox(width: AppSpacing.lg),
            Expanded(child: text),
            const SizedBox(width: AppSpacing.md),
            HistoryEntrance(child: statusIcon),
          ]);
        }),
      )),
    );
  }
}
