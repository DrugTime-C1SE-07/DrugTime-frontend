import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/meal_suggestion.dart';
import 'meal_ui.dart';

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
/// Ảnh thật luôn kèm nhãn "Ảnh minh họa" và ghi nguồn tác giả / Pixabay (AC7).
class MealImageView extends StatelessWidget {
  const MealImageView({
    super.key,
    required this.image,
    required this.loadBytes,
    this.cachedBytes,
    this.height = 180,
    this.borderRadius = BorderRadius.zero,
    this.showAttribution = true,
    this.placeholderIcon = 'salad',
    this.alignment = Alignment.center,
  });

  final MealDishImage? image;
  final Future<Uint8List> Function(MealDishImage image) loadBytes;

  /// Nội dung đã tải sẵn: có thì vẽ ngay, không qua ô giữ chỗ
  /// (adhoc-20261120-meal-image-loading, AC4).
  final Uint8List? Function(MealDishImage image)? cachedBytes;
  final double height;
  final BorderRadius borderRadius;
  final bool showAttribution;

  /// Icon nguyên liệu trên ảnh giữ chỗ (khi chưa có ảnh hoặc ảnh lỗi).
  final String placeholderIcon;

  /// Căn ảnh trong khung (parallax nhẹ khi vuốt thẻ).
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final current = image;
    final Widget child;
    if (current == null || current.status == MealImageStatus.failed) {
      child = _DefaultDishImage(placeholderIcon);
    } else if (!current.isReady) {
      child = const _PendingDishImage();
    } else if (cachedBytes?.call(current) case final bytes?) {
      child = KeyedSubtree(
          key: ValueKey('meal-image-${current.imageId}'),
          child: _picture(bytes, current));
    } else {
      child = FutureBuilder<Uint8List>(
        key: ValueKey('meal-image-${current.imageId}'),
        future: loadBytes(current),
        builder: (context, snapshot) {
          if (snapshot.hasData) return _picture(snapshot.data!, current);
          if (snapshot.hasError) return _DefaultDishImage(placeholderIcon);
          return const _PendingDishImage();
        },
      );
    }
    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(height: height, width: double.infinity, child: child),
    );
  }

  Widget _picture(Uint8List bytes, MealDishImage current) =>
      Stack(fit: StackFit.expand, children: [
        Image.memory(bytes,
            fit: BoxFit.cover,
            alignment: alignment,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => _DefaultDishImage(placeholderIcon)),
        Positioned(
          left: 8,
          bottom: 8,
          right: 8,
          child: _ImageLabel(
              attribution: showAttribution ? current.attribution : null),
        ),
      ]);
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
            child: Text('Ảnh: ${a.photographerName} / Pixabay',
                style: style, overflow: TextOverflow.ellipsis),
          ),
        ),
    ]);
  }
}

class _DefaultDishImage extends StatelessWidget {
  const _DefaultDishImage(this.icon);

  final String icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const ValueKey('meal-image-default'),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF4E0), Color(0xFFE6F4EC)],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, box) => Center(
          child: FoodIcon(icon,
              size: (box.biggest.shortestSide * .38).clamp(20.0, 80.0)),
        ),
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
      color: Color(0xFFF1EFEA),
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
        return const _CheckNote('Chưa thấy tương tác trong dữ liệu hiện có',
            AppColors.surfaceMuted);
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
