import 'package:flutter/material.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/pill_icon.dart';
import '../../domain/entities/adherence_history.dart';
import '../utils/adherence_history_format.dart';
import '../utils/reminder_palette.dart';

class DoseHistoryTile extends StatelessWidget {
  const DoseHistoryTile(
      {super.key,
      required this.dose,
      this.showDate = false,
      this.upcoming = false,
      this.locallyConfirmed = false,
      this.prototypeStyle = false,
      this.details,
      this.onTap});
  final HistoryDose dose;
  final bool showDate;
  final bool upcoming;
  final bool locallyConfirmed;
  final bool prototypeStyle;
  final String? details;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isUpcoming = upcoming && !locallyConfirmed;
    final status = locallyConfirmed ? HistoryDoseStatus.taken : dose.status;
    final interactive =
        onTap != null && (status != HistoryDoseStatus.pending || isUpcoming);
    final (color, background, icon) = isUpcoming
        ? (ReminderPalette.teal, ReminderPalette.surfaceTint, Icons.schedule)
        : switch (status) {
            HistoryDoseStatus.taken => (
                ReminderPalette.success,
                ReminderPalette.successBackground,
                Icons.check_circle_outline
              ),
            HistoryDoseStatus.late => (
                AppColors.cautionText,
                AppColors.cautionBg,
                Icons.schedule
              ),
            HistoryDoseStatus.missed => (
                ReminderPalette.missed,
                ReminderPalette.missedBackground,
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
    final badge = isUpcoming ? 'Sắp tới' : HistoryFormat.status(status);
    final clock = HistoryFormat.time(dose.scheduledAt);
    final state = Container(
      constraints: const BoxConstraints(minHeight: 40),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
          color: background, borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(isUpcoming ? Icons.schedule : icon, size: 16, color: color),
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
    final missed = status == HistoryDoseStatus.missed;
    final rail = missed && !prototypeStyle ? ReminderPalette.missed : null;
    final cardColor =
        missed && prototypeStyle ? const Color(0xFFFFF4F2) : AppColors.surface;
    return Semantics(
      container: true,
      button: interactive,
      onTap: interactive ? onTap : null,
      label:
          '${dose.medicationName}, ${isUpcoming ? 'Sắp tới' : status.label}, giờ dự kiến ${HistoryFormat.time(dose.scheduledAt)}, ${showDate ? HistoryFormat.day(HistoryFormat.today(dose.scheduledAt)) : ''}, ${locallyConfirmed ? 'Đã xác nhận tại Trang chủ' : HistoryFormat.actual(dose)}',
      child: ExcludeSemantics(
        child: LayoutBuilder(builder: (context, constraints) {
          final compact = constraints.maxWidth < 290 ||
              MediaQuery.textScalerOf(context).scale(16) > 20;
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Material(
              color: rail ?? cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.field),
                side: missed && prototypeStyle
                    ? const BorderSide(color: ReminderPalette.missedBackground)
                    : BorderSide.none,
              ),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: EdgeInsets.only(left: rail == null ? 0 : 4),
                child: Material(
                  color: cardColor,
                  child: InkWell(
                    onTap: interactive ? onTap : null,
                    child: Padding(
                      padding: EdgeInsets.all(prototypeStyle ? 9 : 14),
                      child: prototypeStyle
                          ? _prototypeRow(
                              clock: clock,
                              state: state,
                              statusColor: color,
                            )
                          : Row(
                              children: [
                                const PillTile(colored: true),
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

  Widget _prototypeRow({
    required String clock,
    required Widget state,
    required Color statusColor,
  }) {
    final info = details?.trim() ?? '';
    return Row(
      children: [
        const SizedBox(
          width: 40,
          height: 40,
          child: Center(child: PillTile(colored: true)),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(clock,
                  style: AppTextStyles.captionStrong
                      .copyWith(fontSize: 12, color: statusColor)),
              Text(dose.medicationName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyStrong.copyWith(fontSize: 14)),
              if (info.isNotEmpty)
                Text(info,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(fontSize: 11)),
            ],
          ),
        ),
        const SizedBox(width: 7),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 112),
          child: state,
        ),
      ],
    );
  }
}
