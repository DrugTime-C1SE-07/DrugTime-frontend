import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/preview/app_preview_scope.dart';
import '../../../../app/theme/app_theme.dart';
import '../state/adherence_history_controller.dart';
import '../../domain/entities/adherence_history.dart';
import '../widgets/history_motion.dart';
import '../widgets/history_summary.dart';
import '../utils/adherence_history_format.dart';
import '../utils/reminder_palette.dart';
import '../widgets/reminder_scene_header.dart';

class AdherenceMonthScreen extends StatefulWidget {
  const AdherenceMonthScreen({super.key, this.onRetry});
  final Future<void> Function()? onRetry;

  @override
  State<AdherenceMonthScreen> createState() => _AdherenceMonthScreenState();
}

class _AdherenceMonthScreenState extends State<AdherenceMonthScreen> {
  DateTime? _month;
  var _direction = 1.0;

  @override
  Widget build(BuildContext context) {
    final c = AdherenceHistoryScope.of(context);
    if (_month != null && _month != c.selectedMonth) {
      _direction = c.selectedMonth.isBefore(_month!) ? -1 : 1;
    }
    _month = c.selectedMonth;
    final preview = AppPreviewScope.maybeOf(context);
    return HistoryMotionScope(
      active: true,
      child: Scaffold(
        backgroundColor: ReminderPalette.canvas,
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: c.load,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                ReminderSceneHeader(
                  title:
                      'Tháng ${c.selectedMonth.month}, ${c.selectedMonth.year}',
                  now: preview?.clock ?? c.history?.asOf ?? DateTime.now(),
                  monthMode: true,
                  leading: IconButton(
                    tooltip: 'Quay lại',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  trailing: PopupMenuButton<int>(
                    tooltip: 'Chọn tháng',
                    onSelected: (delta) => unawaited(c.changeMonth(delta)),
                    itemBuilder: (_) => [
                      if (c.canGoPrevious)
                        const PopupMenuItem(
                            value: -1, child: Text('Tháng trước')),
                      if (c.canGoNext)
                        const PopupMenuItem(value: 1, child: Text('Tháng sau')),
                    ],
                    icon: const Icon(Icons.more_horiz,
                        color: ReminderPalette.teal),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      if (c.loading || c.error != null)
                        HistoryLoadState(controller: c, onRetry: widget.onRetry)
                      else if (c.history != null) ...[
                        HistoryEntrance(
                            key: ValueKey((c, c.contentRevision, 'summary')),
                            child: _MonthAdherenceCard(controller: c)),
                        const SizedBox(height: 8),
                        HistoryEntrance(
                            key: ValueKey((c, c.selectedMonth, 'grid')),
                            offset: Offset(12 * _direction, 0),
                            child: _PrototypeCalendar(controller: c)),
                        const SizedBox(height: 8),
                        HistoryEntrance(
                            key: ValueKey((c, c.contentRevision, 'selected')),
                            child: _SelectedDayCard(controller: c)),
                      ],
                      const SizedBox(height: AppSpacing.xxl),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthAdherenceCard extends StatelessWidget {
  const _MonthAdherenceCard({required this.controller});

  final AdherenceHistoryController controller;

  @override
  Widget build(BuildContext context) {
    final summary = controller.history!.summary;
    final completed = summary.taken + summary.late;
    final missedDays = controller.history!.dates
        .where((group) => group.summary.missed > 0)
        .length;
    return Container(
      key: const Key('history-month-summary'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: ReminderPalette.header,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ReminderPalette.outline),
      ),
      child: Row(children: [
        Semantics(
          image: true,
          label: 'Dumi, linh vật DrugTime',
          child: Image.asset('assets/icons/mascot-happy.png',
              width: 54, height: 54, fit: BoxFit.contain),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                  crossAxisAlignment: WrapCrossAlignment.end,
                  spacing: 6,
                  children: [
                    Text(HistoryFormat.rate(summary.rate),
                        style: AppTextStyles.title.copyWith(
                            color: ReminderPalette.teal, fontSize: 23)),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text('dữ liệu tuân thủ tháng này',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(fontSize: 11)),
                    ),
                  ]),
              const SizedBox(height: 3),
              Wrap(spacing: 6, runSpacing: 4, children: [
                _MonthMetric(
                    label: '$completed/${summary.total} liều',
                    color: ReminderPalette.successBackground,
                    foreground: ReminderPalette.success),
                if (missedDays > 0)
                  _MonthMetric(
                      label: '$missedDays ngày bỏ lỡ',
                      color: ReminderPalette.missedBackground,
                      foreground: ReminderPalette.missed),
              ]),
            ],
          ),
        ),
      ]),
    );
  }
}

class _MonthMetric extends StatelessWidget {
  const _MonthMetric(
      {required this.label, required this.color, required this.foreground});

  final String label;
  final Color color;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(12)),
        child: Text(label,
            style: AppTextStyles.captionStrong
                .copyWith(fontSize: 10, color: foreground)),
      );
}

class _SelectedDayCard extends StatelessWidget {
  const _SelectedDayCard({required this.controller});

  final AdherenceHistoryController controller;

  @override
  Widget build(BuildContext context) {
    final day = controller.selectedDay;
    final group = controller.selectedGroup;
    final summary = group?.summary;
    final taken = (summary?.taken ?? 0) + (summary?.late ?? 0);
    final remaining = group?.doses
            .where((dose) => dose.scheduledAt.isAfter(controller.history!.asOf))
            .length ??
        0;
    final weekday = day.weekday == 7 ? 'Chủ nhật' : 'Thứ ${day.weekday + 1}';
    final date =
        '${day.day.toString().padLeft(2, '0')}/${day.month.toString().padLeft(2, '0')}/${day.year}';
    final isToday = day == controller.today;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ReminderPalette.surface,
        border: Border.all(color: ReminderPalette.outline),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            width: 52,
            padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: BoxDecoration(
              color: ReminderPalette.teal,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(children: [
              Text(HistoryFormat.weekdays[day.weekday - 1],
                  style: AppTextStyles.caption
                      .copyWith(color: Colors.white, fontSize: 11)),
              Text('${day.day}',
                  style:
                      AppTextStyles.bodyStrong.copyWith(color: Colors.white)),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isToday ? 'Hôm nay' : '$weekday, $date',
                    style: AppTextStyles.bodyStrong),
                Text(
                    summary == null
                        ? 'Chưa có lịch sử'
                        : '$taken/${summary.total} liều đã uống${remaining > 0 ? ' · $remaining liều tới' : ''}',
                    style: AppTextStyles.caption),
              ],
            ),
          ),
          if (group != null && group.doses.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: ExcludeSemantics(
                child: Row(children: [
                  for (final dose in group.doses.take(5))
                    Container(
                      width: 7,
                      height: 22,
                      margin: const EdgeInsets.only(left: 3),
                      decoration: BoxDecoration(
                        color: switch (dose.status) {
                          HistoryDoseStatus.taken =>
                            ReminderPalette.successBackground,
                          HistoryDoseStatus.late =>
                            ReminderPalette.morningBackground,
                          HistoryDoseStatus.missed =>
                            ReminderPalette.missedBackground,
                          _ => ReminderPalette.pendingBackground,
                        },
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ]),
              ),
            ),
        ]),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            key: const Key('history-view-day'),
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              backgroundColor: ReminderPalette.surfaceTint,
              foregroundColor: ReminderPalette.teal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Flexible(
                  child: Text(isToday
                      ? 'Xem chi tiết ngày hôm nay'
                      : 'Xem chi tiết ngày này')),
              SizedBox(width: 8),
              Icon(Icons.chevron_right),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _PrototypeCalendar extends StatelessWidget {
  const _PrototypeCalendar({required this.controller});
  final AdherenceHistoryController controller;

  @override
  Widget build(BuildContext context) {
    final month = controller.selectedMonth;
    final offset = month.weekday - 1;
    final count = DateTime.utc(month.year, month.month + 1, 0).day;
    final rows = (offset + count + 6) ~/ 7;
    final cellHeight = math
        .max(48.0, MediaQuery.textScalerOf(context).scale(14) * 1.4 + 12)
        .toDouble();
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity > 100 && controller.canGoPrevious) {
          unawaited(controller.changeMonth(-1));
        } else if (velocity < -100 && controller.canGoNext) {
          unawaited(controller.changeMonth(1));
        }
      },
      child: LayoutBuilder(builder: (context, constraints) {
        // The grid lives inside 12px padding and a 1px border on each side; sizing it to the
        // outer width pushed Sunday past the card edge.
        final gridWidth =
            math.max(7 * 48.0, constraints.maxWidth - 26).toDouble();
        return Container(
          key: const Key('history-calendar-card'),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          decoration: BoxDecoration(
            color: ReminderPalette.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ReminderPalette.outline),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: gridWidth,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      for (final weekday in HistoryFormat.weekdays)
                        Expanded(
                            child: Center(
                                child: Text(weekday,
                                    style: AppTextStyles.captionStrong
                                        .copyWith(color: AppColors.inkMuted)))),
                    ]),
                    const SizedBox(height: 8),
                    Table(children: [
                      for (var row = 0; row < rows; row++)
                        TableRow(children: [
                          for (var col = 0; col < 7; col++)
                            SizedBox(
                                height: cellHeight,
                                child: _day(context, row * 7 + col - offset + 1,
                                    count)),
                        ]),
                    ]),
                    const SizedBox(height: 10),
                    Wrap(spacing: 16, runSpacing: 6, children: [
                      _legend(ReminderPalette.success, 'Đủ liều'),
                      _legend(ReminderPalette.missed, 'Có bỏ lỡ'),
                      _todayLegend(),
                    ]),
                  ]),
            ),
          ),
        );
      }),
    );
  }

  Widget _legend(Color color, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(text,
              style: AppTextStyles.caption.copyWith(color: AppColors.inkMuted)),
        ],
      );

  Widget _todayLegend() => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              border: Border.all(color: ReminderPalette.teal, width: 1.5),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text('Hôm nay',
              style: AppTextStyles.caption.copyWith(color: AppColors.inkMuted)),
        ],
      );

  Widget _day(BuildContext context, int number, int count) {
    if (number < 1 || number > count) return const SizedBox.shrink();
    final day = DateTime.utc(
        controller.selectedMonth.year, controller.selectedMonth.month, number);
    final selected = day == controller.selectedDay;
    final future = day.isAfter(controller.today);
    final summary = controller.dayGroup(day)?.summary;
    final marker = HistoryFormat.marker(summary);
    final Color? dayFill = switch (marker) {
      HistoryDayMarker.complete => ReminderPalette.successBackground,
      HistoryDayMarker.missed => ReminderPalette.missedBackground,
      _ => null,
    };
    return Semantics(
      button: true,
      selected: selected,
      enabled: !future,
      label: '${HistoryFormat.dayHeading(day, today: controller.today)}'
          '${marker == HistoryDayMarker.complete ? ', đủ liều' : marker == HistoryDayMarker.missed ? ', có bỏ lỡ' : ''}',
      child: InkWell(
        key: ValueKey('history-day-$number'),
        onTap: !future && controller.history?.mode == HistoryMode.date
            ? () => unawaited(controller.selectDay(day))
            : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
          decoration: BoxDecoration(
            color: selected ? ReminderPalette.teal : dayFill,
            shape: BoxShape.circle,
            border: day == controller.today && !selected
                ? Border.all(color: ReminderPalette.teal)
                : null,
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('$number',
                maxLines: 1,
                softWrap: false,
                style: AppTextStyles.caption.copyWith(
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  color: selected
                      ? AppColors.onBrand
                      : future
                          ? AppColors.inkMuted
                          : marker == HistoryDayMarker.missed
                              ? ReminderPalette.missed
                              : marker == HistoryDayMarker.complete
                                  ? ReminderPalette.success
                                  : AppColors.ink,
                )),
          ]),
        ),
      ),
    );
  }
}
