import 'package:flutter/material.dart';

import '../../../patient_monitor/domain/monitor_digest.dart';
import '../../../patient_monitor/presentation/widgets/monitor_palette.dart';

/// Thanh tiến độ chia đoạn: mỗi liều hôm nay một đoạn, màu theo trạng thái.
/// Khi xuất hiện các đoạn "đổ đầy" từ trái sang phải (tắt khi giảm chuyển động).
class SegmentedDoseBar extends StatelessWidget {
  const SegmentedDoseBar(
      {super.key, required this.segments, required this.semanticsLabel});

  final List<DoseSegment> segments;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    if (segments.isEmpty) return const SizedBox.shrink();
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Semantics(
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: still ? 1 : 0, end: 1),
          duration: still ? Duration.zero : const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (context, fill, _) => Row(children: [
            for (var i = 0; i < segments.length; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(
                child: Container(
                  key: ValueKey('dose-segment-$i-${segments[i].name}'),
                  height: 8,
                  decoration: BoxDecoration(
                    color: MonitorColors.upcomingTint,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: ((fill * segments.length) - i).clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: MonitorColors.segment(segments[i]),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}
