// Màn gợi ý bữa ăn (task 5.11): AC2, AC3, AC5, AC6, AC7, AC8, AC10, AC11, AC12, AC13, AC18, AC27.
import 'package:drugtime_mobile/features/meal_suggestion/domain/entities/allergy_profile.dart';
import 'package:drugtime_mobile/features/meal_suggestion/domain/entities/meal_suggestion.dart';
import 'package:drugtime_mobile/features/meal_suggestion/presentation/screens/meal_detail_screens.dart';
import 'package:drugtime_mobile/features/meal_suggestion/presentation/state/meal_suggestion_controller.dart';
import 'package:drugtime_mobile/features/meal_suggestion/presentation/widgets/meal_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'meal_test_helpers.dart';

void main() {
  setUp(() {
    // Màn cao để mọi phần nằm trong viewport.
  });

  Future<void> tall(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
  }

  testWidgets('chưa bật ai_meal: hiện nút bật, không gọi API; bật xong thì gọi (AC2)',
      (tester) async {
    await tall(tester);
    final h = ScreenHarness(aiMeal: false);
    await h.pump(tester);
    expect(find.widgetWithText(FilledButton, 'Bật gợi ý bữa ăn'), findsOneWidget);
    expect(h.repository.calls, isEmpty);

    await tester.tap(find.byKey(const ValueKey('grant-ai-meal')));
    await tester.pumpAndSettle();
    expect(h.consentRepository.grants, 1);
    expect(h.repository.calls, hasLength(1));
    expect(find.byKey(const ValueKey('main-card')), findsOneWidget);
  });

  testWidgets('server trả 403 consent_revoked: tải lại consent, không hiện gợi ý (AC2)',
      (tester) async {
    await tall(tester);
    final h = ScreenHarness();
    h.repository.responses
        .add(const MealSuggestionFailure(MealFailureKind.consentRevoked));
    await h.pump(tester);
    expect(h.consentRepository.fetches, greaterThanOrEqualTo(2));
    expect(find.byKey(const ValueKey('main-card')), findsNothing);
    expect(find.text('Thử lại'), findsNothing);
  });

  testWidgets('chưa khai dị ứng: nút "Khai dị ứng" mở route, không gọi API (AC3)',
      (tester) async {
    await tall(tester);
    final h = ScreenHarness(allergy: const AllergyProfile.unreported());
    await h.pump(tester);
    expect(find.text('Bạn chưa khai dị ứng'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('declare-allergy')));
    expect(h.allergyRoutes, ['allergy']);
    expect(h.repository.calls, isEmpty);
  });

  testWidgets('chưa khai hạn chế: sheet bắt buộc; "Chưa biết" không gọi API (AC5)',
      (tester) async {
    await tall(tester);
    final h = ScreenHarness(dietaryDeclared: false);
    await h.pump(tester);
    expect(h.repository.calls, isEmpty);

    await tester.tap(find.byKey(const ValueKey('declare-dietary')));
    await tester.pumpAndSettle();
    final submit = find.byKey(const ValueKey('dietary-submit'));
    expect(tester.widget<FilledButton>(submit).onPressed, isNull); // chưa chọn gì

    await tester.tap(find.text('Chưa biết'));
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(h.repository.calls, isEmpty);

    await tester.tap(find.byKey(const ValueKey('declare-dietary')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Có'));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(submit).onPressed, isNull); // "Có" mà chưa có mục
    await tester.enterText(find.byKey(const ValueKey('restriction-input')), 'Ăn chay');
    await tester.tap(find.byKey(const ValueKey('restriction-add')));
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(h.repository.calls.single.restrictions.toJson(),
        {'none': false, 'items': ['Ăn chay']});
  });

  testWidgets('màn chính: thẻ Dumi chọn, Món khác, Xem tất cả, không có "Chọn món này" (AC6)',
      (tester) async {
    await tall(tester);
    final h = ScreenHarness();
    await h.pump(tester);
    expect(find.text('Trưa nay ăn gì, bạn?'), findsOneWidget);
    expect(find.text('Dumi chọn'), findsOneWidget);
    expect(find.byKey(const ValueKey('main-dish-name')), findsOneWidget);
    expect(find.text('Món A'), findsWidgets);
    expect(find.text('~480 kcal/phần'), findsOneWidget);
    expect(find.text('Đổi món'), findsOneWidget);
    expect(find.text('Chi tiết'), findsOneWidget);
    expect(find.text('Chọn món này'), findsNothing);
    expect(find.text('Món khác cho bữa trưa'), findsOneWidget);
    expect(find.text('Gợi ý dựa trên danh sách thuốc của bạn'), findsOneWidget);
    expect(find.textContaining('an toàn'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('see-all')));
    await tester.pumpAndSettle();
    expect(find.byType(MealListScreen), findsOneWidget);
    for (final name in ['Món A', 'Món B', 'Món C', 'Món D']) {
      expect(find.text(name), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('meal-disclaimer')), findsOneWidget);
  });

  testWidgets('"Đổi món" xoay vòng, món cũ có nút hoàn tác, không gọi API (AC13)',
      (tester) async {
    await tall(tester);
    final h = ScreenHarness();
    await h.pump(tester);
    String mainName() => tester
        .widget<Text>(find.byKey(const ValueKey('main-dish-name')))
        .data!;
    expect(mainName(), 'Món A');
    await tester.tap(find.byKey(const ValueKey('rotate')));
    await tester.pump();
    expect(mainName(), 'Món B');
    expect(find.byKey(const ValueKey('undo-previous-main')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('undo-previous-main')));
    await tester.pump();
    expect(mainName(), 'Món A');
    expect(h.repository.calls, hasLength(1));
  });

  testWidgets('disclaimer nguyên văn ở màn chính, chi tiết, nguyên liệu (AC10, AC12)',
      (tester) async {
    await tall(tester);
    final h = ScreenHarness();
    await h.pump(tester);
    expect(find.text(disclaimer), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('detail')));
    await tester.pumpAndSettle();
    expect(find.byType(MealDetailScreen), findsOneWidget);
    expect(find.text(disclaimer), findsOneWidget);
    expect(find.text('Lợi ích'), findsOneWidget);
    expect(find.text('Nên tránh'), findsOneWidget);
    expect(find.text('Vì sao'), findsNothing);
    expect(find.text('Cách ăn'), findsNothing);
    expect(find.text('Chọn món này'), findsNothing);
    // Nhãn bệnh nền ở lợi ích đầu; lợi ích chung không có nhãn.
    expect(find.byKey(const ValueKey('benefit-label')), findsOneWidget);
    expect(find.text('Tăng huyết áp'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('open-ingredients')));
    await tester.pumpAndSettle();
    expect(find.byType(MealIngredientsScreen), findsOneWidget);
    expect(find.text('Nguyên liệu chính'), findsOneWidget);
    expect(find.text('Gia vị'), findsOneWidget);
    expect(find.text('2 món'), findsOneWidget);
    expect(find.text('1 món'), findsOneWidget);
    expect(find.text('Dùng ít'), findsOneWidget);
    expect(find.text('1 người'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsNothing); // không có nút −/+ (Q8)
    expect(find.byIcon(Icons.remove), findsNothing);
    expect(find.text('60 g'), findsOneWidget);
    expect(find.text(disclaimer), findsOneWidget);
  });

  testWidgets('lỗi llm_disabled không có "Thử lại"; lỗi khác có, chỉ gọi khi bấm (AC18)',
      (tester) async {
    await tall(tester);
    final h = ScreenHarness();
    h.repository.responses
        .add(const MealSuggestionFailure(MealFailureKind.llmDisabled));
    await h.pump(tester);
    expect(find.text('Tính năng gợi ý bữa ăn đang tạm ngưng.'), findsOneWidget);
    expect(find.byKey(const ValueKey('retry')), findsNothing);

    await tester.pumpWidget(const SizedBox()); // tháo màn cũ để dựng State mới
    final h2 = ScreenHarness();
    h2.repository.responses
        .add(const MealSuggestionFailure(MealFailureKind.llmUnavailable));
    await h2.pump(tester);
    expect(find.byKey(const ValueKey('retry')), findsOneWidget);
    expect(h2.repository.calls, hasLength(1));
    await tester.tap(find.byKey(const ValueKey('retry')));
    await tester.pumpAndSettle();
    expect(h2.repository.calls, hasLength(2));
    expect(find.byKey(const ValueKey('main-card')), findsOneWidget);
  });

  testWidgets('lượt gợi ý khác: còn 1 → câu nhắc; hết → nút tắt (AC27)', (tester) async {
    await tall(tester);
    final h = ScreenHarness();
    h.repository.responses.add(result(refreshesRemaining: 1));
    await h.pump(tester);
    expect(find.text('Còn 1 lần gợi ý khác hôm nay'), findsOneWidget);

    h.repository.responses.add(result(id: 3052, refreshesRemaining: 0));
    await tester.tap(find.byKey(const ValueKey('refresh')));
    await tester.pumpAndSettle();
    expect(h.repository.calls.last.previousSuggestionId, 3051);
    expect(find.text('Hôm nay bạn đã dùng hết lượt gợi ý khác'), findsOneWidget);
    final button = tester.widget<OutlinedButton>(find.byKey(const ValueKey('refresh')));
    expect(button.onPressed, isNull);
    expect(find.byKey(const ValueKey('main-card')), findsOneWidget);
  });

  group('MealFoodCheckView (AC11)', () {
    Future<void> show(WidgetTester tester, MealFoodCheck check) => tester.pumpWidget(
        MaterialApp(home: Scaffold(body: MealFoodCheckView(check))));

    testWidgets('co_tuong_tac: 2 thực phẩm kèm lý do', (tester) async {
      await show(
          tester,
          const MealFoodCheck(status: FoodCheckStatus.coTuongTac, warnings: [
            MealFoodWarning(
                foodToAvoid: 'Chuối', reason: 'Tăng kali máu', severityLevel: 2, source: 'DT'),
            MealFoodWarning(
                foodToAvoid: 'Rượu', reason: 'Nhiễm toan', severityLevel: 3, source: 'DT'),
          ]));
      expect(find.text('Chuối'), findsOneWidget);
      expect(find.text('Tăng kali máu'), findsOneWidget);
      expect(find.text('Rượu'), findsOneWidget);
      expect(find.textContaining('an toàn'), findsNothing);
    });

    testWidgets('da_kiem_tra_khong_thay / khong_du_du_lieu', (tester) async {
      await show(tester,
          const MealFoodCheck(status: FoodCheckStatus.daKiemTraKhongThay, warnings: []));
      expect(find.text('Chưa thấy tương tác trong dữ liệu hiện có'), findsOneWidget);
      expect(find.textContaining('an toàn'), findsNothing);
      await show(tester,
          const MealFoodCheck(status: FoodCheckStatus.khongDuDuLieu, warnings: []));
      expect(find.text('Chưa xác minh được, hãy hỏi dược sĩ'), findsOneWidget);
      expect(find.textContaining('an toàn'), findsNothing);
    });
  });

  group('MealImageView (AC6, AC7, AC8)', () {
    final repo = FakeMealRepository();

    Future<void> show(WidgetTester tester, MealDishImage? image) async {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: MealImageView(image: image, loadBytes: repo.imageBytes))));
      await tester.pumpAndSettle();
    }

    testWidgets('pending → ảnh giữ chỗ', (tester) async {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: MealImageView(
                  image: const MealDishImage(imageId: 1, status: MealImageStatus.pending),
                  loadBytes: repo.imageBytes))));
      expect(find.byKey(const ValueKey('meal-image-pending')), findsOneWidget);
      expect(find.text('Ảnh minh họa'), findsNothing);
    });

    testWidgets('failed hoặc null → ảnh mặc định', (tester) async {
      await show(tester, const MealDishImage(imageId: 1, status: MealImageStatus.failed));
      expect(find.byKey(const ValueKey('meal-image-default')), findsOneWidget);
      await show(tester, null);
      expect(find.byKey(const ValueKey('meal-image-default')), findsOneWidget);
    });

    testWidgets('ready → ảnh qua repository + "Ảnh minh họa" + ghi nguồn', (tester) async {
      await show(
          tester,
          const MealDishImage(
              imageId: 42,
              status: MealImageStatus.ready,
              url: '/meal-images/42',
              attribution: attribution));
      expect(repo.bytesCalls, contains(42));
      expect(find.text('Ảnh minh họa'), findsOneWidget);
      expect(find.text('Ảnh: Nguyễn Văn A / Pexels'), findsOneWidget);
    });
  });

  test('ingredientIcon theo từ khóa, không khớp dùng icon nhóm', () {
    const rice = MealIngredient(name: 'Gạo lứt', amount: '60 g', isMain: true, useSparingly: false);
    const odd1 = MealIngredient(name: 'Quế', amount: '1', isMain: true, useSparingly: false);
    const odd2 = MealIngredient(name: 'Quế', amount: '1', isMain: false, useSparingly: false);
    expect(ingredientIcon(rice), isNot(ingredientIcon(odd1)));
    expect(ingredientIcon(odd1), isNot(ingredientIcon(odd2)));
  });

  testWidgets('state không lưu bền: controller mới không có gợi ý cũ (AC19)', (tester) async {
    await tall(tester);
    final h = ScreenHarness();
    await h.pump(tester);
    final first = h.controller!;
    expect(first.current.status, MealTabStatus.data);
    await tester.pumpWidget(const SizedBox());
    final h2 = ScreenHarness(repository: h.repository);
    h2.repository.responses.add(result(id: 77));
    await h2.pump(tester);
    expect(h2.controller, isNot(same(first)));
    expect(h2.controller!.current.result!.suggestionId, 77);
  });
}
