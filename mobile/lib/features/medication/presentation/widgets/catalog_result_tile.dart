import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/medication.dart';
import 'dosage_form_icon.dart';
import 'medication_labels.dart';

/// Nội dung một dòng kết quả tìm thuốc, **cùng một khuôn** cho mọi thuốc (nhận xét 5 của
/// adhoc-20261120-add-medication-ux):
/// 1. Tên in đậm + nhãn hàm lượng;
/// 2. "Hoạt chất: …" tối đa 2 dòng, dư thì "+N hoạt chất";
/// 3. Icon + dạng bào chế.
/// Trường thiếu ghi "Chưa có thông tin" thay vì để trống hay hiện con số đứng một mình.
class CatalogResultTile extends StatelessWidget {
  const CatalogResultTile({super.key, required this.item, this.inUse = false});

  final DrugCatalogItem item;
  final bool inUse;

  /// Số hoạt chất hiện ra trước khi gộp thành "+N hoạt chất".
  static const maxIngredients = 2;

  static const missing = 'Chưa có thông tin';

  /// Tách danh sách hoạt chất thô của danh mục theo `;`.
  static (String, int) ingredientSummary(String raw) {
    final parts = raw
        .split(';')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.isEmpty) return (missing, 0);
    final shown = parts.take(maxIngredients).join('; ');
    return (shown, parts.length - maxIngredients > 0 ? parts.length - maxIngredients : 0);
  }

  @override
  Widget build(BuildContext context) {
    final strength = item.strength.trim();
    final form = item.dosageForm.trim();
    final (ingredients, more) = ingredientSummary(item.activeIngredient);
    final muted = AppTextStyles.caption.copyWith(color: AppColors.inkMuted);

    return Column(
      key: const Key('catalog-result-tile'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Wrap: tên dùng hết chiều ngang, nhãn hàm lượng xuống dòng khi không đủ chỗ (chữ phóng
        // to trên màn hẹp) thay vì ép tên thành cột hẹp nhiều dòng.
        Wrap(
            spacing: AppSpacing.sm,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
          Text(item.name, style: AppTextStyles.bodyStrong),
          Container(
            key: const Key('catalog-result-strength'),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: strength.isEmpty ? AppColors.surfaceMuted : AppColors.brandTint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              strength.isEmpty ? 'Chưa rõ hàm lượng' : formatStrength(strength),
              style: AppTextStyles.caption.copyWith(
                color: strength.isEmpty ? AppColors.inkMuted : AppColors.brand,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ]),
        const SizedBox(height: 4),
        Text.rich(
          key: const Key('catalog-result-ingredients'),
          TextSpan(children: [
            const TextSpan(text: 'Hoạt chất: '),
            TextSpan(
              text: ingredients,
              style: ingredients == missing
                  ? null
                  : AppTextStyles.caption.copyWith(color: AppColors.ink),
            ),
            if (more > 0)
              TextSpan(
                text: ' +$more hoạt chất',
                style: AppTextStyles.captionStrong.copyWith(color: AppColors.brand),
              ),
          ]),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: muted,
        ),
        const SizedBox(height: 4),
        Row(key: const Key('catalog-result-form'), children: [
          DosageFormIcon(dosageForm: form, size: 16, color: AppColors.inkMuted),
          const SizedBox(width: 6),
          Expanded(child: Text(form.isEmpty ? missing : form, style: muted)),
          if (inUse)
            const Text('Đang dùng', style: AppTextStyles.captionStrong),
        ]),
      ],
    );
  }
}
