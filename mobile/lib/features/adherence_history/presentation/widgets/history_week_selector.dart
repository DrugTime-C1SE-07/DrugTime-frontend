import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../app/theme/app_theme.dart';
import '../state/adherence_history_controller.dart';
import '../utils/adherence_history_format.dart';
import '../utils/reminder_palette.dart';
import 'history_motion.dart';

class HistoryWeekSelector extends StatefulWidget {
  const HistoryWeekSelector({super.key, required this.controller});
  final AdherenceHistoryController controller;

  @override
  State<HistoryWeekSelector> createState() => _HistoryWeekSelectorState();
}

class _HistoryWeekSelectorState extends State<HistoryWeekSelector> {
  final _scroll = ScrollController();
  DateTime? _alignedDay;
  double? _alignedWidth;
  DateTime? _weekStart;
  int _weekDirection = 0;
  double _drag = 0;

  /// Selects [day] for a user gesture; buzzes only when the selection really changed.
  Future<void> _choose(DateTime day) async {
    final c = widget.controller;
    final before = c.selectedDay;
    await c.selectDay(day);
    if (c.selectedDay != before) unawaited(HapticFeedback.selectionClick());
  }

  /// Swipe right → previous week (D−7); swipe left → next week, never past today.
  void _swipeWeek(DragEndDetails details) {
    final c = widget.controller;
    final velocity = details.primaryVelocity ?? 0;
    final distance = _drag;
    _drag = 0;
    final forward = velocity < -HistoryMotion.swipeVelocity ||
        (velocity.abs() <= HistoryMotion.swipeVelocity &&
            distance < -HistoryMotion.swipeDistance);
    final back = velocity > HistoryMotion.swipeVelocity ||
        (velocity.abs() <= HistoryMotion.swipeVelocity &&
            distance > HistoryMotion.swipeDistance);
    if (back) {
      unawaited(_choose(c.selectedDay.subtract(const Duration(days: 7))));
    } else if (forward) {
      if (HistoryFormat.week(c.selectedDay).contains(c.today)) return;
      final next = c.selectedDay.add(const Duration(days: 7));
      unawaited(_choose(next.isAfter(c.today) ? c.today : next));
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final days = HistoryFormat.week(c.selectedDay);
    if (_weekStart != days.first) {
      _weekDirection =
          _weekStart == null ? 0 : days.first.compareTo(_weekStart!).sign;
      _weekStart = days.first;
    }
    final selectedIndex = days.indexOf(c.selectedDay);
    final scaler = MediaQuery.textScalerOf(context);
    Size labelSize(String value, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(
            text: value,
            style: DefaultTextStyle.of(context).style.merge(style)),
        textScaler: scaler,
        textDirection: Directionality.of(context),
        maxLines: 1,
      )..layout();
      final size = painter.size;
      painter.dispose();
      return size;
    }

    final daySize = labelSize('88', AppTextStyles.bodyStrong);
    final sundaySize = labelSize('CN', AppTextStyles.caption);
    final weekdaySize = labelSize('T2', AppTextStyles.caption);
    final footerSize =
        labelSize('99/99', AppTextStyles.caption.copyWith(fontSize: 11));
    final minimumWidth = math.max(
        AppSizes.tapTarget,
        math.max(daySize.width, math.max(sundaySize.width, weekdaySize.width)) +
            16);
    final height = math.max(
        96.0,
        (footerSize.height +
                math.max(sundaySize.height, weekdaySize.height) +
                60)
            .ceilToDouble());
    return LayoutBuilder(builder: (context, constraints) {
      // The card's padding (4 + 4) and border (1 + 1) are inside these constraints; the
      // cells share what is left, so a week that fits never scrolls (and the week swipe
      // below is not taken over by the horizontal scroll view).
      final inner = constraints.maxWidth - 10;
      final width = math.max(minimumWidth, inner / 7);
      final overflows = width * 7 > inner + .5;
      final align =
          _alignedDay != c.selectedDay || _alignedWidth != constraints.maxWidth;
      _alignedDay = c.selectedDay;
      _alignedWidth = constraints.maxWidth;
      final animate = HistoryMotion.enabled(context);
      if (align) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_scroll.hasClients) return;
          final offset = (days.indexOf(c.selectedDay) * width +
                  width / 2 -
                  constraints.maxWidth / 2)
              .clamp(0.0, _scroll.position.maxScrollExtent);
          if ((_scroll.offset - offset).abs() > 1) {
            if (animate) {
              unawaited(_scroll.animateTo(offset,
                  duration: HistoryMotion.entrance,
                  curve: Curves.easeOutCubic));
            } else {
              _scroll.jumpTo(offset);
            }
          }
        });
      }
      final card = Container(
        key: const Key('history-week-card'),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
        decoration: BoxDecoration(
          color: ReminderPalette.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ReminderPalette.outline),
        ),
        child: Scrollbar(
          controller: _scroll,
          thumbVisibility: overflows,
          child: SingleChildScrollView(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            physics: overflows ? null : const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.only(bottom: overflows ? AppSpacing.sm : 0),
            child: HistoryEntrance(
              key: ValueKey(('history-week', days.first)),
              offset: _weekDirection == 0
                  ? Offset.zero
                  : HistoryMotion.travel(_weekDirection),
              child: Stack(children: [
                if (selectedIndex >= 0)
                  AnimatedPositioned(
                    key: const Key('history-week-indicator'),
                    duration: animate ? HistoryMotion.selection : Duration.zero,
                    curve: Curves.easeOutCubic,
                    left: selectedIndex * width + 4,
                    top: 0,
                    width: width - 8,
                    height: height,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: ReminderPalette.teal,
                        borderRadius: BorderRadius.circular(AppRadius.field),
                      ),
                    ),
                  ),
                Row(children: [
                  for (final day in days)
                    SizedBox(
                      width: width,
                      height: height,
                      child: Semantics(
                        label:
                            '${HistoryFormat.dayHeading(day, today: c.today)}${day.isAfter(c.today) ? ', chưa đến ngày' : ''}${_markerLabel(c, day)}',
                        button: true,
                        selected: day == c.selectedDay,
                        enabled: !day.isAfter(c.today),
                        child: ExcludeSemantics(
                          child: InkWell(
                            key: ValueKey('history-week-${day.day}'),
                            borderRadius:
                                BorderRadius.circular(AppRadius.field),
                            onTap: day.isAfter(c.today)
                                ? null
                                : () => unawaited(_choose(day)),
                            child: HistorySelection(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 2),
                              decoration: BoxDecoration(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.field),
                                border: day == c.today && day != c.selectedDay
                                    ? Border.all(color: ReminderPalette.teal)
                                    : null,
                              ),
                              child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                        HistoryFormat.weekdays[day.weekday - 1],
                                        maxLines: 1,
                                        style: AppTextStyles.caption.copyWith(
                                            color: day == c.selectedDay
                                                ? Colors.white
                                                : day.isAfter(c.today)
                                                    ? AppColors.inkDisabled
                                                    : AppColors.inkMuted)),
                                    const SizedBox(height: AppSpacing.xs),
                                    AnimatedSwitcher(
                                      duration: animate
                                          ? HistoryMotion.selection
                                          : Duration.zero,
                                      transitionBuilder: (child, animation) =>
                                          ScaleTransition(
                                              scale: Tween(begin: .9, end: 1.0)
                                                  .animate(animation),
                                              child: FadeTransition(
                                                  opacity: animation,
                                                  child: child)),
                                      child: day == c.selectedDay
                                          ? CircleAvatar(
                                              key: const ValueKey('selected'),
                                              radius: 16,
                                              backgroundColor: Colors.white,
                                              child: FittedBox(
                                                child: Text('${day.day}',
                                                    style: AppTextStyles
                                                        .captionStrong
                                                        .copyWith(
                                                            color:
                                                                ReminderPalette
                                                                    .teal)),
                                              ),
                                            )
                                          : _WeekMarker(
                                              key: const ValueKey('marker'),
                                              day: day,
                                              controller: c),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(_footer(c, day),
                                        maxLines: 1,
                                        style: AppTextStyles.caption.copyWith(
                                            fontSize: 11,
                                            color: day == c.selectedDay
                                                ? Colors.white
                                                : AppColors.inkMuted)),
                                  ]),
                            ),
                          ),
                        ),
                      ),
                    ),
                ]),
              ]),
            ),
          ),
        ),
      );
      if (overflows) return card;
      return GestureDetector(
        key: const Key('history-week-swipe'),
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: (_) => _drag = 0,
        onHorizontalDragUpdate: (d) => _drag += d.primaryDelta ?? 0,
        onHorizontalDragEnd: _swipeWeek,
        child: card,
      );
    });
  }

  String _footer(AdherenceHistoryController c, DateTime day) {
    final summary = c.dayGroup(day)?.summary;
    if (day == c.selectedDay && summary != null && summary.total > 0) {
      return '${summary.taken + summary.late}/${summary.total}';
    }
    return '${day.day}';
  }

  String _markerLabel(AdherenceHistoryController c, DateTime day) =>
      switch (HistoryFormat.marker(c.dayGroup(day)?.summary)) {
        HistoryDayMarker.complete => ', đủ liều',
        HistoryDayMarker.missed => ', có bỏ lỡ',
        HistoryDayMarker.pending => ', còn liều đang chờ',
        null => '',
      };
}

class _WeekMarker extends StatelessWidget {
  const _WeekMarker({super.key, required this.day, required this.controller});

  final DateTime day;
  final AdherenceHistoryController controller;

  @override
  Widget build(BuildContext context) {
    final marker = HistoryFormat.marker(controller.dayGroup(day)?.summary);
    final color = switch (marker) {
      HistoryDayMarker.complete => ReminderPalette.success,
      HistoryDayMarker.missed => ReminderPalette.missed,
      HistoryDayMarker.pending => ReminderPalette.pending,
      null => AppColors.inkDisabled,
    };
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: switch (marker) {
          HistoryDayMarker.complete => ReminderPalette.successBackground,
          HistoryDayMarker.missed => ReminderPalette.missedBackground,
          _ => null,
        },
        border: Border.all(color: color),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: switch (marker) {
        HistoryDayMarker.complete => Icon(Icons.check, size: 15, color: color),
        HistoryDayMarker.missed =>
          Icon(Icons.priority_high, size: 15, color: color),
        _ => FittedBox(
            child: Text('${day.day}',
                style: AppTextStyles.captionStrong.copyWith(color: color)),
          ),
      },
    );
  }
}
