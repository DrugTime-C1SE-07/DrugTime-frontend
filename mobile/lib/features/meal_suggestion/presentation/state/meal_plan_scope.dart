import 'package:flutter/widgets.dart';

import 'meal_choice_controller.dart';
import 'meal_plan_controller.dart';

/// Đưa thực đơn hôm nay và món đã chọn (mức phiên app) xuống cây widget.
///
/// Hai controller do `app.dart` tạo và hủy; màn hình không tự tạo hay dispose.
class MealPlanScope extends InheritedWidget {
  const MealPlanScope({
    super.key,
    required this.plan,
    required this.choices,
    required super.child,
  });

  final MealPlanController plan;
  final MealChoiceController choices;

  static MealPlanScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MealPlanScope>();

  static MealPlanScope of(BuildContext context) {
    final scope = maybeOf(context);
    assert(scope != null, 'MealPlanScope không có trong cây widget');
    return scope!;
  }

  @override
  bool updateShouldNotify(MealPlanScope oldWidget) =>
      plan != oldWidget.plan || choices != oldWidget.choices;
}
