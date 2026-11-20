// Luồng gợi ý bữa ăn trên app: sheet "Dumi cần biết" (AC1, AC2), màn chờ (AC3, AC6, AC14b),
// kết quả (AC5, AC7, AC10, AC15), chọn món (AC8), "Gợi ý khác" (AC9, AC9b), chi tiết (AC11),
// thực đơn trong ngày (AC12), lời chào & font (AC11b).
import 'dart:async';

import 'package:drugtime_mobile/features/meal_suggestion/domain/entities/allergy_profile.dart';
import 'package:drugtime_mobile/features/meal_suggestion/domain/entities/meal_suggestion.dart';
import 'package:drugtime_mobile/features/meal_suggestion/presentation/analyzing/analyzing_view.dart';
import 'package:drugtime_mobile/features/meal_suggestion/presentation/analyzing/analysis_timeline.dart';
import 'package:drugtime_mobile/features/meal_suggestion/presentation/state/meal_plan_controller.dart';
import 'package:drugtime_mobile/features/meal_suggestion/presentation/screens/meal_detail_screens.dart';
import 'package:drugtime_mobile/features/meal_suggestion/presentation/screens/meal_suggestion_screen.dart';
import 'package:drugtime_mobile/features/meal_suggestion/presentation/widgets/meal_ui.dart';
import 'package:drugtime_mobile/shared/widgets/mascot/mascot_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'meal_test_helpers.dart';

Finder key(String k) => find.byKey(ValueKey(k));

/// Chạy đồng hồ [ms] mili giây theo bước nhỏ (route chuyển cảnh cần nhiều khung).
Future<void> advance(WidgetTester tester, int ms) async {
  for (var t = 0; t < ms; t += 50) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Vuốt chồng thẻ sang thẻ kế.
Future<void> swipeNext(WidgetTester tester) async {
  await tester.drag(key('dish-deck'), const Offset(-300, 0));
  await tester.pumpAndSettle();
}

void main() {
  group('sheet "Dumi cần biết"', () {
    testWidgets(
        'chưa bật ai_meal: chỉ bước bật; bật xong vào thẳng màn chờ (AC1)',
        (tester) async {
      final h = FlowHarness(aiMeal: false);
      await h.pump(tester);
      await tester.tap(find.text('Mở Dumi'));
      await tester.pumpAndSettle();
      expect(key('meal-setup-sheet'), findsOneWidget);
      expect(find.text('Bước 1/1 · chỉ hỏi một lần'), findsOneWidget);
      expect(h.repository.calls, isEmpty);

      await tester.tap(key('grant-ai-meal'));
      await tester.pump();
      await advance(tester, 600);
      expect(find.byType(AnalyzingView), findsOneWidget);
      await FlowHarness.settle(tester);
      expect(h.consentRepository.grants, 1);
      expect(h.repository.calls, hasLength(3));
      expect(find.byType(AnalyzingView), findsNothing);
    });

    testWidgets('đóng sheet: không gọi API, về Trang chủ (AC1)',
        (tester) async {
      final h = FlowHarness(aiMeal: false);
      await h.pump(tester);
      await tester.tap(find.text('Mở Dumi'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(200, 40)); // chạm nền mờ
      await tester.pumpAndSettle();
      expect(h.repository.calls, isEmpty);
      expect(find.byType(MealSuggestionScreen), findsNothing);
      expect(find.text('Mở Dumi'), findsOneWidget);
    });

    testWidgets(
        'thiếu consent + hạn chế: 2 bước; "Chưa biết" không gọi API (AC2)',
        (tester) async {
      final h = FlowHarness(aiMeal: false, dietaryDeclared: false);
      await h.pump(tester);
      await tester.tap(find.text('Mở Dumi'));
      await tester.pumpAndSettle();
      expect(find.text('Bước 1/2 · chỉ hỏi một lần'), findsOneWidget);
      await tester.tap(key('grant-ai-meal'));
      await tester.pumpAndSettle();
      expect(find.text('Bước 2/2 · chỉ hỏi một lần'), findsOneWidget);
      await tester.tap(find.text('Chưa biết'));
      await tester.pumpAndSettle();
      await tester.tap(key('dietary-submit'));
      await tester.pumpAndSettle();
      expect(key('dietary-unknown-note'), findsOneWidget);
      expect(h.repository.calls, isEmpty);

      // Đổi sang "Không có" thì đi tiếp vào màn chờ.
      await tester.tap(find.text('Không có'));
      await tester.pumpAndSettle();
      await tester.tap(key('dietary-submit'));
      await FlowHarness.settle(tester);
      expect(h.repository.calls, hasLength(3));
    });

    testWidgets(
        'chưa khai dị ứng: nút "Khai dị ứng" mở route, không gọi API (AC2)',
        (tester) async {
      final h = FlowHarness(allergy: const AllergyProfile.unreported());
      await h.pump(tester);
      await tester.tap(find.text('Mở Dumi'));
      await tester.pumpAndSettle();
      await tester.tap(key('declare-allergy'));
      await tester.pumpAndSettle();
      expect(h.allergyRoutes, ['allergy']);
      expect(h.repository.calls, isEmpty);
    });

    testWidgets(
        'khai dị ứng xong thì quay lại Dumi và lên thực đơn, không khảo sát lại (N7, AC12)',
        (tester) async {
      final h = FlowHarness(allergy: const AllergyProfile.unreported())
        ..declareResult = true
        ..allergyAfterDeclare = reportedAllergy;
      await h.pump(tester);
      await tester.tap(find.text('Mở Dumi'));
      await tester.pumpAndSettle();
      await tester.tap(key('declare-allergy'));
      await FlowHarness.settle(tester);
      expect(h.allergyRoutes, ['allergy']);
      expect(find.text('Tính năng này đang được phát triển.'), findsNothing);
      expect(h.repository.calls, hasLength(3));
    });
  });

  group('màn chờ', () {
    testWidgets(
        '3 lời gọi song song; chữ tối giản, không tên thuốc/dị ứng, không emoji (AC3)',
        (tester) async {
      final h = FlowHarness();
      final gates = [
        for (var i = 0; i < 3; i++) Completer<MealSuggestionResult>()
      ];
      h.repository.responses.addAll(gates);
      await h.pump(tester);
      await tester.tap(find.text('Mở Dumi'));
      await tester.pump();
      await advance(tester, 600);
      expect(h.repository.calls.map((c) => c.type),
          [MealType.sang, MealType.trua, MealType.toi]);
      expect(h.repository.calls.every((c) => c.previousSuggestionId == null),
          isTrue);
      expect(find.text('Dumi đang lên thực đơn…'), findsOneWidget);
      expect(find.text('Dựa trên thuốc, bệnh nền và dị ứng của bạn'),
          findsOneWidget);
      for (final t in MealType.values) {
        expect(key('meal-pill-${t.apiValue}'), findsOneWidget);
      }
      expect(find.byType(MascotView), findsWidgets);
      for (final banned in ['Tôm', 'Đậu phộng', 'Tăng huyết áp']) {
        expect(find.textContaining(banned), findsNothing);
      }
      final emoji =
          RegExp(r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]', unicode: true);
      for (final t in tester.widgetList<Text>(find.byType(Text))) {
        expect(emoji.hasMatch(t.data ?? ''), isFalse, reason: t.data);
      }
      expect(find.byType(Image), findsNothing); // không dùng ảnh PNG linh vật
      for (final (i, t) in MealType.values.indexed) {
        gates[i].complete(result(id: 10 + i, type: t));
      }
      await FlowHarness.settle(tester);
    });

    testWidgets(
        'về ngay lúc 11:30: chờ tối thiểu ~2,5 s; mở sẵn Trưa + "Dumi chọn" (AC5)',
        (tester) async {
      final h = FlowHarness();
      await h.pump(tester);
      await tester.tap(find.text('Mở Dumi'));
      await tester.pump();
      await advance(tester, 2000);
      expect(find.byType(AnalyzingView), findsOneWidget);
      await FlowHarness.settle(tester);
      expect(find.byType(AnalyzingView), findsNothing);
      expect(h.plan.tab, MealType.trua);
      expect(find.text('Dumi chọn'), findsWidgets);
    });

    testWidgets(
        'lỗi một phần: Tối có chấm cảnh báo; Thử lại gọi đúng Tối (AC6)',
        (tester) async {
      final h = FlowHarness();
      h.repository.responses.addAll([
        result(id: 1, type: MealType.sang),
        result(id: 2, type: MealType.trua),
        const MealSuggestionFailure(MealFailureKind.llmUnavailable),
      ]);
      await h.pump(tester);
      await h.openToResults(tester);
      expect(key('tab-error-toi'), findsOneWidget);
      await tester.tap(find.text('Tối').last);
      await tester.pumpAndSettle();
      await tester.tap(key('retry'));
      await tester.pumpAndSettle();
      expect(h.repository.calls, hasLength(4));
      expect(h.repository.calls.last.type, MealType.toi);
      expect(key('tab-error-toi'), findsNothing);
    });

    testWidgets('cả 3 lỗi: không vào kết quả; Thử lại gọi lại cả 3 (AC6)',
        (tester) async {
      final h = FlowHarness();
      h.repository.responses.addAll(
          List.filled(3, const MealSuggestionFailure(MealFailureKind.network)));
      await h.pump(tester);
      await h.openToResults(tester);
      expect(find.text('Dumi chưa lên được thực đơn'), findsOneWidget);
      await tester.tap(key('analyzing-retry'));
      await FlowHarness.settle(tester);
      expect(h.repository.calls, hasLength(6));
      expect(find.byType(AnalyzingView), findsNothing);
      expect(h.plan.hasMenu, isTrue);
    });

    testWidgets('linh vật không bị dựng lại khi icon quỹ đạo đi qua (AC11b)',
        (tester) async {
      final h = FlowHarness();
      final gate = Completer<MealSuggestionResult>();
      h.repository.responses.add(gate);
      await h.pump(tester, reduceMotion: false);
      await tester.tap(find.text('Mở Dumi'));
      await tester.pump();
      await advance(tester, 600);
      final mascot = key('analyzing-mascot');
      final first = tester.state(mascot);
      for (var i = 0; i < 360; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(identical(tester.state(mascot), first), isTrue,
            reason: 'dựng lại ở khung $i');
      }
      gate.complete(result(id: 1, type: MealType.sang));
      // Chuỗi kết thúc chạy hết, không có lỗi vẽ (NaN) rồi về kết quả.
      for (var i = 0; i < 120; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(tester.takeException(), isNull);
      expect(find.byType(AnalyzingView), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('kết quả', () {
    testWidgets(
        'vuốt thẻ / đổi tab không gọi API; Nên tránh + disclaimer (AC7, AC10)',
        (tester) async {
      final h = FlowHarness();
      await h.pump(tester);
      await h.openToResults(tester);
      expect(key('dish-name-0'), findsOneWidget);
      await swipeNext(tester);
      expect(h.plan.stateOf(MealType.trua).pageIndex, 1);
      await tester.tap(find.text('Sáng').last);
      await tester.pumpAndSettle();
      expect(h.plan.tab, MealType.sang);
      expect(h.repository.calls, hasLength(3));
      expect(key('avoid-panel'), findsOneWidget);
      expect(key('meal-disclaimer'), findsOneWidget);
      for (final banned in ['hợp với thuốc', 'an toàn với thuốc']) {
        expect(find.textContaining(banned), findsNothing);
      }
      // Giảm chuyển động: màn kết quả không còn xin khung hình (AC15).
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('mở lại cùng ngày: vào thẳng kết quả, 0 lời gọi (AC12)',
        (tester) async {
      final h = FlowHarness();
      await h.pump(tester);
      await h.openToResults(tester);
      await swipeNext(tester);
      await tester.tap(find.byType(RoundIconButton).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mở Dumi'));
      await tester.pumpAndSettle();
      expect(find.byType(AnalyzingView), findsNothing);
      expect(h.repository.calls, hasLength(3));
      expect(h.plan.stateOf(MealType.trua).pageIndex, 1);

      // Qua 00:00 giờ VN: phân tích lại.
      await tester.tap(find.byType(RoundIconButton).first);
      await tester.pumpAndSettle();
      h.clock = DateTime.utc(2026, 11, 16, 17, 30);
      await h.openToResults(tester);
      expect(h.repository.calls, hasLength(6));
    });

    testWidgets('mở từ hàng Trang chủ ở bữa Tối (AC14d)', (tester) async {
      final h = FlowHarness();
      await h.pump(tester, initialMeal: MealType.toi);
      await h.openToResults(tester);
      expect(h.plan.tab, MealType.toi);
    });

    testWidgets(
        'chọn món: nhãn, dấu tích tab, lưu, tự sang bữa kế; bấm lại bỏ chọn (AC8)',
        (tester) async {
      final h = FlowHarness();
      await h.pump(tester);
      await h.openToResults(tester);
      await swipeNext(tester);
      await tester.tap(key('choose-1'));
      await tester.pump();
      expect(key('chosen-badge'), findsOneWidget);
      expect(key('tab-chosen-trua'), findsOneWidget);
      expect(h.choices.choiceOf(MealType.trua)!.dishIndex, 1);
      expect(h.store.data.containsKey('patient-1'), isTrue);
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pumpAndSettle();
      expect(h.plan.tab, MealType.toi);

      await tester.tap(find.text('Trưa').last);
      await tester.pumpAndSettle();
      await tester.tap(key('choose-1'));
      await tester.pumpAndSettle();
      expect(h.choices.choiceOf(MealType.trua), isNull);
      expect(h.repository.calls, hasLength(3));
    });
  });

  testWidgets(
      'chọn món lần đầu: gợi ý thêm widget một lần; "Thêm" mở hộp thoại ghim',
      (tester) async {
    final h = FlowHarness();
    h.bridge.pinSupported = true;
    await h.pump(tester);
    await h.openToResults(tester);
    expect(key('widget-hint'), findsNothing);
    await tester.tap(key('choose-0'));
    await tester.pumpAndSettle();
    expect(key('widget-hint'), findsOneWidget);
    await tester.ensureVisible(key('widget-hint-add'));
    await tester.pumpAndSettle();
    await tester.tap(key('widget-hint-add'));
    await tester.pumpAndSettle();
    expect(h.bridge.pinRequests, 1);
    expect(h.bridge.pinOffered, isTrue);
    expect(key('widget-hint'), findsNothing);
    // Widget nhận đúng món vừa chọn.
    expect(h.bridge.published.last.meals[MealType.trua]!.name, 'Món A');
  });

  group('"Gợi ý khác"', () {
    testWidgets('qua màn chờ một bữa; quay về với danh sách mới (AC9)',
        (tester) async {
      final h = FlowHarness();
      await h.pump(tester);
      await h.openToResults(tester);
      final before = h.plan.stateOf(MealType.sang).result!.suggestionId;
      h.repository.responses.add(result(
          id: 99,
          type: MealType.trua,
          refreshesRemaining: 1,
          dishes: [dish('Bún cá'), dish('Phở gà')]));
      await tester.tap(key('refresh'));
      await tester.pump();
      await advance(tester, 600);
      expect(find.text('Dumi đang tìm món khác…'), findsOneWidget);
      expect(key('meal-pill-trua'), findsOneWidget);
      expect(key('meal-pill-sang'), findsNothing);
      await FlowHarness.settle(tester);
      expect(h.repository.calls.last.previousSuggestionId, isNotNull);
      expect(h.repository.calls.last.type, MealType.trua);
      expect(find.text('Bún cá'), findsOneWidget);
      expect(find.text('Còn 1 lần gợi ý khác hôm nay'), findsOneWidget);
      expect(h.plan.stateOf(MealType.sang).result!.suggestionId, before);
    });

    testWidgets('lỗi: "Giữ món cũ" quay về danh sách cũ, không trừ lượt (AC9)',
        (tester) async {
      final h = FlowHarness();
      await h.pump(tester);
      await h.openToResults(tester);
      final old = h.plan.stateOf(MealType.trua).result!.suggestionId;
      h.repository.responses
          .add(const MealSuggestionFailure(MealFailureKind.llmUnavailable));
      await tester.tap(key('refresh'));
      await FlowHarness.settle(tester);
      expect(find.text('Dumi chưa tìm được món khác'), findsOneWidget);
      await tester.tap(key('analyzing-keep'));
      await tester.pumpAndSettle();
      expect(find.byType(AnalyzingView), findsNothing);
      expect(h.plan.stateOf(MealType.trua).result!.suggestionId, old);
      expect(find.text('Còn 2 lần gợi ý khác hôm nay'), findsOneWidget);
    });

    testWidgets('bấm 4 lần liên tiếp: 1 màn chờ, 1 lời gọi (AC9b)',
        (tester) async {
      final h = FlowHarness();
      await h.pump(tester);
      await h.openToResults(tester);
      for (var i = 0; i < 4; i++) {
        await tester.tap(key('refresh'), warnIfMissed: false);
      }
      await tester.pump();
      await advance(tester, 600);
      expect(find.byType(AnalyzingView), findsOneWidget);
      await FlowHarness.settle(tester);
      expect(h.repository.calls, hasLength(4));
    });

    testWidgets('hết lượt: nút khóa, bấm mở sheet, không gọi API (AC9b)',
        (tester) async {
      final h = FlowHarness();
      h.repository.responses.addAll([
        for (final t in MealType.values)
          result(id: 20 + t.index, type: t, refreshesRemaining: 0),
      ]);
      await h.pump(tester);
      await h.openToResults(tester);
      expect(find.text('Hết lượt gợi ý hôm nay'), findsOneWidget);
      expect(key('refresh-locked'), findsOneWidget);
      await tester.tap(key('refresh'));
      await tester.pumpAndSettle();
      expect(key('refresh-limit-sheet'), findsOneWidget);
      expect(find.text('Hôm nay hết lượt gợi ý khác rồi'), findsOneWidget);
      expect(find.textContaining('0 giờ ngày mai'), findsOneWidget);
      expect(find.byType(AnalyzingView), findsNothing);
      await tester.tap(key('refresh-limit-ok'));
      await tester.pumpAndSettle();
      expect(key('refresh-limit-sheet'), findsNothing);
      expect(h.repository.calls, hasLength(3));
    });

    testWidgets('server trả 429: hiện sheet hết lượt, nút khóa (AC9b)',
        (tester) async {
      final h = FlowHarness();
      await h.pump(tester);
      await h.openToResults(tester);
      h.repository.responses
          .add(const MealSuggestionFailure(MealFailureKind.refreshLimit));
      await tester.tap(key('refresh'));
      await FlowHarness.settle(tester);
      await tester.tap(key('analyzing-keep'));
      await tester.pumpAndSettle();
      expect(key('refresh-limit-sheet'), findsOneWidget);
      await tester.tap(key('refresh-limit-ok'));
      await tester.pumpAndSettle();
      expect(key('refresh-locked'), findsOneWidget);
    });
  });

  group('chi tiết món (AC11)', () {
    testWidgets(
        'ảnh bo góc; tab Lợi ích / Nên tránh; sheet nguyên liệu; chọn từ chi tiết',
        (tester) async {
      final h = FlowHarness();
      await h.pump(tester);
      await h.openToResults(tester);
      await tester.tap(key('detail-0'));
      await tester.pumpAndSettle();
      expect(find.byType(MealDetailScreen), findsOneWidget);
      final frame = key('detail-image-frame');
      expect(find.descendant(of: frame, matching: find.byType(ClipRRect)),
          findsWidgets);
      expect(find.text('Lợi ích'), findsOneWidget);
      expect(find.text('Nên tránh'), findsOneWidget);
      expect(find.text('Cách ăn'), findsNothing);
      expect(key('benefit-label'),
          findsOneWidget); // nhãn từ hồ sơ, không phải thuốc

      await tester.tap(key('open-ingredients'));
      await tester.pumpAndSettle();
      expect(key('ingredients-sheet'), findsOneWidget);
      expect(find.text('1 người'), findsOneWidget);
      expect(find.text('Dùng ít'), findsOneWidget);
      expect(find.text('Nguyên liệu chính'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsNothing);
      expect(find.byIcon(Icons.remove), findsNothing);
      Navigator.of(tester.element(key('ingredients-sheet'))).pop();
      await tester.pumpAndSettle();

      await tester.tap(key('detail-choose'));
      await tester.pumpAndSettle();
      expect(find.byType(MealDetailScreen), findsNothing);
      expect(h.choices.choiceOf(MealType.trua)!.dishIndex, 0);
    });

    testWidgets('món không có nguyên liệu: "Chưa có công thức…", không có nút',
        (tester) async {
      final h = FlowHarness();
      h.repository.responses.addAll([
        result(id: 1, type: MealType.sang),
        result(
            id: 2,
            type: MealType.trua,
            dishes: [dish('Canh chua', ingredients: const [])]),
        result(id: 3, type: MealType.toi),
      ]);
      await h.pump(tester);
      await h.openToResults(tester);
      await tester.tap(key('detail-0'));
      await tester.pumpAndSettle();
      expect(find.text('Chưa có công thức và định lượng cho món này'),
          findsOneWidget);
      expect(key('open-ingredients'), findsNothing);
    });
  });

  group('lời chào & font (AC11b)', () {
    testWidgets('đổi tab: phần chữ cố định không nhảy dọc, không dựng lại',
        (tester) async {
      final h = FlowHarness();
      await h.pump(tester, reduceMotion: false);
      await tester.tap(find.text('Mở Dumi'));
      for (var i = 0; i < 160; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      final fixed = key('greeting-fixed');
      expect(fixed, findsOneWidget);
      final y0 = tester.getTopLeft(fixed).dy;
      final element = tester.element(fixed);
      await tester.tap(find.text('Tối').last);
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.getTopLeft(fixed).dy, closeTo(y0, .5));
        expect(identical(tester.element(fixed), element), isTrue);
      }
      expect(find.text('Gợi ý cho bữa tối'), findsWidgets);
      final style = DefaultTextStyle.of(tester.element(fixed)).style;
      expect(style.fontFamily, kMealFont);
      await tester.pumpWidget(const SizedBox());
    });
  });

  // adhoc-20261120-meal-image-loading: chỉ hiện kết quả khi ảnh của bữa sắp hiển thị đã sẵn sàng.
  group('chờ ảnh món', () {
    const pending501 =
        MealDishImage(imageId: 501, status: MealImageStatus.pending);
    const ready501 = MealDishImage(
        imageId: 501,
        status: MealImageStatus.ready,
        url: '/meal-images/501',
        attribution: attribution);

    void lunchWithImage(FlowHarness h) => h.repository.responses.addAll([
          result(id: 1, type: MealType.sang),
          result(
              id: 2,
              type: MealType.trua,
              dishes: [dish('Canh chua', image: pending501), dish('Món B')]),
          result(id: 3, type: MealType.toi),
        ]);

    test('AnalysisTimeline: có kết quả nhưng ảnh chưa xong → preparingImages (AC3)',
        () {
      const statuses = {
        MealType.sang: MealTabStatus.data,
        MealType.trua: MealTabStatus.data,
        MealType.toi: MealTabStatus.data,
      };
      expect(
          AnalysisTimeline.next(
              statuses: statuses,
              minShowPassed: true,
              reduceMotion: true,
              imagesReady: false),
          AnalysisStep.preparingImages);
      expect(
          AnalysisTimeline.next(
              statuses: statuses,
              minShowPassed: false,
              reduceMotion: true,
              imagesReady: false),
          AnalysisStep.wait);
      expect(
          AnalysisTimeline.next(
              statuses: statuses, minShowPassed: true, reduceMotion: true),
          AnalysisStep.done);
    });

    testWidgets(
        'giữ màn chờ "Đang chuẩn bị ảnh món…" tới khi ảnh tải xong, rồi mở kết quả có ảnh (AC3, AC4)',
        (tester) async {
      final h = FlowHarness(repository: FakeMealRepository());
      lunchWithImage(h);
      final gate = Completer<void>();
      h.repository.bytesGates[501] = gate;
      await h.pump(tester);
      await tester.tap(find.text('Mở Dumi'));
      await tester.pump();
      await advance(tester, 3000);
      expect(find.byType(AnalyzingView), findsOneWidget);
      expect(find.text('Đang chuẩn bị ảnh món…'), findsOneWidget);

      h.repository.imageAnswer = (_) => const [ready501];
      await advance(tester, 2100); // một nhịp hỏi trạng thái
      expect(h.repository.bytesCalls, contains(501));
      expect(find.byType(AnalyzingView), findsOneWidget); // nội dung ảnh chưa về

      gate.complete();
      await FlowHarness.settle(tester);
      expect(find.byType(AnalyzingView), findsNothing);
      expect(h.plan.tab, MealType.trua);
      expect(find.byKey(const ValueKey('meal-image-501')), findsWidgets);
    });

    testWidgets(
        'quá 20 giây vẫn chưa có ảnh: vẫn mở kết quả; hết hạn hỏi thì ảnh mặc định (AC5)',
        (tester) async {
      final h = FlowHarness(repository: FakeMealRepository());
      lunchWithImage(h);
      await h.pump(tester);
      await tester.tap(find.text('Mở Dumi'));
      await tester.pump();
      await advance(tester, 3000);
      expect(find.text('Đang chuẩn bị ảnh món…'), findsOneWidget);
      for (var i = 0; i < 18; i++) {
        h.clock = h.clock.add(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
      }
      expect(find.byType(AnalyzingView), findsOneWidget); // chưa đủ 20 giây
      for (var i = 0; i < 4; i++) {
        h.clock = h.clock.add(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
      }
      // Không dùng pumpAndSettle: ảnh còn pending có vòng xoay chạy liên tục.
      await advance(tester, 1500);
      expect(find.byType(AnalyzingView), findsNothing);
      // Hết cửa sổ hỏi (30 giây): ảnh coi như không có, không xoay mãi.
      for (var i = 0; i < 12; i++) {
        h.clock = h.clock.add(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
      }
      final d = h.plan.stateOf(MealType.trua).dishes.first;
      expect(h.plan.imageOf(d)!.status, MealImageStatus.failed);
      expect(h.plan.isPolling, isFalse);
    });

    testWidgets(
        'ảnh món đầu đã xong thì mở kết quả dù món khác còn pending; ảnh món đó tự hiện sau (AC3, AC4, AC10)',
        (tester) async {
      const pending502 =
          MealDishImage(imageId: 502, status: MealImageStatus.pending);
      final h = FlowHarness(repository: FakeMealRepository());
      h.repository.responses.addAll([
        result(id: 1, type: MealType.sang),
        result(id: 2, type: MealType.trua, dishes: [
          dish('Canh chua', image: ready501),
          dish('Món B', image: pending502),
        ]),
        result(id: 3, type: MealType.toi),
      ]);
      await h.pump(tester);
      await tester.tap(find.text('Mở Dumi'));
      await tester.pump();
      await advance(tester, 3000);
      // Không dùng pumpAndSettle: ảnh món B còn pending có vòng xoay chạy liên tục.
      await advance(tester, 1500);
      expect(find.byType(AnalyzingView), findsNothing);
      expect(h.plan.tab, MealType.trua);
      expect(find.byKey(const ValueKey('meal-image-501')), findsWidgets);
      final dishB = h.plan.stateOf(MealType.trua).dishes[1];
      expect(h.plan.imageOf(dishB)!.status, MealImageStatus.pending);

      // AC10: màn đã mở, ảnh món B thành ready thì tự tải và hiện, không mở lại màn.
      h.repository.imageAnswer = (_) => const [
            MealDishImage(
                imageId: 502,
                status: MealImageStatus.ready,
                url: '/meal-images/502',
                attribution: attribution)
          ];
      await advance(tester, 2100);
      await tester.pump();
      expect(h.repository.bytesCalls, contains(502));
      expect(h.plan.cachedImageBytes(h.plan.imageOf(dishB)!), isNotNull);
      expect(find.byKey(const ValueKey('meal-image-502')), findsWidgets);
      await FlowHarness.settle(tester); // hết ảnh pending: dừng polling và hoạt ảnh
    });

    testWidgets('bữa không có ảnh: mở kết quả ngay sau thời gian tối thiểu (AC6)',
        (tester) async {
      final h = FlowHarness();
      await h.pump(tester);
      await tester.tap(find.text('Mở Dumi'));
      await tester.pump();
      await advance(tester, 2000);
      expect(find.text('Đang chuẩn bị ảnh món…'), findsNothing);
      await FlowHarness.settle(tester);
      expect(find.byType(AnalyzingView), findsNothing);
      expect(h.repository.imageCalls, isEmpty);
    });

    testWidgets('"Gợi ý khác" cũng chờ ảnh của món mới (AC3)', (tester) async {
      final h = FlowHarness();
      await h.pump(tester);
      await h.openToResults(tester);
      const pending777 =
          MealDishImage(imageId: 777, status: MealImageStatus.pending);
      h.repository.responses.add(result(
          id: 99,
          type: MealType.trua,
          refreshesRemaining: 1,
          dishes: [dish('Bún cá', image: pending777), dish('Phở gà')]));
      await tester.tap(key('refresh'));
      await tester.pump();
      await advance(tester, 3000);
      expect(find.text('Đang chuẩn bị ảnh món…'), findsOneWidget);
      h.repository.imageAnswer = (_) => const [
            MealDishImage(
                imageId: 777,
                status: MealImageStatus.ready,
                url: '/meal-images/777',
                attribution: attribution)
          ];
      await advance(tester, 2100);
      await FlowHarness.settle(tester);
      expect(find.byType(AnalyzingView), findsNothing);
      expect(find.text('Bún cá'), findsOneWidget);
      expect(h.repository.bytesCalls, contains(777));
    });
  });
}
