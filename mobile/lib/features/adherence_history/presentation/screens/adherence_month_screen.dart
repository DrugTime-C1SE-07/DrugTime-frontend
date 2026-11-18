import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/preview/app_preview_scope.dart';
import '../state/adherence_history_controller.dart';
import '../../domain/entities/adherence_history.dart';
import '../widgets/history_summary.dart';
import '../widgets/history_motion.dart';
import '../utils/adherence_history_format.dart';

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
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Row(children: [
            IconButton(
              tooltip: 'Quay lại',
              style: IconButton.styleFrom(
                backgroundColor: AppColors.brandTint,
                foregroundColor: AppColors.brand,
                minimumSize: const Size(48, 48),
              ),
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: PopupMenuButton<int>(
                tooltip: 'Chọn tháng',
                onSelected: (delta) => unawaited(c.changeMonth(delta)),
                itemBuilder: (_) => [
                  if (c.canGoPrevious)
                    const PopupMenuItem(value: -1, child: Text('Tháng trước')),
                  if (c.canGoNext)
                    const PopupMenuItem(value: 1, child: Text('Tháng sau')),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Tháng ${c.selectedMonth.month}, ${c.selectedMonth.year}',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.heading,
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 48,
              child: AppPreviewScope.maybeOf(context) != null
                  ? const Center(child: AppPreviewBadge())
                  : null,
            ),
          ]),
          const SizedBox(height: AppSpacing.xl),
          if (c.loading || c.error != null)
            HistoryLoadState(controller: c, onRetry: widget.onRetry)
          else if (c.history != null) ...[
            HistoryEntrance(
                key: ValueKey((c, c.selectedMonth, 'grid')),
                offset: Offset(12 * _direction, 0),
                child: _PrototypeCalendar(controller: c)),
            const SizedBox(height: AppSpacing.xl),
            HistoryEntrance(
                key: ValueKey((c, c.contentRevision, 'summary')),
                child: _SelectedDayCard(controller: c)),
          ],
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    ))));
  }
}

class _SelectedDayCard extends StatelessWidget {
  const _SelectedDayCard({required this.controller});

  final AdherenceHistoryController controller;

  @override
  Widget build(BuildContext context) {
    final day = controller.selectedDay;
    final summary = controller.selectedGroup?.summary;
    final taken = (summary?.taken ?? 0) + (summary?.late ?? 0);
    final remaining = controller.selectedGroup?.doses
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
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.field),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('$weekday, $date${isToday ? ' · Hôm nay' : ''}',
            style: AppTextStyles.bodyStrong),
        const SizedBox(height: 6),
        Text(
            summary == null
                ? 'Chưa có lịch sử'
                : '$taken/${summary.total} liều đã uống${remaining > 0 ? ' · $remaining liều còn lại trong ngày' : ''}',
            style: AppTextStyles.caption),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: const Key('history-view-day'),
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              backgroundColor: AppColors.brandTint,
              foregroundColor: AppColors.brand,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Flexible(
                  child: Text(isToday
                      ? 'Xem chi tiết ngày hôm nay'
                      : 'Xem chi tiết ngày này')),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right),
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
    final cellHeight = math.max(56.0, scaler.scale(14) + 42);
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity > 100 && controller.canGoPrevious) {
          unawaited(controller.changeMonth(-1));
        } else if (velocity < -100 && controller.canGoNext) {
          unawaited(controller.changeMonth(1));
        }
      },
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        LayoutBuilder(builder: (context, constraints) {
          final width = math.max(constraints.maxWidth, minimumWidth * 7);
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: width,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  for (final weekday in HistoryFormat.weekdays)
                    Expanded(
                        child: Center(
                            child: Text(weekday,
                                style: AppTextStyles.captionStrong
                                    .copyWith(color: AppColors.inkMuted)))),
                ]),
                const SizedBox(height: 20),
                Table(children: [
                  for (var row = 0; row < rows; row++)
                    TableRow(children: [
                      for (var col = 0; col < 7; col++)
                        SizedBox(
                            height: cellHeight,
                            child: _day(context, row * 7 + col - offset + 1, count)),
                    ]),
                ]),
              ]),
            ),
          );
        }),
        const SizedBox(height: 28),
        Wrap(spacing: 20, runSpacing: 8, children: [
          _legend(AppColors.safe, 'Đủ liều'),
          _legend(AppColors.danger, 'Có bỏ lỡ'),
        ]),
      ]),
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

  Widget _day(BuildContext context, int number, int count) {
    if (number < 1 || number > count) return const SizedBox.shrink();
    final day = DateTime.utc(
        controller.selectedMonth.year, controller.selectedMonth.month, number);
    final selected = day == controller.selectedDay;
    final future = day.isAfter(controller.today);
    final summary = controller.dayGroup(day)?.summary;
    final marker = HistoryFormat.marker(summary);
    final Color? dot = switch (marker) {
      HistoryDayMarker.complete => AppColors.safe,
      HistoryDayMarker.missed => AppColors.danger,
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
            color: selected ? AppColors.brand : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('$number',
                style: AppTextStyles.caption.copyWith(
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  color: selected
                      ? AppColors.onBrand
                      : future
                          ? AppColors.inkMuted
                          : AppColors.ink,
                )),
            const SizedBox(height: 6),
            Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: selected ? Colors.transparent : dot,
                  shape: BoxShape.circle,
                )),
          ]),
        ),
      ),
    );
  }
}
