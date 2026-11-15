import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';

/// Thanh tiến trình 3 bước cho luồng Thêm thuốc (Figma Prototype_DrugTime):
/// 1. Thêm thuốc
/// 2. Lịch uống
/// 3. Xác nhận
///
/// Hiển thị 3 vạch tiến trình ngang với tên bước hiển thị trên vạch tương ứng,
/// vạch đang hoạt động nổi bật với màu thương hiệu, không hiển thị chuỗi "Bước x/3".
class MedicationStepProgress extends StatelessWidget {
  const MedicationStepProgress({
    super.key,
    required this.currentStep,
  }) : assert(currentStep >= 0 && currentStep <= 2);

  final int currentStep;

  static const List<String> stepLabels = [
    'Thêm thuốc',
    'Lịch uống',
    'Xác nhận',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.page,
        vertical: AppSpacing.sm,
      ),
      color: AppColors.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              for (int i = 0; i < stepLabels.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          stepLabels[i],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(
                            fontWeight: i == currentStep
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: i == currentStep
                                ? AppColors.brand
                                : i < currentStep
                                    ? AppColors.inkMuted
                                    : AppColors.inkDisabled,
                          ),
                        ),
                      ),
                      Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: i <= currentStep
                              ? AppColors.brand
                              : AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
