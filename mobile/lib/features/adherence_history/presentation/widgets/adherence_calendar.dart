import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/adherence_history.dart';
import '../state/adherence_history_controller.dart';
import '../utils/adherence_history_format.dart';
import 'history_motion.dart';
import 'history_inline_row.dart';
import 'history_info_sheet.dart';
import '../../../../core/preview/app_preview_scope.dart';

class HistoryMonthHeader extends StatelessWidget {
  const HistoryMonthHeader({super.key, required this.controller, this.onBack});
  final AdherenceHistoryController controller;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final large = MediaQuery.textScalerOf(context).scale(16) > 22;
    final title = HistoryInlineRow(children: [
      Text(
          'Tháng ${controller.selectedMonth.month}, ${controller.selectedMonth.year}',
          style: AppTextStyles.heading),
      if (onBack != null && AppPreviewScope.maybeOf(context) != null)
        const AppPreviewBadge(),
    ]);
    if (onBack == null) {
      return Row(children: [
        Expanded(child: title),
        IconButton(
            tooltip: 'Tháng trước',
            onPressed: controller.canGoPrevious
                ? () => unawaited(controller.changeMonth(-1))
                : null,
            icon: const Icon(Icons.chevron_left)),
        IconButton(
            tooltip: 'Tháng sau',
            onPressed: controller.canGoNext
                ? () => unawaited(controller.changeMonth(1))
                : null,
            icon: const Icon(Icons.chevron_right)),
      ]);
    }
    return Column(children: [
      if (large) title,
      Row(children: [
        if (onBack != null) BackButton(onPressed: onBack),
        if (!large) Expanded(child: title) else const Spacer(),
        if (onBack != null) const HistoryInfoButton(),
      ]),
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        IconButton(
            tooltip: 'Tháng trước',
            onPressed: controller.canGoPrevious
                ? () => unawaited(controller.changeMonth(-1))
                : null,
            icon: const Icon(Icons.chevron_left)),
        IconButton(
            tooltip: 'Tháng sau',
            onPressed: controller.canGoNext
                ? () => unawaited(controller.changeMonth(1))
                : null,
            icon: const Icon(Icons.chevron_right)),
      ]),
    ]);
  }
}

class AdherenceCalendar extends StatefulWidget {
  const AdherenceCalendar(
      {super.key, required this.controller, required this.onDay});
  final AdherenceHistoryController controller;
  final ValueChanged<DateTime> onDay;

  @override
  State<AdherenceCalendar> createState() => _AdherenceCalendarState();
}

class _AdherenceCalendarState extends State<AdherenceCalendar> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final month = c.selectedMonth;
    final offset = month.weekday - 1;
    final days = DateTime.utc(month.year, month.month + 1, 0).day;
    final rows = (offset + days + 6) ~/ 7;
    final scaler = MediaQuery.textScalerOf(context);
    double labelWidth(String value) {
      final painter = TextPainter(
        text: TextSpan(
            text: value,
            style: DefaultTextStyle.of(context)
                .style
                .merge(AppTextStyles.captionStrong)),
        textScaler: scaler,
        textDirection: Directionality.of(context),
        maxLines: 1,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    final minimumWidth = math.max(
        AppSizes.tapTarget,
        math.max(labelWidth('88'),
                math.max(labelWidth('CN'), labelWidth('T2'))) +
            8);
    final height =
        math.max(56.0, MediaQuery.textScalerOf(context).scale(14) * 1.4 + 36);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      LayoutBuilder(builder: (context, constraints) {
        final width = math.max(constraints.maxWidth, minimumWidth * 7);
        final overflows = width > constraints.maxWidth;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_scroll.hasClients) return;
          final cell = width / 7;
          final offset = ((c.selectedDay.weekday - 1) * cell +
                  cell / 2 -
                  constraints.maxWidth / 2)
              .clamp(0.0, _scroll.position.maxScrollExtent);
          if ((_scroll.offset - offset).abs() > 1) _scroll.jumpTo(offset);
        });
        return Scrollbar(
          controller: _scroll,
          thumbVisibility: overflows,
          child: SingleChildScrollView(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.only(bottom: overflows ? AppSpacing.sm : 0),
            child: SizedBox(
                width: width,
                child: Column(children: [
                  Row(children: [
                    for (final label in HistoryFormat.weekdays)
                      Expanded(
                          child: Center(
                              child: Text(label,
                                  maxLines: 1,
                                  style: AppTextStyles.captionStrong))),
                  ]),
                  const SizedBox(height: AppSpacing.sm),
                  Table(children: [
                    for (var row = 0; row < rows; row++)
                      TableRow(children: [
                        for (var col = 0; col < 7; col++)
                          SizedBox(
                              height: height,
                              child: _cell(
                                  month, row * 7 + col - offset + 1, days)),
                      ]),
                  ]),
                ])),
          ),
        );
      }),
      const SizedBox(height: AppSpacing.xl),
      HistoryInlineRow(children: [
        Semantics(
            label: 'Đã uống, gồm cả uống trễ',
            child: ExcludeSemantics(
                child: _legend(Icons.check_circle, AppColors.safe, 'Đã uống'))),
        Semantics(
            label: 'Bỏ lỡ, chưa ghi nhận đã uống',
            child: ExcludeSemantics(
                child: _legend(Icons.error, AppColors.danger, 'Bỏ lỡ'))),
        _legend(Icons.schedule, AppColors.inkMuted, 'Chờ'),
      ]),
    ]);
  }

  Widget _cell(DateTime month, int number, int days) {
    if (number < 1 || number > days) return const SizedBox.shrink();
    final c = widget.controller;
    final day = DateTime.utc(month.year, month.month, number);
    final group = c.dayGroup(day);
    final marker = HistoryFormat.marker(group?.summary);
    final selected = c.selectedDay == day;
    final future = day.isAfter(c.today);
    final pending = (group?.summary.pending ?? 0) > 0;
    final enabled =
        !future && c.history?.mode == HistoryMode.date && !c.loading;
    final (color, icon) = switch (marker) {
      HistoryDayMarker.complete => (AppColors.safe, Icons.check_circle),
      HistoryDayMarker.missed => (AppColors.danger, Icons.error),
      _ => (AppColors.inkMuted, Icons.schedule),
    };
    final description = future
        ? 'Chưa đến ngày'
        : group == null
            ? 'Chưa có lịch sử'
            : '${marker == HistoryDayMarker.missed ? 'Có liều chưa ghi nhận đã uống' : marker == HistoryDayMarker.complete ? 'Đã ghi nhận uống, gồm uống trễ' : 'Đang chờ'}, ${HistoryFormat.rate(group.summary.rate)}';
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label:
          '${HistoryFormat.dayHeading(day, today: c.today)}, $description${pending ? ', tạm tính, ${group!.summary.pending} liều đang chờ' : ''}',
      child: ExcludeSemantics(
          child: InkWell(
        key: ValueKey('history-day-$number'),
        onTap: enabled ? () => widget.onDay(day) : null,
        borderRadius: BorderRadius.circular(AppRadius.field),
        child: HistorySelection(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
              color: selected ? AppColors.brand : null,
              borderRadius: BorderRadius.circular(AppRadius.field),
              border: day == c.today && !selected
                  ? Border.all(color: AppColors.brand)
                  : null),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('$number',
                maxLines: 1,
                style: AppTextStyles.captionStrong.copyWith(
                    color: selected
                        ? AppColors.onBrand
                        : future
                            ? AppColors.inkDisabled
                            : AppColors.ink)),
            const SizedBox(height: AppSpacing.xs),
            SizedBox(
                height: 14,
                child:
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  if (marker != null)
                    Icon(icon,
                        size: 12, color: selected ? AppColors.onBrand : color),
                  if (pending && marker != HistoryDayMarker.pending)
                    Icon(Icons.schedule,
                        size: 12,
                        color:
                            selected ? AppColors.onBrand : AppColors.inkMuted),
                ])),
          ]),
        ),
      )),
    );
  }

  Widget _legend(IconData icon, Color color, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(child: Icon(icon, size: 14, color: color)),
          const SizedBox(width: AppSpacing.xs),
          Text(label, style: AppTextStyles.caption),
        ],
      );
}
