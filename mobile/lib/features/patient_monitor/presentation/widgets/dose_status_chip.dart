import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../adherence/domain/entities/adherence_history.dart';
import '../../domain/monitor_digest.dart';
import '../../domain/monitor_models.dart';
import 'monitor_palette.dart';

/// Chip trạng thái bên phải một liều: giờ uống, "Muộn HH:mm", "Bỏ lỡ", "Sắp tới"…
class DoseStatusChip extends StatelessWidget {
  const DoseStatusChip({super.key, required this.dose, required this.asOf});

  final AdherenceDose dose;
  final DateTime asOf;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon, label) = switch (segmentOf(dose, asOf)) {
      DoseSegment.taken => (
          MonitorColors.takenTint,
          MonitorColors.taken,
          Icons.check_circle_outline,
          monitorTime(dose.takenAt!)
        ),
      DoseSegment.late => (
          MonitorColors.lateTint,
          MonitorColors.late,
          Icons.schedule,
          'Muộn ${monitorTime(dose.takenAt!)}'
        ),
      DoseSegment.missed => (
          MonitorColors.missedTint,
          MonitorColors.missed,
          Icons.error_outline,
          'Bỏ lỡ'
        ),
      DoseSegment.overdue => (
          MonitorColors.missedTint,
          MonitorColors.missed,
          Icons.help_outline,
          'Chưa xác nhận'
        ),
      DoseSegment.upcoming => (
          MonitorColors.upcomingTint,
          AppColors.inkMuted,
          Icons.schedule,
          vietnamWallTime(dose.scheduledAt).hour >= 18 ? 'Tối nay' : 'Sắp tới'
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: fg),
        const SizedBox(width: 4),
        Flexible(
            child: Text(label,
                style: AppTextStyles.captionStrong.copyWith(color: fg))),
      ]),
    );
  }
}
