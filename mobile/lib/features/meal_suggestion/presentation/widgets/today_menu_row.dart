import 'package:flutter/material.dart';

import '../../../../app/router.dart';
import '../../data/meal_choice_store.dart';
import '../../domain/entities/meal_suggestion.dart';
import '../screens/meal_suggestion_screen.dart';
import '../state/meal_plan_controller.dart';
import '../state/meal_plan_scope.dart';
import 'meal_greeting.dart';
import 'meal_ui.dart';
import 'meal_widgets.dart';

/// Hàng "Thực đơn hôm nay" ở Trang chủ (AC14): 3 ô Sáng/Trưa/Tối với món đã chọn.
///
/// Chỉ hiện khi đã chọn ít nhất 1 món hôm nay; chạm một ô mở màn kết quả ở đúng bữa.
/// Chỉ liệt kê món, không có câu đánh giá món với thuốc (QD-37).
class TodayMenuRow extends StatelessWidget {
  const TodayMenuRow({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = MealPlanScope.maybeOf(context);
    if (scope == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: Listenable.merge([scope.choices, scope.plan]),
      builder: (context, _) {
        final choices = scope.choices.choices;
        if (choices.isEmpty) return const SizedBox.shrink();
        return Padding(
          key: const ValueKey('today-menu-row'),
          padding: const EdgeInsets.only(top: 18),
          child: MealTypography(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Thực đơn hôm nay',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Row(children: [
                for (final m in MealType.values) ...[
                  Expanded(
                    child: _MealTile(
                        meal: m, choice: choices[m], plan: scope.plan),
                  ),
                  if (m != MealType.toi) const SizedBox(width: 10),
                ],
              ]),
            ]),
          ),
        );
      },
    );
  }
}

class _MealTile extends StatelessWidget {
  const _MealTile(
      {required this.meal, required this.choice, required this.plan});
  final MealType meal;
  final MealChoice? choice;
  final MealPlanController plan;

  /// Ảnh món nếu thực đơn hôm nay còn trong bộ nhớ; không thì icon giữ chỗ.
  Widget _picture() {
    final c = choice;
    final result = plan.stateOf(meal).result;
    if (c != null &&
        result != null &&
        result.suggestionId == c.suggestionId &&
        c.dishIndex < result.dishes.length) {
      final dish = result.dishes[c.dishIndex];
      return MealImageView(
        image: plan.imageOf(dish),
        loadBytes: plan.imageBytes,
        height: 52,
        showAttribution: false,
        placeholderIcon: dishTypeAsset(dish.dishType),
        borderRadius: BorderRadius.circular(26),
      );
    }
    return Container(
      decoration:
          const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFF1F4F2)),
      alignment: Alignment.center,
      child: FoodIcon(c == null ? 'list' : 'salad', size: 26),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = choice;
    return Semantics(
      button: true,
      label: '${meal.tabLabel}: ${c?.name ?? 'Chưa chọn'}',
      excludeSemantics: true,
      child: Pressable(
        key: ValueKey('today-menu-${meal.apiValue}'),
        onTap: () => Navigator.pushNamed(context, AppRoutes.mealSuggestion,
            arguments: MealRouteArgs(initialMeal: meal)),
        child: Container(
          constraints: const BoxConstraints(minHeight: 132),
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: c == null ? MealColors.line : const Color(0xFFCFE8E2)),
          ),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(MealGreeting.icon(meal),
                  size: 16, color: MealGreeting.tint(meal)),
              const SizedBox(width: 4),
              Text(meal.tabLabel,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: MealColors.ink2)),
            ]),
            const SizedBox(height: 8),
            SizedBox(width: 52, height: 52, child: _picture()),
            const SizedBox(height: 8),
            Text(
              c?.name ?? 'Chưa chọn',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  height: 1.3,
                  fontWeight: c == null ? FontWeight.w400 : FontWeight.w600,
                  color: c == null ? MealColors.ink2 : MealColors.ink),
            ),
          ]),
        ),
      ),
    );
  }
}
