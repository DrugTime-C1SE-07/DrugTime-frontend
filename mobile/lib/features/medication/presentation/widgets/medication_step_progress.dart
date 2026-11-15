import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';

/// Thanh tiến trình 3 bước cho luồng Thêm thuốc (Figma Prototype_DrugTime):
/// 1. Thêm thuốc
/// 2. Lịch uống
/// 3. Xác nhận
///
/// Hiển thị 3 vạch tiến trình ngang; chỉ vạch đang hoạt động mới có nhãn tên
/// bước phía trên — đúng theo thiết kế Figma StepProgress/1of3, 2of3, 3of3.
/// Không hiển thị chuỗi "Bước x/3".
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
          // 3 vạch tiến trình ngang với tên tiến trình xuất hiện ở trên vạch tương ứng của bước hiện tại
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (int i = 0; i < stepLabels.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 20,
                        child: i == currentStep
                            ? Text(
                                stepLabels[i],
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.caption.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.brand,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 6),
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
