import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../adherence/domain/entities/adherence_history.dart';
import '../../../patient_dose_reminders/data/patient_dose_reminder_repository.dart';
import '../../domain/monitor_digest.dart';
import '../../domain/monitor_models.dart';
import 'dose_row.dart';
import 'monitor_palette.dart';

/// R3 · Chi tiết liều: giờ hẹn, giờ người thân nhắc, giờ uống và độ trễ, dải 7 ngày.
class DoseDetailView extends StatelessWidget {
  const DoseDetailView({
    super.key,
    required this.dose,
    required this.history,
    required this.name,
    required this.now,
    this.receipt,
    this.canRemind = false,
    this.wait = Duration.zero,
    this.busy = false,
    this.message,
    this.onNudge,
  });

  final AdherenceDose dose;
  final AdherenceHistory history;
  final String name;
  final DateTime now;
  final ReminderReceipt? receipt;
  final bool canRemind, busy;
  final Duration wait;
  final String? message;
  final VoidCallback? onNudge;

  static const _weekday = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

  @override
  Widget build(BuildContext context) {
    final taken = dose.takenAt;
    final delay = taken?.difference(dose.scheduledAt);
    final late = delay != null && dose.status == AdherenceDoseStatus.late;
    final strip = scheduleStrip(history, dose.scheduleId, now);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _card(Row(children: [
        MedicationTile(seed: dose.medicationId, size: 56),
        const SizedBox(width: 14),
        Expanded(child: Text(dose.medicationName, style: AppTextStyles.title)),
      ])),
      const SizedBox(height: 12),
      _card(Column(children: [
        _row(Icons.schedule, 'Giờ hẹn', monitorTime(dose.scheduledAt),
            AppColors.inkMuted),
        if (receipt != null)
          _row(Icons.notifications_none, 'Bạn đã nhắc',
              monitorTime(receipt!.requestedAt), MonitorColors.nudged,
              key: const Key('detail-reminded')),
        if (taken != null)
          _row(
              Icons.check_circle_outline,
              '$name đã uống',
              late
                  ? '${monitorTime(taken)} · trễ ${formatDelayShort(delay)}'
                  : monitorTime(taken),
              late ? MonitorColors.late : MonitorColors.taken,
              key: const Key('detail-taken'))
        else
          _row(
              Icons.info_outline,
              'Trạng thái',
              switch (segmentOf(dose, history.asOf)) {
                DoseSegment.missed => 'Bỏ lỡ',
                DoseSegment.overdue => 'Chưa xác nhận',
                _ => 'Chưa tới giờ',
              },
              needsAttention(dose, history.asOf)
                  ? MonitorColors.missed
                  : AppColors.inkMuted),
        if (canRemind) ...[
          const SizedBox(height: 8),
          FilledButton.icon(
            key: const Key('detail-nudge'),
            onPressed: busy || wait > Duration.zero ? null : onNudge,
            icon: const Icon(Icons.notifications_active_outlined),
            label: Text(busy
                ? 'Đang gửi…'
                : wait > Duration.zero
                    ? 'Nhắc lại sau ${wait.inSeconds + 1}s'
                    : 'Nhắc $name'),
            style:
                FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
          if (message != null)
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(message!, style: AppTextStyles.caption)),
          const SizedBox(height: 6),
          const Text('Lời nhắc không phải hướng dẫn uống bù.',
              style: AppTextStyles.caption),
        ],
      ])),
      const SizedBox(height: 12),
      _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${dose.medicationName} · 7 ngày gần nhất',
            style: AppTextStyles.bodyStrong),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          for (var i = 0; i < strip.length; i++)
            Column(key: ValueKey('strip-$i-${strip[i].mark.name}'), children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: MonitorColors.strip(strip[i].mark),
                child: Icon(
                    switch (strip[i].mark) {
                      StripMark.onTime => Icons.check,
                      StripMark.late => Icons.schedule,
                      StripMark.missed => Icons.close,
                      _ => null,
                    },
                    size: 18,
                    color: Colors.white),
              ),
              const SizedBox(height: 6),
              Text(_weekday[strip[i].day.weekday - 1],
                  style: AppTextStyles.caption),
            ]),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 14, children: [
          for (final (color, label) in [
            (MonitorColors.taken, 'Đúng giờ'),
            (MonitorColors.late, 'Muộn'),
            (MonitorColors.missed, 'Bỏ lỡ'),
          ])
            Row(mainAxisSize: MainAxisSize.min, children: [
              CircleAvatar(radius: 5, backgroundColor: color),
              const SizedBox(width: 6),
              Text(label, style: AppTextStyles.caption),
            ]),
        ]),
      ])),
    ]);
  }

  Widget _row(IconData icon, String label, String value, Color color,
          {Key? key}) =>
      Padding(
        key: key,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: AppTextStyles.body)),
          Text(value, style: AppTextStyles.bodyStrong.copyWith(color: color)),
        ]),
      );

  static Widget _card(Widget child) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: child,
      );
}
