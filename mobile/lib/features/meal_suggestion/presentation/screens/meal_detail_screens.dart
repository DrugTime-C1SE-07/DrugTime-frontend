import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/meal_suggestion.dart';
import '../state/meal_suggestion_controller.dart';
import '../widgets/meal_widgets.dart';

/// Chi tiết món (S05-D1, S05-D1c): tab Lợi ích / Nên tránh, nút "Nguyên liệu" ở đáy.
/// Không có "Vì sao", "Cách ăn" (4.26 Q4) hay "Chọn món này" (5.11 Q1).
class MealDetailScreen extends StatelessWidget {
  const MealDetailScreen({
    super.key,
    required this.controller,
    required this.dish,
    required this.result,
  });

  final MealSuggestionController controller;
  final MealDish dish;
  final MealSuggestionResult result;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        appBar: AppBar(title: Text(dish.name)),
        body: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.all(AppSpacing.page),
            children: [
              MealImageView(
                image: controller.imageOf(dish),
                loadBytes: controller.imageBytes,
                height: 200,
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(dish.name, style: AppTextStyles.title),
              const SizedBox(height: AppSpacing.xs),
              Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.xs, children: [
                MealChip(result.mealType.tabLabel),
                MealChip('${kcalLabel(dish.kcalEstimate)}/phần'),
                MealChip('Nấu ${dish.cookMinutes} phút'),
              ]),
              const SizedBox(height: AppSpacing.md),
              const TabBar(tabs: [Tab(text: 'Lợi ích'), Tab(text: 'Nên tránh')]),
              SizedBox(
                height: 260,
                child: TabBarView(children: [
                  _Benefits(dish.benefits),
                  SingleChildScrollView(
                    padding: const EdgeInsets.only(top: AppSpacing.md),
                    child: MealFoodCheckView(result.foodCheck),
                  ),
                ]),
              ),
              MealDisclaimer(result.disclaimer),
              const SizedBox(height: AppSpacing.md),
              FilledButton.icon(
                key: const ValueKey('open-ingredients'),
                icon: const Icon(LucideIcons.salad),
                label: const Text('Nguyên liệu'),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => MealIngredientsScreen(
                      controller: controller, dish: dish, result: result),
                )),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Benefits extends StatelessWidget {
  const _Benefits(this.benefits);

  final List<MealBenefit> benefits;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      children: [
        for (final b in benefits)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(LucideIcons.check, size: 18, color: AppColors.brand),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nhãn lấy từ hồ sơ (bệnh nền, dị ứng, hạn chế); lợi ích chung không nhãn.
                      if (b.label case final label?)
                        Container(
                          margin: const EdgeInsets.only(bottom: 2),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                              color: AppColors.brandTint,
                              borderRadius: BorderRadius.circular(10)),
                          child: Text(label,
                              key: const ValueKey('benefit-label'),
                              style: AppTextStyles.caption
                                  .copyWith(color: AppColors.brand)),
                        ),
                      Text(b.text, style: AppTextStyles.body),
                    ]),
              ),
            ]),
          ),
      ],
    );
  }
}

/// Màn Nguyên liệu (S05-D1n): khẩu phần cố định "1 người" (Q8), không có nút −/+.
class MealIngredientsScreen extends StatelessWidget {
  const MealIngredientsScreen({
    super.key,
    required this.controller,
    required this.dish,
    required this.result,
  });

  final MealSuggestionController controller;
  final MealDish dish;
  final MealSuggestionResult result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('Nguyên liệu')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.card)),
            child: Row(children: [
              SizedBox(
                width: 64,
                child: MealImageView(
                  image: controller.imageOf(dish),
                  loadBytes: controller.imageBytes,
                  height: 56,
                  showAttribution: false,
                  borderRadius: BorderRadius.circular(AppRadius.field),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text(dish.name, style: AppTextStyles.bodyStrong)),
              const MealChip('1 người'),
            ]),
          ),
          _Group(title: 'Nguyên liệu chính', items: dish.mainIngredients),
          _Group(title: 'Gia vị', items: dish.seasonings),
          const SizedBox(height: AppSpacing.md),
          MealDisclaimer(result.disclaimer),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.items});

  final String title;
  final List<MealIngredient> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(title, style: AppTextStyles.heading)),
          Text('${items.length} món', style: AppTextStyles.caption),
        ]),
        const SizedBox(height: AppSpacing.sm),
        Container(
          decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.card)),
          child: Column(children: [
            for (final i in items)
              ListTile(
                leading: Icon(ingredientIcon(i), color: AppColors.brand),
                title: Row(children: [
                  Flexible(child: Text(i.name, style: AppTextStyles.body)),
                  if (i.useSparingly) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                          color: AppColors.cautionBg,
                          borderRadius: BorderRadius.circular(10)),
                      child: Text('Dùng ít',
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.cautionText)),
                    ),
                  ],
                ]),
                trailing: Text(i.amount, style: AppTextStyles.body),
              ),
          ]),
        ),
      ]),
    );
  }
}

/// Danh sách tất cả món ("Xem tất cả"). Figma không có màn riêng: danh sách dọc theo kiểu thẻ.
class MealListScreen extends StatelessWidget {
  const MealListScreen({super.key, required this.controller, required this.result});

  final MealSuggestionController controller;
  final MealSuggestionResult result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: Text('Món cho ${result.mealType.mealLabel}')),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(AppSpacing.page),
          children: [
            for (final dish in result.dishes)
              Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => MealDetailScreen(
                        controller: controller, dish: dish, result: result),
                  )),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MealImageView(
                            image: controller.imageOf(dish),
                            loadBytes: controller.imageBytes,
                            height: 140),
                        Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(dish.name, style: AppTextStyles.bodyStrong),
                                const SizedBox(height: AppSpacing.xs),
                                Wrap(spacing: AppSpacing.sm, children: [
                                  MealChip(dish.dishType.label),
                                  MealChip(kcalLabel(dish.kcalEstimate)),
                                ]),
                              ]),
                        ),
                      ]),
                ),
              ),
            MealDisclaimer(result.disclaimer),
          ],
        ),
      ),
    );
  }
}
