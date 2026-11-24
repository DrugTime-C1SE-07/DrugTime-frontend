import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../utils/adherence_history_format.dart';
import '../utils/reminder_palette.dart';
import 'history_motion.dart';

/// Hero tag shared by a dose row on the day tab and the card on its detail page.
@immutable
class DoseHeroTag {
  const DoseHeroTag(this.scheduleId, this.scheduledAt);
  final int scheduleId;
  final DateTime scheduledAt;

  @override
  bool operator ==(Object other) =>
      other is DoseHeroTag &&
      other.scheduleId == scheduleId &&
      other.scheduledAt.isAtSameMomentAs(scheduledAt);

  @override
  int get hashCode =>
      Object.hash(scheduleId, scheduledAt.toUtc().microsecondsSinceEpoch);

  @override
  String toString() => 'DoseHeroTag($scheduleId, $scheduledAt)';
}

/// One segment of the vertical line that links the doses of a day, with a dot at the dose.
/// [passed] colours the segment and dot as "already behind us".
class DoseRailSegment extends StatelessWidget {
  const DoseRailSegment({
    super.key,
    required this.passed,
    this.first = false,
    this.last = false,
  });

  final bool passed, first, last;

  static const width = 18.0;
  static const passedColor = ReminderPalette.teal;
  static const upcomingColor = ReminderPalette.outline;

  @override
  Widget build(BuildContext context) {
    final color = passed ? passedColor : upcomingColor;
    return SizedBox(
      width: width,
      child: Stack(alignment: Alignment.topCenter, children: [
        Positioned(
          top: first ? 22 : 0,
          bottom: last ? null : 0,
          height: last ? 22 : null,
          child: Container(
              key: const Key('dose-rail-line'), width: 2, color: color),
        ),
        Positioned(
          top: 16,
          child: Container(
            key: const Key('dose-rail-dot'),
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: passed ? passedColor : ReminderPalette.surface,
              border: Border.all(color: color, width: 2),
            ),
          ),
        ),
      ]),
    );
  }
}

/// "Bây giờ · HH:mm" line placed between the doses already due and the ones still ahead.
/// The time is always shown in Vietnam time.
class NowMarker extends StatelessWidget {
  const NowMarker({super.key, required this.now});
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final label = 'Bây giờ · ${HistoryFormat.time(now)}';
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: Padding(
          key: const Key('history-now-marker'),
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(children: [
            const SizedBox(
              width: DoseRailSegment.width,
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                      color: ReminderPalette.missed, shape: BoxShape.circle),
                  child: SizedBox.square(dimension: 10),
                ),
              ),
            ),
            // Flexible + ellipsis: with large text the label shrinks instead of overflowing.
            Flexible(
              flex: 3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: ReminderPalette.missed,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.captionStrong
                        .copyWith(color: Colors.white, fontSize: 11)),
              ),
            ),
            const SizedBox(width: 6),
            const Expanded(
                child: Divider(
                    height: 2, thickness: 1.5, color: ReminderPalette.missed)),
          ]),
        ),
      ),
    );
  }
}

/// A check mark that draws itself when [animate] flips to true after the first build.
/// The first build always shows the finished mark, so opening the screen does not replay it.
class DrawnCheck extends StatefulWidget {
  const DrawnCheck({super.key, required this.color, this.size = 16});
  final Color color;
  final double size;

  @override
  State<DrawnCheck> createState() => _DrawnCheckState();
}

class _DrawnCheckState extends State<DrawnCheck>
    with SingleTickerProviderStateMixin {
  late final _controller =
      AnimationController(vsync: this, duration: HistoryMotion.check, value: 1);

  /// Starts drawing from an empty mark (used when the status just became "Đã uống").
  void replay() {
    if (!HistoryMotion.enabled(context)) {
      _controller.value = 1;
      return;
    }
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (_, __) => CustomPaint(
            key: const Key('drawn-check'),
            painter: _CheckPainter(
                progress: Curves.easeOutCubic.transform(_controller.value),
                color: widget.color),
          ),
        ),
      );
}

/// Lets a parent ask a [DrawnCheck] to replay.
extension DrawnCheckReplay on GlobalKey<State<DrawnCheck>> {
  void replay() => (currentState as _DrawnCheckState?)?.replay();
}

class _CheckPainter extends CustomPainter {
  const _CheckPainter({required this.progress, required this.color});
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * .18, size.height * .54)
      ..lineTo(size.width * .42, size.height * .76)
      ..lineTo(size.width * .84, size.height * .28);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * .14
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final metric in path.computeMetrics()) {
      canvas.drawPath(metric.extractPath(0, metric.length * progress), paint);
    }
  }

  @override
  bool shouldRepaint(_CheckPainter old) =>
      old.progress != progress || old.color != color;
}
