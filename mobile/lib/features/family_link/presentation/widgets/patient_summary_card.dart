import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../patient_monitor/domain/monitor_digest.dart';
import '../../../patient_monitor/domain/monitor_models.dart';
import '../../../patient_monitor/presentation/widgets/monitor_palette.dart';
import 'segmented_dose_bar.dart';

/// Card một người được theo dõi trên hub (R1): avatar chữ cái, liều tới, thanh tiến độ
/// chia đoạn và dòng tóm tắt có màu. [snapshot] null = đang tải; [failed] = lỗi tải.
class PatientSummaryCard extends StatelessWidget {
  const PatientSummaryCard({
    super.key,
    required this.patientId,
    required this.name,
    required this.now,
    required this.onTap,
    this.snapshot,
    this.failed = false,
  });

  final String patientId, name;
  final MonitorSnapshot? snapshot;
  final bool failed;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final data = snapshot;
    final doses = data?.dosesForDay(now) ?? const [];
    final asOf = data?.report.history.asOf ?? now;
    final summary = data == null ? null : hubSummary(doses, asOf);
    final alert = summary?.tone == SummaryTone.alert;
    final (bg, fg) = MonitorColors.avatar(patientId);
    final next = summary?.next;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
              color: alert
                  ? MonitorColors.missed.withValues(alpha: .35)
                  : Colors.transparent,
              width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Hero(
                      tag: 'patient-avatar-$patientId',
                      child: CircleAvatar(
                        radius: 26,
                        backgroundColor: bg,
                        child: Text(nameInitials(name),
                            style: AppTextStyles.heading.copyWith(color: fg)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                style: AppTextStyles.heading,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Text(
                              data == null
                                  ? (failed
                                      ? 'Chưa tải đủ dữ liệu · Kéo xuống để thử lại'
                                      : 'Đang tải hôm nay…')
                                  : next == null
                                      ? 'Không còn liều nào hôm nay'
                                      : 'Liều tới: ${monitorTime(next.scheduledAt)} ${next.medicationName}',
                              style: AppTextStyles.caption,
                            ),
                          ]),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.inkMuted),
                  ]),
                  if (summary != null && summary.total > 0) ...[
                    const SizedBox(height: 14),
                    SegmentedDoseBar(
                      segments: doseSegments(doses, asOf),
                      semanticsLabel:
                          'Đã xác nhận ${summary.confirmed} trên ${summary.total} liều',
                    ),
                  ],
                  if (summary != null) ...[
                    const SizedBox(height: 12),
                    _SummaryPill(summary: summary),
                  ],
                ]),
          ),
        ),
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({required this.summary});
  final HubSummary summary;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon) = switch (summary.tone) {
      SummaryTone.alert => (
          MonitorColors.missedTint,
          MonitorColors.missed,
          Icons.error_outline
        ),
      SummaryTone.good => (
          MonitorColors.takenTint,
          MonitorColors.taken,
          Icons.check_circle_outline
        ),
      SummaryTone.neutral => (
          MonitorColors.upcomingTint,
          AppColors.inkMuted,
          Icons.schedule
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Icon(icon, size: 20, color: fg),
        const SizedBox(width: 8),
        Expanded(
            child: Text(summary.line,
                style: AppTextStyles.bodyStrong.copyWith(color: fg))),
      ]),
    );
  }
}
