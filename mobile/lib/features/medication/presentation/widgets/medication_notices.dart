import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/pill_icon.dart';
import '../../domain/entities/medication.dart';

/// Tóm tắt thuốc sắp hết ở đầu danh sách — để người dùng không phải dò từng thẻ.
class LowStockBanner extends StatelessWidget {
  const LowStockBanner({super.key, required this.medications});

  final List<Medication> medications;

  @override
  Widget build(BuildContext context) {
    final names = medications.map((m) => m.name).join(', ');
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.cautionBg,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.caution.withAlpha(64)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.cautionText),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${medications.length} thuốc sắp hết',
                  style: AppTextStyles.bodyStrong.copyWith(color: AppColors.cautionText),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '$names — nhớ mua thêm trước khi hết.',
                  style: AppTextStyles.caption.copyWith(color: AppColors.cautionText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Trạng thái rỗng: chưa có thuốc nào, hoặc tìm kiếm không ra kết quả.
class MedicationEmptyState extends StatelessWidget {
  const MedicationEmptyState({
    super.key,
    required this.title,
    required this.message,
    required this.onAdd,
  });

  final String title;
  final String message;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: Column(
        children: [
          const PillTile(size: 72),
          const SizedBox(height: AppSpacing.lg),
          Text(title, textAlign: TextAlign.center, style: AppTextStyles.heading),
          const SizedBox(height: AppSpacing.sm),
          Text(message, textAlign: TextAlign.center, style: AppTextStyles.caption),
          const SizedBox(height: AppSpacing.xl),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Thêm thuốc mới'),
          ),
        ],
      ),
    );
  }
}
