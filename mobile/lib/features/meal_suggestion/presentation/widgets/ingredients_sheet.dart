import 'package:flutter/material.dart';

import '../../domain/entities/meal_suggestion.dart';
import '../state/meal_plan_controller.dart';
import 'meal_ui.dart';
import 'meal_widgets.dart';

/// Nguyên liệu dạng bottom sheet kéo lên (S05-D1n); khẩu phần cố định "1 người", không có −/+ (AC11).
Future<void> showIngredientsSheet(
  BuildContext context, {
  required MealPlanController plan,
  required MealDish dish,
  required String disclaimer,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MealTypography(
        child: DraggableScrollableSheet(
          initialChildSize: .66,
          minChildSize: .4,
          maxChildSize: .92,
          builder: (context, scroll) => Container(
            key: const ValueKey('ingredients-sheet'),
            decoration: const BoxDecoration(
              color: MealColors.canvas,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                        color: const Color(0xFFD5DAD7),
                        borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20)),
                  child: Row(children: [
                    SizedBox(
                      width: 58,
                      height: 58,
                      child: MealImageView(
                        image: plan.imageOf(dish),
                        loadBytes: plan.imageBytes,
                        cachedBytes: plan.cachedImageBytes,
                        height: 58,
                        showAttribution: false,
                        placeholderIcon: dishTypeAsset(dish.dishType),
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(dish.name,
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: MealColors.ink)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                          color: MealColors.chip,
                          borderRadius: BorderRadius.circular(20)),
                      child: const Text('1 người',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: MealColors.ink)),
                    ),
                  ]),
                ),
                for (final (title, items) in [
                  ('Nguyên liệu chính', dish.mainIngredients),
                  ('Gia vị', dish.seasonings),
                ])
                  if (items.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Row(children: [
                      Expanded(
                          child: Text(title,
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: MealColors.ink))),
                      Text('${items.length} món',
                          style: const TextStyle(
                              fontSize: 14, color: MealColors.ink2)),
                    ]),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20)),
                      child: Column(children: [
                        for (var i = 0; i < items.length; i++)
                          StaggerIn(
                            index: i,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(children: [
                                IconTile(ingredientAsset(items[i]), size: 42),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Text(items[i].name,
                                          style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: MealColors.ink)),
                                      if (items[i].useSparingly)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                              color: const Color(0xFFFFF1D6),
                                              borderRadius:
                                                  BorderRadius.circular(20)),
                                          child: const Text('Dùng ít',
                                              style: TextStyle(
                                                  fontSize: 13,
                                                  color: Color(0xFF8A5A00),
                                                  fontWeight: FontWeight.w700)),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(items[i].amount,
                                    style: const TextStyle(
                                        fontSize: 15, color: MealColors.ink2)),
                              ]),
                            ),
                          ),
                      ]),
                    ),
                  ],
                const SizedBox(height: 16),
                MealDisclaimer(disclaimer),
              ],
            ),
          ),
        ),
      ),
    );
