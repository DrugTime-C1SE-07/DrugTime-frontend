import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../app/theme/app_theme.dart';
import '../state/adherence_history_controller.dart';
import '../widgets/adherence_calendar.dart';
import '../widgets/history_summary.dart';
import '../widgets/history_motion.dart';

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
    return HistoryMotionScope(
        child: Scaffold(
            body: SafeArea(
                child: RefreshIndicator(
      onRefresh: c.load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          HistoryMonthHeader(
              controller: c, onBack: () => Navigator.of(context).pop()),
          const SizedBox(height: AppSpacing.xl),
          if (c.loading || c.error != null)
            HistoryLoadState(controller: c, onRetry: widget.onRetry)
          else if (c.history != null) ...[
            HistoryEntrance(
                key: ValueKey((c, c.selectedMonth, 'grid')),
                offset: Offset(12 * _direction, 0),
                child: AdherenceCalendar(
                    controller: c,
                    onDay: (day) => unawaited(c.selectDay(day)))),
            const SizedBox(height: AppSpacing.xl),
            HistoryEntrance(
                key: ValueKey((c, c.contentRevision, 'summary')),
                child: HistorySummary(
                    summary: c.selectedGroup?.summary,
                    day: c.selectedDay,
                    today: c.today,
                    onViewDay: () => Navigator.of(context).pop())),
          ],
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    ))));
  }
}
