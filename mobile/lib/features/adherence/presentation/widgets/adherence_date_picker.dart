import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/adherence_history.dart';

String adherenceDayLabel(DateTime date) =>
    '${_weekdayName(date.weekday)}, ${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/${date.year}';

String _weekdayName(int weekday) =>
    weekday == 7 ? 'Chủ nhật' : 'Thứ ${weekday + 1}';

class AdherenceDatePicker extends StatefulWidget {
  const AdherenceDatePicker({
    super.key,
    required this.selectedDate,
    required this.earliestDate,
    required this.today,
    required this.groups,
    required this.onSelected,
  });

  final DateTime selectedDate;
  final DateTime earliestDate;
  final DateTime today;
  final List<AdherenceDateGroup> groups;
  final ValueChanged<DateTime> onSelected;

  @override
  State<AdherenceDatePicker> createState() => _AdherenceDatePickerState();
}

class _AdherenceDatePickerState extends State<AdherenceDatePicker> {
  bool _showMonth = false;
  late DateTime _displayMonth;

  @override
  void initState() {
    super.initState();
    _displayMonth =
        DateTime.utc(widget.selectedDate.year, widget.selectedDate.month);
  }

  @override
  void didUpdateWidget(covariant AdherenceDatePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!sameCalendarDate(oldWidget.selectedDate, widget.selectedDate)) {
      _displayMonth =
          DateTime.utc(widget.selectedDate.year, widget.selectedDate.month);
    }
  }

  @override
  Widget build(BuildContext context) {
    final weekStart = widget.selectedDate
        .subtract(Duration(days: widget.selectedDate.weekday - 1));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(adherenceDayLabel(widget.selectedDate),
                  style: AppTextStyles.heading),
            ),
            IconButton(
              key: const Key('adherence-calendar-toggle'),
              tooltip: _showMonth ? 'Đóng lịch tháng' : 'Xem theo tháng',
              constraints: const BoxConstraints(
                minWidth: AppSizes.tapTarget,
                minHeight: AppSizes.tapTarget,
              ),
              onPressed: () => setState(() => _showMonth = !_showMonth),
              icon: Icon(
                  _showMonth ? Icons.view_week_outlined : Icons.calendar_month),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: constraints.maxWidth < AppSizes.tapTarget * 7
                  ? AppSizes.tapTarget * 7
                  : constraints.maxWidth,
              child: _showMonth
                  ? _MonthGrid(
                      displayMonth: _displayMonth,
                      selectedDate: widget.selectedDate,
                      earliestDate: widget.earliestDate,
                      today: widget.today,
                      groups: widget.groups,
                      onSelected: (date) {
                        widget.onSelected(date);
                        setState(() => _showMonth = false);
                      },
                      onMonthChanged: (month) =>
                          setState(() => _displayMonth = month),
                    )
                  : Row(
                      children: [
                        for (var offset = 0; offset < 7; offset++)
                          Expanded(
                            child: _DayCell(
                              date: weekStart.add(Duration(days: offset)),
                              selected: sameCalendarDate(
                                  weekStart.add(Duration(days: offset)),
                                  widget.selectedDate),
                              enabled: !weekStart
                                      .add(Duration(days: offset))
                                      .isBefore(widget.earliestDate) &&
                                  !weekStart
                                      .add(Duration(days: offset))
                                      .isAfter(widget.today),
                              group: _groupFor(widget.groups,
                                  weekStart.add(Duration(days: offset))),
                              onTap: widget.onSelected,
                            ),
                          ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.displayMonth,
    required this.selectedDate,
    required this.earliestDate,
    required this.today,
    required this.groups,
    required this.onSelected,
    required this.onMonthChanged,
  });

  final DateTime displayMonth;
  final DateTime selectedDate;
  final DateTime earliestDate;
  final DateTime today;
  final List<AdherenceDateGroup> groups;
  final ValueChanged<DateTime> onSelected;
  final ValueChanged<DateTime> onMonthChanged;

  @override
  Widget build(BuildContext context) {
    final first = DateTime.utc(displayMonth.year, displayMonth.month);
    final gridStart = first.subtract(Duration(days: first.weekday - 1));
    final last = DateTime.utc(displayMonth.year, displayMonth.month + 1, 0);
    final weeks = ((first.weekday - 1 + last.day) / 7).ceil();
    final earliestMonth = DateTime.utc(earliestDate.year, earliestDate.month);
    final latestMonth = DateTime.utc(today.year, today.month);
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Tháng trước',
              onPressed: first.isAfter(earliestMonth)
                  ? () =>
                      onMonthChanged(DateTime.utc(first.year, first.month - 1))
                  : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text('Tháng ${first.month}, ${first.year}',
                  textAlign: TextAlign.center, style: AppTextStyles.bodyStrong),
            ),
            IconButton(
              tooltip: 'Tháng sau',
              onPressed: first.isBefore(latestMonth)
                  ? () =>
                      onMonthChanged(DateTime.utc(first.year, first.month + 1))
                  : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            for (final label in ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'])
              Expanded(
                  child:
                      Center(child: Text(label, style: AppTextStyles.caption))),
          ],
        ),
        for (var week = 0; week < weeks; week++)
          Row(
            children: [
              for (var day = 0; day < 7; day++)
                Expanded(
                  child: Builder(builder: (context) {
                    final date = gridStart.add(Duration(days: week * 7 + day));
                    return _DayCell(
                      date: date,
                      selected: sameCalendarDate(date, selectedDate),
                      enabled: date.month == first.month &&
                          !date.isBefore(earliestDate) &&
                          !date.isAfter(today),
                      group: _groupFor(groups, date),
                      onTap: onSelected,
                      monthMode: true,
                    );
                  }),
                ),
            ],
          ),
        const SizedBox(height: AppSpacing.sm),
        const Wrap(
          spacing: AppSpacing.lg,
          children: [
            _Legend('Đã uống', AppColors.safe),
            _Legend('Có bỏ lỡ', AppColors.danger),
          ],
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.selected,
    required this.enabled,
    required this.group,
    required this.onTap,
    this.monthMode = false,
  });

  final DateTime date;
  final bool selected;
  final bool enabled;
  final AdherenceDateGroup? group;
  final ValueChanged<DateTime> onTap;
  final bool monthMode;

  @override
  Widget build(BuildContext context) {
    final hasMissed = group != null && group!.summary.missed > 0;
    final marker = group == null
        ? null
        : group!.summary.missed > 0
            ? AppColors.danger
            : group!.summary.counted > 0
                ? AppColors.safe
                : null;
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: '${adherenceDayLabel(date)}${hasMissed ? ', có bỏ lỡ' : ''}',
      child: InkWell(
        onTap: enabled ? () => onTap(date) : null,
        borderRadius: BorderRadius.circular(AppRadius.field),
        child: Container(
          constraints: const BoxConstraints(minHeight: AppSizes.tapTarget),
          margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 2),
          decoration: BoxDecoration(
            color: selected ? AppColors.brand : null,
            borderRadius: BorderRadius.circular(AppRadius.field),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!monthMode)
                Text(date.weekday == 7 ? 'CN' : 'T${date.weekday + 1}',
                    style: AppTextStyles.caption.copyWith(
                        color:
                            selected ? AppColors.onBrand : AppColors.inkMuted)),
              Text('${date.day}',
                  style: AppTextStyles.captionStrong.copyWith(
                    color: selected
                        ? AppColors.onBrand
                        : enabled
                            ? AppColors.ink
                            : AppColors.inkDisabled,
                  )),
              if (marker != null)
                Icon(Icons.circle,
                    size: 6, color: selected ? AppColors.onBrand : marker),
            ],
          ),
        ),
      ),
    );
  }
}

AdherenceDateGroup? _groupFor(List<AdherenceDateGroup> groups, DateTime date) {
  for (final group in groups) {
    if (sameCalendarDate(group.date, date)) return group;
  }
  return null;
}

class _Legend extends StatelessWidget {
  const _Legend(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: AppSpacing.xs),
          Text(label, style: AppTextStyles.caption),
        ],
      );
}
