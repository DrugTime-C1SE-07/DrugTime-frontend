import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../interaction_check/domain/entities/interaction_check_result.dart';
import '../../../medication/domain/entities/medication.dart';
import 'dose_row.dart';
import 'monitor_palette.dart';

/// Ngưỡng "sắp hết" của tồn kho.
const lowStockThreshold = 3;

/// R5 · Tủ thuốc: banner tương tác (nếu có) và danh sách thuốc với chip tồn kho.
class CabinetView extends StatelessWidget {
  const CabinetView({
    super.key,
    required this.medications,
    required this.interactions,
    required this.foodWarnings,
    required this.onOpenInteractions,
  });

  final List<Medication> medications;

  /// null = đang tải hoặc lỗi; banner chỉ hiện khi đã có kết quả.
  final InteractionCheckResult? interactions;
  final int foodWarnings;
  final VoidCallback onOpenInteractions;

  @override
  Widget build(BuildContext context) {
    final found = interactions?.interactions ?? const [];
    final count = found.length + foodWarnings;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (interactions != null)
        Material(
          key: const Key('cabinet-interaction-banner'),
          color: count > 0 ? AppColors.cautionBg : MonitorColors.takenTint,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onOpenInteractions,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Icon(
                    count > 0
                        ? Icons.warning_amber_rounded
                        : Icons.verified_outlined,
                    color: count > 0
                        ? AppColors.cautionText
                        : MonitorColors.taken),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            count > 0
                                ? '$count tương tác cần theo dõi'
                                : interactions!.status.label,
                            style: AppTextStyles.bodyStrong.copyWith(
                                color: count > 0
                                    ? AppColors.cautionText
                                    : MonitorColors.taken)),
                        if (found.isNotEmpty)
                          Text(
                              '${found.first.ingredientAName} ⇄ ${found.first.ingredientBName}',
                              style: AppTextStyles.caption
                                  .copyWith(color: AppColors.cautionText)),
                      ]),
                ),
                const Icon(Icons.chevron_right),
              ]),
            ),
          ),
        ),
      if (interactions != null) const SizedBox(height: 12),
      if (medications.isEmpty) const Text('Chưa có thuốc đang dùng.'),
      for (final medication in medications)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Row(children: [
              MedicationTile(seed: medication.id.hashCode, size: 56),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          [medication.name, medication.strength]
                              .where((s) => s.isNotEmpty)
                              .join(' '),
                          style: AppTextStyles.heading),
                      const SizedBox(height: 2),
                      Text(
                          '${_amount(medication.dosePerIntake)} ${medication.unit} · ${medication.timing.label}',
                          style: AppTextStyles.caption),
                      const SizedBox(height: 8),
                      StockChip(medication: medication),
                    ]),
              ),
            ]),
          ),
        ),
    ]);
  }

  static String _amount(num value) =>
      value == value.roundToDouble() ? '${value.round()}' : '$value';
}

/// Chip tồn kho: chưa cập nhật / hết thuốc / sắp hết (≤ [lowStockThreshold]) / còn N.
class StockChip extends StatelessWidget {
  const StockChip({super.key, required this.medication});
  final Medication medication;

  @override
  Widget build(BuildContext context) {
    final stock = medication.stockRemaining;
    final (bg, fg, label) = stock == null
        ? (
            MonitorColors.upcomingTint,
            AppColors.inkMuted,
            'Chưa cập nhật số lượng'
          )
        : stock == 0
            ? (MonitorColors.missedTint, MonitorColors.missed, 'Hết thuốc')
            : stock <= lowStockThreshold
                ? (
                    MonitorColors.lateTint,
                    MonitorColors.late,
                    'Còn $stock ${medication.unit} — sắp hết'
                  )
                : (
                    MonitorColors.upcomingTint,
                    AppColors.inkMuted,
                    'Còn $stock ${medication.unit}'
                  );
    return Container(
      key: ValueKey('stock-${medication.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.inventory_2_outlined, size: 16, color: fg),
        const SizedBox(width: 6),
        Flexible(
            child: Text(label,
                style: AppTextStyles.captionStrong.copyWith(color: fg))),
      ]),
    );
  }
}
