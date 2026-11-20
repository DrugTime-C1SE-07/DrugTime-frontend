// Thành phần giao diện gợi ý bữa ăn: Nên tránh (AC10), ảnh món, icon, chip một hàng (AC11b),
// chuỗi kết thúc 1 lần bùng sáng (AC14b), logic thời gian màn chờ (AC4, AC5, AC6, AC15).
import 'dart:io';

import 'package:drugtime_mobile/core/utils/app_assets.dart';
import 'package:drugtime_mobile/features/meal_suggestion/domain/entities/meal_suggestion.dart';
import 'package:drugtime_mobile/features/meal_suggestion/presentation/analyzing/analysis_timeline.dart';
import 'package:drugtime_mobile/features/meal_suggestion/presentation/analyzing/supernova.dart';
import 'package:drugtime_mobile/features/meal_suggestion/presentation/state/meal_plan_controller.dart';
import 'package:drugtime_mobile/features/meal_suggestion/presentation/widgets/meal_ui.dart';
import 'package:drugtime_mobile/features/meal_suggestion/presentation/widgets/meal_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'meal_test_helpers.dart';

void main() {
  group('MealFoodCheckView (AC10)', () {
    Future<void> show(WidgetTester tester, MealFoodCheck check) =>
        tester.pumpWidget(
            MaterialApp(home: Scaffold(body: MealFoodCheckView(check))));

    testWidgets('co_tuong_tac: thực phẩm kèm lý do, không nói "an toàn"',
        (tester) async {
      await show(
          tester,
          const MealFoodCheck(status: FoodCheckStatus.coTuongTac, warnings: [
            MealFoodWarning(
                foodToAvoid: 'Chuối',
                reason: 'Tăng kali máu',
                severityLevel: 2,
                source: 'DT'),
          ]));
      expect(find.text('Chuối'), findsOneWidget);
      expect(find.text('Tăng kali máu'), findsOneWidget);
      expect(find.textContaining('an toàn'), findsNothing);
    });

    testWidgets('da_kiem_tra_khong_thay / khong_du_du_lieu', (tester) async {
      await show(
          tester,
          const MealFoodCheck(
              status: FoodCheckStatus.daKiemTraKhongThay, warnings: []));
      expect(find.text('Chưa thấy tương tác trong dữ liệu hiện có'),
          findsOneWidget);
      await show(
          tester,
          const MealFoodCheck(
              status: FoodCheckStatus.khongDuDuLieu, warnings: []));
      expect(find.text('Chưa xác minh được, hãy hỏi dược sĩ'), findsOneWidget);
    });
  });

  group('MealImageView', () {
    final repo = FakeMealRepository();

    testWidgets('pending → giữ chỗ; failed/null → ảnh mặc định có icon SVG',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: MealImageView(
                  image: const MealDishImage(
                      imageId: 1, status: MealImageStatus.pending),
                  loadBytes: repo.imageBytes))));
      expect(find.byKey(const ValueKey('meal-image-pending')), findsOneWidget);
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: MealImageView(image: null, loadBytes: repo.imageBytes))));
      expect(find.byKey(const ValueKey('meal-image-default')), findsOneWidget);
      expect(find.byType(FoodIcon), findsOneWidget);
    });

    testWidgets('ready → ảnh qua repository + "Ảnh minh họa" + ghi nguồn',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: MealImageView(
                  image: const MealDishImage(
                      imageId: 42,
                      status: MealImageStatus.ready,
                      url: '/meal-images/42',
                      attribution: attribution),
                  loadBytes: repo.imageBytes))));
      await tester.pumpAndSettle();
      expect(repo.bytesCalls, contains(42));
      expect(find.text('Ảnh minh họa'), findsOneWidget);
      expect(find.text('Ảnh: Nguyễn Văn A / Pixabay'), findsOneWidget);
      expect(find.textContaining('Pexels'), findsNothing);
    });

    testWidgets(
        'có nội dung tải sẵn: hiện ảnh ngay khung hình đầu, không giữ chỗ, không tải lại (AC4)',
        (tester) async {
      // adhoc-20261120-meal-image-loading
      final bytes = await repo.imageBytes(const MealDishImage(
          imageId: 0, status: MealImageStatus.ready, url: '/meal-images/0'));
      repo.bytesCalls.clear();
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: MealImageView(
                  image: const MealDishImage(
                      imageId: 43,
                      status: MealImageStatus.ready,
                      url: '/meal-images/43',
                      attribution: attribution),
                  loadBytes: repo.imageBytes,
                  cachedBytes: (_) => bytes))));
      expect(find.byKey(const ValueKey('meal-image-pending')), findsNothing);
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('Ảnh: Nguyễn Văn A / Pixabay'), findsOneWidget);
      expect(repo.bytesCalls, isEmpty);
    });
  });

  group('icon & chip (AC11b, AC14b)', () {
    test('mọi icon nguyên liệu khai báo đều có file SVG', () {
      for (final name in AppAssets.foodIconNames) {
        expect(File(AppAssets.foodIcon(name)).existsSync(), isTrue,
            reason: name);
      }
    });

    test('tagStyle khớp từ khóa; không khớp → icon chung', () {
      expect(tagStyle('Ít muối').icon, 'salt');
      expect(tagStyle('Ít đường').icon, 'sugar');
      expect(tagStyle('~480 kcal').icon, 'flame');
      expect(tagStyle('Nhiều rau').icon, 'leafy');
      expect(tagStyle('Đạm nạc').icon, 'chicken');
      expect(tagStyle('Ít dầu mỡ').icon, 'oil');
      expect(tagStyle('Món Huế').icon, 'generic');
      for (final t in ['Ít muối', 'x', '~1 kcal']) {
        expect(AppAssets.foodIconNames, contains(tagStyle(t).icon));
      }
    });

    test('ingredientAsset theo từ khóa, không khớp dùng icon nhóm', () {
      MealIngredient ing(String n, {bool main = true}) => MealIngredient(
          name: n, amount: '1', isMain: main, useSparingly: false);
      expect(ingredientAsset(ing('Gạo lứt')), 'rice');
      expect(ingredientAsset(ing('Ức gà')), 'chicken');
      expect(ingredientAsset(ing('Cá hồi')), 'fish');
      expect(ingredientAsset(ing('Muối', main: false)), 'salt');
      expect(ingredientAsset(ing('Quế')), 'salad');
      expect(ingredientAsset(ing('Quế', main: false)), 'generic');
    });

    testWidgets('chip có icon và luôn nằm trên một hàng, kể cả chữ ×1,3',
        (tester) async {
      tester.view.physicalSize = const Size(360 * 3, 800 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
              size: Size(360, 800), textScaler: TextScaler.linear(1.3)),
          child: Scaffold(
            body: Padding(
              padding: EdgeInsets.all(24),
              child: TagRow(['Ít muối', 'Ít đường', 'Nhiều rau', '~480 kcal']),
            ),
          ),
        ),
      ));
      final chips = find.byType(TagChip);
      expect(chips, findsNWidgets(4));
      expect(find.descendant(of: chips, matching: find.byType(FoodIcon)),
          findsNWidgets(4));
      final ys = {
        for (final e in chips.evaluate())
          tester.getCenter(find.byWidget(e.widget)).dy.round()
      };
      expect(ys, hasLength(1), reason: 'chip lệch hàng: $ys');
      expect(tester.takeException(), isNull);
    });
  });

  group('chuỗi kết thúc (AC14b)', () {
    test('lớp chớp sáng có đúng 1 đỉnh, tối đa 0,85, tổng ≤ 1,8 s', () {
      var peaks = 0;
      var prev = 0.0, rising = false, max = 0.0;
      for (var i = 0; i <= 1000; i++) {
        final a = flashAlpha(i / 1000);
        if (a > prev) {
          rising = true;
        } else if (a < prev && rising) {
          peaks++;
          rising = false;
        }
        prev = a;
        if (a > max) max = a;
      }
      expect(peaks, 1);
      expect(max, lessThanOrEqualTo(.85));
      expect(AnalysisTimeline.finale.inMilliseconds, lessThanOrEqualTo(1800));
      expect(finaleMs, AnalysisTimeline.finale.inMilliseconds);
    });
  });

  group('AnalysisTimeline (AC4, AC5, AC6, AC15)', () {
    Map<MealType, MealTabStatus> st(
            MealTabStatus a, MealTabStatus b, MealTabStatus c) =>
        {MealType.sang: a, MealType.trua: b, MealType.toi: c};
    const d = MealTabStatus.data, e = MealTabStatus.error;
    const l = MealTabStatus.loading;

    test('chờ khi còn bữa chạy hoặc chưa đủ 2,5 s', () {
      expect(
          AnalysisTimeline.next(
              statuses: st(d, l, d), minShowPassed: true, reduceMotion: false),
          AnalysisStep.wait);
      expect(
          AnalysisTimeline.next(
              statuses: st(d, d, d), minShowPassed: false, reduceMotion: false),
          AnalysisStep.wait);
      expect(AnalysisTimeline.minShow, const Duration(milliseconds: 2500));
    });

    test('đủ → siêu tân tinh; giảm chuyển động → sang ngay; cả 3 lỗi → lỗi',
        () {
      expect(
          AnalysisTimeline.next(
              statuses: st(d, e, d), minShowPassed: true, reduceMotion: false),
          AnalysisStep.finale);
      expect(
          AnalysisTimeline.next(
              statuses: st(d, d, d), minShowPassed: true, reduceMotion: true),
          AnalysisStep.done);
      expect(
          AnalysisTimeline.next(
              statuses: st(e, e, e), minShowPassed: true, reduceMotion: false),
          AnalysisStep.failed);
    });

    test('bữa mở sẵn: bữa sắp tới; lỗi thì bữa thành công gần nhất (AC6)', () {
      expect(AnalysisTimeline.revealMeal(st(d, d, d), MealType.trua),
          MealType.trua);
      expect(AnalysisTimeline.revealMeal(st(d, e, d), MealType.trua),
          MealType.toi);
      expect(AnalysisTimeline.revealMeal(st(d, e, e), MealType.toi),
          MealType.sang);
    });
  });
}
