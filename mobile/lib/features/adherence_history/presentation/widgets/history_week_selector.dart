import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../app/theme/app_theme.dart';
import '../state/adherence_history_controller.dart';
import '../utils/adherence_history_format.dart';
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

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final days = HistoryFormat.week(c.selectedDay);
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
    final minimumWidth = math.max(
        AppSizes.tapTarget,
        math.max(daySize.width, math.max(sundaySize.width, weekdaySize.width)) +
            16);
    final height = math.max(
        68.0,
        (daySize.height + math.max(sundaySize.height, weekdaySize.height) + 24)
            .ceilToDouble());
    return LayoutBuilder(builder: (context, constraints) {
      final width = math.max(minimumWidth, constraints.maxWidth / 7);
      final overflows = width * 7 > constraints.maxWidth;
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
      return Scrollbar(
        controller: _scroll,
        thumbVisibility: overflows,
        child: SingleChildScrollView(
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.only(bottom: overflows ? AppSpacing.sm : 0),
          child: Row(children: [
            for (final day in days)
              SizedBox(
                width: width,
                height: height,
                child: Semantics(
                  button: true,
                  selected: day == c.selectedDay,
                  enabled: !day.isAfter(c.today),
                  label:
                      '${HistoryFormat.dayHeading(day, today: c.today)}${day.isAfter(c.today) ? ', chưa đến ngày' : ''}',
                  child: ExcludeSemantics(
                    child: InkWell(
                      key: ValueKey('history-week-${day.day}'),
                      borderRadius: BorderRadius.circular(AppRadius.field),
                      onTap: day.isAfter(c.today)
                          ? null
                          : () => unawaited(c.selectDay(day)),
                      child: HistorySelection(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 2),
                        decoration: BoxDecoration(
                          color: day == c.selectedDay ? AppColors.brand : null,
                          borderRadius: BorderRadius.circular(AppRadius.field),
                          border: day == c.today && day != c.selectedDay
                              ? Border.all(color: AppColors.brand)
                              : null,
                        ),
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(HistoryFormat.weekdays[day.weekday - 1],
                                  maxLines: 1,
                                  style: AppTextStyles.caption.copyWith(
                                      color: day == c.selectedDay
                                          ? AppColors.onBrand
                                          : day.isAfter(c.today)
                                              ? AppColors.inkDisabled
                                              : AppColors.inkMuted)),
                              const SizedBox(height: AppSpacing.xs),
                              Text('${day.day}',
                                  maxLines: 1,
                                  style: AppTextStyles.bodyStrong.copyWith(
                                      color: day == c.selectedDay
                                          ? AppColors.onBrand
                                          : day.isAfter(c.today)
                                              ? AppColors.inkDisabled
                                              : AppColors.ink)),
                            ]),
                      ),
                    ),
                  ),
                ),
              ),
          ]),
        ),
      );
    });
  }
}
