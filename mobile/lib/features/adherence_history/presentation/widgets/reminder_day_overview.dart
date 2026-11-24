import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/adherence_history.dart';
import '../utils/adherence_history_format.dart';
import '../utils/reminder_palette.dart';
import 'history_motion.dart';

/// The compact "Hộp thuốc hôm nay" progress strip shown in the Figma day view.
class ReminderDayOverview extends StatefulWidget {
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
  State<ReminderDayOverview> createState() => _ReminderDayOverviewState();
}

class _ReminderDayOverviewState extends State<ReminderDayOverview> {
  final _strip = ScrollController();
  final _focusChip = GlobalKey();
  Object? _scrolledFor;

  @override
  void dispose() {
    _strip.dispose();
    super.dispose();
  }

  /// Index of the chip to bring into view: on today the first pending dose, else none.
  int? _focusIndex(List<HistoryDose> doses) {
    if (widget.day != widget.today) return null;
    final index =
        doses.indexWhere((d) => d.status == HistoryDoseStatus.pending);
    return index < 0 ? null : index;
  }

  void _scrollToFocus(Object token) {
    if (_scrolledFor == token) return;
    _scrolledFor = token;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _focusChip.currentContext;
      if (!mounted || target == null) return;
      Scrollable.ensureVisible(target,
          alignment: .5,
          duration: HistoryMotion.enabled(context)
              ? HistoryMotion.entrance
              : Duration.zero,
          curve: Curves.easeOutCubic);
    });
  }

  @override
  Widget build(BuildContext context) {
    final day = widget.day, today = widget.today, group = widget.group;
    final summary = group?.summary;
    final doses = List<HistoryDose>.of(group?.doses ?? const [])
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    final completed = (summary?.taken ?? 0) + (summary?.late ?? 0);
    final total = summary?.total ?? 0;
    final ratio = '$completed/$total';
    final focus = _focusIndex(doses);
    if (focus != null) {
      _scrollToFocus((day, doses[focus].scheduleId, doses[focus].scheduledAt));
    }
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
                    _CountUp(
                        completed: completed,
                        total: total,
                        semanticsLabel: '$ratio liều'),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _ProgressRing(value: total == 0 ? 0 : completed / total),
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
              controller: _strip,
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var index = 0; index < doses.length; index++) ...[
                    if (index > 0) const SizedBox(width: 5),
                    _TimelineDose(
                        key: index == focus ? _focusChip : null,
                        dose: doses[index]),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// "3/5 liều": the taken count runs up from 0 when the box appears or the ratio changes.
class _CountUp extends StatelessWidget {
  const _CountUp(
      {required this.completed,
      required this.total,
      required this.semanticsLabel});
  final int completed, total;
  final String semanticsLabel;

  Widget _text(int value) => Text.rich(
      TextSpan(children: [
        TextSpan(
          text: '$value/$total',
          style: AppTextStyles.title.copyWith(fontSize: 30),
        ),
        const TextSpan(text: ' liều', style: AppTextStyles.caption),
      ]),
      semanticsLabel: semanticsLabel);

  @override
  Widget build(BuildContext context) => !HistoryMotion.enabled(context)
      ? _text(completed)
      : TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: completed.toDouble()),
          duration: HistoryMotion.progress,
          curve: Curves.easeOutCubic,
          builder: (_, value, __) => _text(value.round()));
}

/// Share of the day's doses already taken (on time or late). It is not the adherence rate
/// (QD-42), so it carries no percentage or "tuân thủ" wording.
class _ProgressRing extends StatelessWidget {
  const _ProgressRing({required this.value});
  final double value;

  Widget _ring(double current) => SizedBox.square(
        key: const Key('history-progress-ring'),
        dimension: 44,
        child: CustomPaint(painter: _RingPainter(current)),
      );

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: !HistoryMotion.enabled(context)
            ? _ring(value)
            : TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: value),
                duration: HistoryMotion.progress,
                curve: Curves.easeOutCubic,
                builder: (_, current, __) => _ring(current)),
      );
}

class _RingPainter extends CustomPainter {
  const _RingPainter(this.value);
  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 5.0;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final base = Paint()
      ..color = ReminderPalette.surface
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawArc(rect, 0, 2 * math.pi, false, base);
    if (value <= 0) return;
    final arc = Paint()
      ..color = ReminderPalette.success
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke;
    canvas.drawArc(
        rect, -math.pi / 2, 2 * math.pi * value.clamp(0.0, 1.0), false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.value != value;
}

class _TimelineDose extends StatelessWidget {
  const _TimelineDose({super.key, required this.dose});

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
