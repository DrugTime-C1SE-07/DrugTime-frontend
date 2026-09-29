import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

/// Nút lựa chọn dạng viên. Trạng thái chọn thể hiện bằng nền đặc + dấu tích
/// + chữ đậm, không chỉ bằng màu.
class SelectablePill extends StatelessWidget {
  const SelectablePill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.minHeight = AppSizes.tapTarget,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? AppColors.onBrand : AppColors.ink;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.brand : AppColors.surface,
        shape: StadiumBorder(
          side: selected
              ? BorderSide.none
              : const BorderSide(color: AppColors.border),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (selected) ...[
                    Icon(Icons.check, size: 18, color: foreground),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: (selected
                              ? AppTextStyles.bodyStrong
                              : AppTextStyles.body)
                          .copyWith(color: foreground, height: 1.2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
