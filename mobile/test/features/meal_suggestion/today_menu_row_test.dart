// Hàng "Thực đơn hôm nay" ở Trang chủ (AC14).
import 'package:drugtime_mobile/app/router.dart';
import 'package:drugtime_mobile/features/meal_suggestion/data/meal_choice_store.dart';
import 'package:drugtime_mobile/features/meal_suggestion/domain/entities/meal_suggestion.dart';
import 'package:drugtime_mobile/features/meal_suggestion/presentation/screens/meal_suggestion_screen.dart';
import 'package:drugtime_mobile/features/meal_suggestion/presentation/state/meal_plan_scope.dart';
import 'package:drugtime_mobile/features/meal_suggestion/presentation/widgets/today_menu_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'meal_test_helpers.dart';

void main() {
  Future<List<RouteSettings>> pump(WidgetTester tester, FlowHarness h) async {
    final pushed = <RouteSettings>[];
    await tester.pumpWidget(MealPlanScope(
      plan: h.plan,
      choices: h.choices,
      child: MaterialApp(
        home:
            const Scaffold(body: SingleChildScrollView(child: TodayMenuRow())),
        onGenerateRoute: (settings) {
          pushed.add(settings);
          return MaterialPageRoute<void>(
              settings: settings, builder: (_) => const SizedBox());
        },
      ),
    ));
    await tester.pumpAndSettle();
    return pushed;
  }

  testWidgets('chưa chọn món nào: không có hàng', (tester) async {
    final h = FlowHarness();
    await h.choices.bind('patient-1');
    await pump(tester, h);
    expect(find.byKey(const ValueKey('today-menu-row')), findsNothing);
  });

  testWidgets('có món đã chọn: 3 ô; chạm Tối mở kết quả ở tab Tối',
      (tester) async {
    final h = FlowHarness();
    await h.choices.bind('patient-1');
    await h.choices.choose(
        MealType.trua,
        const MealChoice(
            name: 'Cơm gạo lứt', kcal: 480, suggestionId: 1, dishIndex: 0));
    final pushed = await pump(tester, h);
    expect(find.byKey(const ValueKey('today-menu-row')), findsOneWidget);
    expect(find.text('Thực đơn hôm nay'), findsOneWidget);
    expect(find.text('Cơm gạo lứt'), findsOneWidget);
    expect(find.text('Chưa chọn'), findsNWidgets(2));
    for (final banned in ['hợp với thuốc', 'an toàn']) {
      expect(find.textContaining(banned), findsNothing);
    }
    await tester.tap(find.byKey(const ValueKey('today-menu-toi')));
    await tester.pumpAndSettle();
    expect(pushed.single.name, AppRoutes.mealSuggestion);
    expect(
        (pushed.single.arguments! as MealRouteArgs).initialMeal, MealType.toi);
  });

  testWidgets('bỏ chọn món cuối: hàng ẩn đi', (tester) async {
    final h = FlowHarness();
    await h.choices.bind('patient-1');
    await h.choices.choose(
        MealType.sang,
        const MealChoice(
            name: 'Cháo yến mạch', kcal: 300, suggestionId: 1, dishIndex: 0));
    await pump(tester, h);
    expect(find.text('Cháo yến mạch'), findsOneWidget);
    await h.choices.unchoose(MealType.sang);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('today-menu-row')), findsNothing);
  });
}
