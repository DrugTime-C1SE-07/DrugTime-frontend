import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../adherence/domain/entities/adherence_history.dart';
import '../../domain/monitor_digest.dart';
import '../../domain/monitor_models.dart';
import 'dose_status_chip.dart';
import 'monitor_palette.dart';

/// Ô màu nhỏ đại diện một loại thuốc, màu ổn định theo id thuốc.
class MedicationTile extends StatelessWidget {
  const MedicationTile({super.key, required this.seed, this.size = 48});
  final int seed;
  final double size;

  static const _tints = [
    (Color(0xFFE3F4EA), Color(0xFF7CC28A)),
    (Color(0xFFFFF4D6), Color(0xFFF2C94C)),
    (Color(0xFFE2F1FB), Color(0xFF7FB8E6)),
    (Color(0xFFFCE7EE), Color(0xFFE88FAA)),
    (Color(0xFFEDE7FB), Color(0xFF9B87E8)),
  ];

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _tints[seed.abs() % _tints.length];
    return Container(
      width: size,
      height: size,
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Icon(Icons.medication_rounded, color: fg, size: size * .55),
    );
  }
}

/// Một dòng liều hôm nay: ô thuốc, giờ (đỏ nếu bỏ lỡ), tên thuốc, chip trạng thái.
class DoseRow extends StatelessWidget {
  const DoseRow(
      {super.key, required this.dose, required this.asOf, required this.onTap});

  final AdherenceDose dose;
  final DateTime asOf;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final alert = needsAttention(dose, asOf);
    return Material(
      color: alert ? MonitorColors.missedTint.withValues(alpha: .5) : null,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(children: [
            MedicationTile(seed: dose.medicationId),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(monitorTime(dose.scheduledAt),
                        style: AppTextStyles.caption.copyWith(
                            color: alert
                                ? MonitorColors.missed
                                : AppColors.inkMuted)),
                    Text(dose.medicationName,
                        style: AppTextStyles.bodyStrong,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ]),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Align(
                alignment: Alignment.centerRight,
                child: DoseStatusChip(dose: dose, asOf: asOf),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
