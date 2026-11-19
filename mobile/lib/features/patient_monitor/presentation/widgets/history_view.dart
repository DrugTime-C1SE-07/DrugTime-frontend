import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../adherence/domain/entities/adherence_history.dart';
import '../../domain/monitor_models.dart';
import 'monitor_palette.dart';

/// R6 · Lịch sử uống thuốc: "Tuần này" / "Tháng N", tỷ lệ tuân thủ, số liều theo trạng thái
/// và mỗi ngày một hàng chấm. Số liệu lấy nguyên từ `GET /adherence`.
class HistoryView extends StatelessWidget {
  const HistoryView({
    super.key,
    required this.monthly,
    required this.monthOffset,
    required this.now,
    required this.history,
    required this.error,
    required this.onMode,
    required this.onMonth,
    required this.onRetry,
  });

  final bool monthly;
  final int monthOffset;
  final DateTime now;
  final AdherenceHistory? history;
  final String? error;
  final ValueChanged<bool> onMode;
  final ValueChanged<int> onMonth;
  final VoidCallback onRetry;

  static const _weekday = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

  @override
  Widget build(BuildContext context) {
    final today = monitorDay(now);
    final month = DateTime.utc(today.year, today.month + monthOffset);
    final h = history;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          _segment('Tuần này', !monthly, () => onMode(false),
              const Key('history-week')),
          _segment('Tháng ${month.month}', monthly, () => onMode(true),
              const Key('history-month')),
        ]),
      ),
      if (monthly)
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          IconButton(
              tooltip: 'Tháng trước',
              onPressed:
                  monthOffset > -2 ? () => onMonth(monthOffset - 1) : null,
              icon: const Icon(Icons.chevron_left)),
          Text(
              monthOffset == 0
                  ? 'Tháng này'
                  : 'Tháng ${month.month}/${month.year}',
              style: AppTextStyles.bodyStrong),
          IconButton(
              tooltip: 'Tháng sau',
              onPressed:
                  monthOffset < 0 ? () => onMonth(monthOffset + 1) : null,
              icon: const Icon(Icons.chevron_right)),
        ]),
      const SizedBox(height: 12),
      if (error != null) ...[
        Text(error!),
        TextButton(onPressed: onRetry, child: const Text('Thử lại')),
      ] else if (h == null)
        const LinearProgressIndicator()
      else ...[
        _summary(h.summary),
        const SizedBox(height: 12),
        if (h.groups.isEmpty)
          const Text('Chưa có lịch sử trong khoảng này.')
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Column(children: [
              for (final group in [
                ...h.groups
              ]..sort((a, b) => b.date.compareTo(a.date)))
                _day(group, today),
            ]),
          ),
      ],
    ]);
  }

  Widget _segment(String label, bool selected, VoidCallback onTap, Key key) =>
      Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          child: GestureDetector(
            key: key,
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? MonitorColors.purple : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(label,
                  style: AppTextStyles.bodyStrong.copyWith(
                      color: selected ? Colors.white : AppColors.inkMuted)),
            ),
          ),
        ),
      );

  Widget _summary(AdherenceSummary s) => Container(
        key: const Key('history-summary'),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.rate == null ? '—' : '${_rate(s.rate!)}%',
                style: AppTextStyles.display
                    .copyWith(color: MonitorColors.taken, fontSize: 40)),
            Text(s.rate == null ? 'chưa đủ dữ liệu' : 'tuân thủ',
                style: AppTextStyles.caption),
          ]),
          const SizedBox(width: 20),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _count(MonitorColors.taken, '${s.taken} liều đúng giờ'),
              _count(MonitorColors.late, '${s.late} liều muộn'),
              _count(MonitorColors.missed, '${s.missed} liều bỏ lỡ'),
              if (s.pending + s.unverified > 0)
                _count(MonitorColors.upcoming,
                    '${s.pending + s.unverified} liều chờ / chưa xác minh'),
            ]),
          ),
        ]),
      );

  static String _rate(double r) =>
      r == r.roundToDouble() ? '${r.round()}' : r.toStringAsFixed(2);

  Widget _count(Color color, String label) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          CircleAvatar(radius: 6, backgroundColor: color),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: AppTextStyles.body)),
        ]),
      );

  Widget _day(AdherenceDateGroup group, DateTime today) {
    final isToday = group.date.year == today.year &&
        group.date.month == today.month &&
        group.date.day == today.day;
    final wd = _weekday[group.date.weekday - 1];
    final label = isToday
        ? 'Hôm nay · $wd'
        : '$wd · ${group.date.day}/${group.date.month}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Expanded(
            child: Text(label,
                style:
                    isToday ? AppTextStyles.bodyStrong : AppTextStyles.body)),
        Wrap(spacing: 8, children: [
          for (final dose in group.doses)
            Tooltip(
              message: '${monitorTime(dose.scheduledAt)} ${dose.medicationName}'
                  ' · ${dose.status.label}',
              child: CircleAvatar(
                radius: 11,
                backgroundColor: switch (dose.status) {
                  AdherenceDoseStatus.taken => MonitorColors.taken,
                  AdherenceDoseStatus.late => MonitorColors.late,
                  AdherenceDoseStatus.missed => MonitorColors.missed,
                  _ => MonitorColors.upcoming,
                },
              ),
            ),
        ]),
      ]),
    );
  }
}
