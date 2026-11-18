import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/app_assets.dart';
import '../../domain/entities/meal_suggestion.dart';

/// Lời miễn trừ hiển thị nguyên văn, không nằm trong tab hay mục thu gọn (R-07, AC10).
class MealDisclaimer extends StatelessWidget {
  const MealDisclaimer(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('meal-disclaimer'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.infoBg,
        borderRadius: BorderRadius.circular(AppRadius.field),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(LucideIcons.info, size: 18, color: AppColors.info),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(text, style: AppTextStyles.caption)),
      ]),
    );
  }
}

/// Ảnh minh họa món: giữ chỗ khi `pending`, ảnh mặc định khi `failed`/không có ảnh/lỗi tải.
/// Ảnh thật luôn kèm nhãn "Ảnh minh họa" và ghi nguồn tác giả / Pexels (AC7).
class MealImageView extends StatelessWidget {
  const MealImageView({
    super.key,
    required this.image,
    required this.loadBytes,
    this.height = 180,
    this.borderRadius = BorderRadius.zero,
    this.showAttribution = true,
  });

  final MealDishImage? image;
  final Future<Uint8List> Function(MealDishImage image) loadBytes;
  final double height;
  final BorderRadius borderRadius;
  final bool showAttribution;

  @override
  Widget build(BuildContext context) {
    final current = image;
    final Widget child;
    if (current == null || current.status == MealImageStatus.failed) {
      child = const _DefaultDishImage();
    } else if (!current.isReady) {
      child = const _PendingDishImage();
    } else {
      child = FutureBuilder<Uint8List>(
        key: ValueKey('meal-image-${current.imageId}'),
        future: loadBytes(current),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return Stack(fit: StackFit.expand, children: [
              Image.memory(snapshot.data!,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (_, __, ___) => const _DefaultDishImage()),
              Positioned(
                left: 8,
                bottom: 8,
                right: 8,
                child: _ImageLabel(
                    attribution: showAttribution ? current.attribution : null),
              ),
            ]);
          }
          if (snapshot.hasError) return const _DefaultDishImage();
          return const _PendingDishImage();
        },
      );
    }
    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(height: height, width: double.infinity, child: child),
    );
  }
}

class _ImageLabel extends StatelessWidget {
  const _ImageLabel({this.attribution});

  final MealImageAttribution? attribution;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(color: Colors.white, fontSize: 11, height: 1.2);
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
            color: Colors.black54, borderRadius: BorderRadius.circular(6)),
        child: const Text('Ảnh minh họa', style: style),
      ),
      const Spacer(),
      if (attribution case final a?)
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
                color: Colors.black54, borderRadius: BorderRadius.circular(6)),
            child: Text('Ảnh: ${a.photographerName} / Pexels',
                style: style, overflow: TextOverflow.ellipsis),
          ),
        ),
    ]);
  }
}

class _DefaultDishImage extends StatelessWidget {
  const _DefaultDishImage();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const ValueKey('meal-image-default'),
      color: AppColors.brandTint,
      child: Center(
        child: Image.asset(AppAssets.mascotCooking, height: 72,
            errorBuilder: (_, __, ___) =>
                const Icon(LucideIcons.cookingPot, color: AppColors.brand)),
      ),
    );
  }
}

class _PendingDishImage extends StatelessWidget {
  const _PendingDishImage();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      key: ValueKey('meal-image-pending'),
      color: AppColors.surfaceMuted,
      child: Center(
        child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2)),
      ),
    );
  }
}

/// Khối "Nên tránh" theo ba trạng thái của engine tất định; không bao giờ ghi "an toàn" (QD-37).
class MealFoodCheckView extends StatelessWidget {
  const MealFoodCheckView(this.check, {super.key});

  final MealFoodCheck check;

  @override
  Widget build(BuildContext context) {
    switch (check.status) {
      case FoodCheckStatus.coTuongTac:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final w in check.warnings)
              Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.cautionBg,
                  borderRadius: BorderRadius.circular(AppRadius.field),
                ),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(LucideIcons.circleAlert,
                          size: 18, color: AppColors.caution),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(w.foodToAvoid,
                                  style: AppTextStyles.bodyStrong),
                              Text(w.reason, style: AppTextStyles.caption),
                              Text('Nguồn: ${w.source}',
                                  style: AppTextStyles.caption),
                            ]),
                      ),
                    ]),
              ),
          ],
        );
      case FoodCheckStatus.daKiemTraKhongThay:
        return const _CheckNote(
            'Chưa thấy tương tác trong dữ liệu hiện có', AppColors.surfaceMuted);
      case FoodCheckStatus.khongDuDuLieu:
        return const _CheckNote(
            'Chưa xác minh được, hãy hỏi dược sĩ', AppColors.cautionBg);
    }
  }
}

class _CheckNote extends StatelessWidget {
  const _CheckNote(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(AppRadius.field)),
        child: Text(text, style: AppTextStyles.body),
      );
}

class MealChip extends StatelessWidget {
  const MealChip(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: AppTextStyles.caption),
      );
}

String kcalLabel(int kcal) => '~$kcal kcal';

/// Biểu tượng nguyên liệu theo từ khóa tên; không khớp thì dùng biểu tượng theo nhóm.
IconData ingredientIcon(MealIngredient ingredient) {
  final name = ingredient.name.toLowerCase();
  const rules = <(List<String>, IconData)>[
    (['gạo', 'cơm', 'bún', 'phở', 'miến', 'mì', 'bánh'], LucideIcons.wheat),
    (['gà', 'vịt'], LucideIcons.drumstick),
    (['bò', 'heo', 'lợn', 'thịt'], LucideIcons.beef),
    (['tôm', 'cua', 'mực'], LucideIcons.shrimp),
    (['cá'], LucideIcons.fish),
    (['trứng'], LucideIcons.egg),
    (['sữa'], LucideIcons.milk),
    (['đậu', 'đỗ'], LucideIcons.bean),
    (['lạc', 'hạt', 'mè', 'vừng'], LucideIcons.nut),
    (['cà rốt', 'củ'], LucideIcons.carrot),
    (['cà chua'], LucideIcons.cherry),
    (['chanh', 'cam', 'quýt'], LucideIcons.citrus),
    (['táo', 'chuối', 'dứa', 'xoài', 'quả', 'trái'], LucideIcons.apple),
    (['rau', 'cải', 'xà lách', 'bí', 'mướp', 'hành', 'ngò', 'rau thơm'],
        LucideIcons.leafyGreen),
    (['dầu', 'nước mắm', 'nước tương', 'xì dầu', 'giấm'], LucideIcons.droplet),
  ];
  for (final (keys, icon) in rules) {
    if (keys.any(name.contains)) return icon;
  }
  return ingredient.isMain ? LucideIcons.salad : LucideIcons.leaf;
}
