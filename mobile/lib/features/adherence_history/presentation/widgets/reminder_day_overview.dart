import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/adherence_history.dart';
import '../utils/adherence_history_format.dart';
import '../utils/reminder_palette.dart';

/// The compact "Hộp thuốc hôm nay" progress strip shown in the Figma day view.
class ReminderDayOverview extends StatelessWidget {
  const ReminderDayOverview({
    super.key,
    required this.day,
    required this.today,
    required this.group,
  });

  final DateTime day;
  final DateTime today;
  final DateHistoryGroup? group;

  @override
  Widget build(BuildContext context) {
    final summary = group?.summary;
    final doses = List<HistoryDose>.of(group?.doses ?? const [])
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    final completed = (summary?.taken ?? 0) + (summary?.late ?? 0);
    final total = summary?.total ?? 0;
    final ratio = '$completed/$total';
    final dayLabel = day == today
        ? 'hôm nay'
        : HistoryFormat.shortDay(day, reference: today);

    return Container(
      key: const Key('history-summary'),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
      decoration: BoxDecoration(
        color: ReminderPalette.header,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ReminderPalette.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Hộp thuốc $dayLabel',
                        style: AppTextStyles.captionStrong
                            .copyWith(color: ReminderPalette.morningInk)),
                    Text.rich(
                        TextSpan(children: [
                          TextSpan(
                            text: ratio,
                            style: AppTextStyles.title.copyWith(fontSize: 30),
                          ),
                          const TextSpan(
                              text: ' liều', style: AppTextStyles.caption),
                        ]),
                        semanticsLabel: '$ratio liều'),
                  ],
                ),
              ),
              if (day == today && (summary?.pending ?? 0) > 0)
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: ReminderPalette.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('Còn ${summary!.pending} liều đang chờ',
                        style: AppTextStyles.captionStrong.copyWith(
                            fontSize: 12, color: ReminderPalette.morningInk)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (doses.isEmpty)
            Text('Chưa có liều trong ngày này',
                style:
                    AppTextStyles.caption.copyWith(color: AppColors.inkMuted))
          else
            SingleChildScrollView(
              key: const Key('history-dose-timeline-scroll'),
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var index = 0; index < doses.length; index++) ...[
                    if (index > 0) const SizedBox(width: 5),
                    _TimelineDose(dose: doses[index]),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TimelineDose extends StatelessWidget {
  const _TimelineDose({required this.dose});

  final HistoryDose dose;

  @override
  Widget build(BuildContext context) {
    final color = switch (dose.status) {
      HistoryDoseStatus.taken => ReminderPalette.success,
      HistoryDoseStatus.late => ReminderPalette.morningInk,
      HistoryDoseStatus.missed => ReminderPalette.missed,
      HistoryDoseStatus.pending ||
      HistoryDoseStatus.unverified =>
        ReminderPalette.pending,
    };
    final background = switch (dose.status) {
      HistoryDoseStatus.taken => ReminderPalette.successBackground,
      HistoryDoseStatus.late => ReminderPalette.morningBackground,
      HistoryDoseStatus.missed => ReminderPalette.missedBackground,
      HistoryDoseStatus.pending || HistoryDoseStatus.unverified => Colors.white,
    };
    return Semantics(
      label:
          '${HistoryFormat.time(dose.scheduledAt)}, ${HistoryFormat.status(dose.status)}',
      child: ExcludeSemantics(
        child: SizedBox(
          width: 54,
          child: Column(
            children: [
              Container(
                height: 27,
                width: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: dose.status == HistoryDoseStatus.pending ||
                            dose.status == HistoryDoseStatus.unverified
                        ? ReminderPalette.outline
                        : background,
                  ),
                ),
                child: Icon(
                  switch (dose.status) {
                    HistoryDoseStatus.taken => Icons.check_rounded,
                    HistoryDoseStatus.late => Icons.schedule_rounded,
                    HistoryDoseStatus.missed => Icons.priority_high_rounded,
                    HistoryDoseStatus.pending => Icons.schedule_rounded,
                    HistoryDoseStatus.unverified => Icons.cloud_off_outlined,
                  },
                  size: 16,
                  color: color,
                ),
              ),
              const SizedBox(height: 3),
              Text(HistoryFormat.time(dose.scheduledAt),
                  maxLines: 1,
                  style: AppTextStyles.captionStrong.copyWith(
                    fontSize: 10,
                    color: color,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}
