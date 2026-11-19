// MealPlanController: thực đơn cả ngày ở mức phiên (AC3, AC5, AC6, AC9, AC9b, AC12, AC16) và hỏi lại ảnh.
import 'dart:async';

import 'package:drugtime_mobile/features/meal_suggestion/domain/entities/allergy_profile.dart';
import 'package:drugtime_mobile/features/meal_suggestion/domain/entities/meal_suggestion.dart';
import 'package:drugtime_mobile/features/meal_suggestion/presentation/state/dietary_session.dart';
import 'package:drugtime_mobile/features/meal_suggestion/presentation/state/meal_plan_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'meal_test_helpers.dart';

void main() {
  late FakeMealRepository repo;
  late DateTime clock;
  late FakeAllergyRepository allergyRepo;

  Future<MealPlanController> make(
      {AllergyProfile allergy = reportedAllergy}) async {
    final session = DietarySession.instance
      ..clear()
      ..restrictions = const DietaryDeclaration.none()
      ..preferences = const ['Ít cay'];
    allergyRepo = FakeAllergyRepository(allergy);
    final c = MealPlanController(
      repository: repo,
      allergyRepository: allergyRepo,
      session: session,
      now: () => clock,
    )..bind('p1');
    await c.loadAllergy();
    return c;
  }

  setUp(() {
    repo = FakeMealRepository();
    clock = DateTime.utc(2026, 11, 16, 4, 30); // 11:30 giờ VN
  });

  test('chưa khai dị ứng: không gọi API', () async {
    final c = await make(allergy: const AllergyProfile.unreported());
    await c.analyze();
    expect(c.canRequest, isFalse);
    expect(repo.calls, isEmpty);
  });

  test('analyze gửi 3 bữa song song, không previous_suggestion_id (AC3)',
      () async {
    final c = await make();
    final gates = [
      for (var i = 0; i < 3; i++) Completer<MealSuggestionResult>()
    ];
    repo.responses.addAll(gates);
    final done = c.analyze();
    await Future<void>.delayed(Duration.zero);
    // Cả 3 lời gọi đã đi trước khi bữa nào về.
    expect(repo.calls.map((x) => x.type),
        [MealType.sang, MealType.trua, MealType.toi]);
    expect(repo.calls.every((x) => x.previousSuggestionId == null), isTrue);
    expect(repo.calls.first.allergies.toJson(), {
      'none': false,
      'items': ['Tôm', 'Đậu phộng']
    });
    expect(c.isAnalyzing, isTrue);
    for (final (i, t) in MealType.values.indexed) {
      gates[i].complete(result(id: i + 1, type: t));
    }
    await done;
    expect(c.hasMenu, isTrue);
    expect(c.tab, MealType.trua); // 11:30 → Trưa (AC5)
    expect(c.stateOf(MealType.toi).result!.suggestionId, 3);
  });

  test('lỗi một phần: chỉ bữa lỗi ở error; retryMeal gọi đúng bữa (AC6)',
      () async {
    final c = await make();
    repo.responses.addAll([
      result(type: MealType.sang),
      result(type: MealType.trua),
      const MealSuggestionFailure(MealFailureKind.llmUnavailable),
    ]);
    await c.analyze();
    expect(c.stateOf(MealType.toi).status, MealTabStatus.error);
    expect(c.stateOf(MealType.sang).status, MealTabStatus.data);
    await c.retryMeal(MealType.toi);
    expect(repo.calls.last.type, MealType.toi);
    expect(repo.calls, hasLength(4));
    expect(c.stateOf(MealType.toi).status, MealTabStatus.data);
  });

  test('cùng ngày cùng tài khoản: bind lại không xóa, không gọi API (AC12)',
      () async {
    final c = await make();
    await c.analyze();
    c.setPage(MealType.trua, 2);
    clock = clock.add(const Duration(hours: 5));
    c.bind('p1');
    expect(c.hasMenu, isTrue);
    expect(c.stateOf(MealType.trua).pageIndex, 2);
    expect(repo.calls, hasLength(3));
  });

  test('qua 00:00 giờ VN hoặc đổi tài khoản: thực đơn bị xóa (AC12)', () async {
    final c = await make();
    await c.analyze();
    clock = DateTime.utc(2026, 11, 16, 17, 1); // 00:01 ngày 17 giờ VN
    c.bind('p1');
    expect(c.hasMenu, isFalse);
    await c.analyze();
    c.bind('p2');
    expect(c.hasMenu, isFalse);
    expect(c.allergy, isNull);
  });

  test('khai lại hạn chế ăn uống khác trước: thực đơn bị xóa (AC12)', () async {
    final c = await make();
    await c.analyze();
    c.saveDietary(
        restrictions: const DietaryDeclaration.none(), preferences: ['Ít cay']);
    expect(c.hasMenu, isTrue); // không đổi gì
    c.saveDietary(
        restrictions: const DietaryDeclaration.items(['Ăn chay']),
        preferences: const []);
    expect(c.hasMenu, isFalse);
  });

  test('dị ứng trong hồ sơ đổi: thực đơn bị xóa (AC12)', () async {
    final c = await make();
    await c.analyze();
    allergyRepo.profile = const AllergyProfile(
        status: AllergyStatus.reported, customItems: ['Sữa']);
    await c.loadAllergy();
    expect(c.hasMenu, isFalse);
  });

  test('reset bỏ response về muộn (AC16)', () async {
    final c = await make();
    final slow = Completer<MealSuggestionResult>();
    repo.responses.add(slow);
    final done = c.analyze();
    c.reset();
    slow.complete(result(type: MealType.sang));
    await done;
    expect(c.stateOf(MealType.sang).status, MealTabStatus.idle);
  });

  test('"Gợi ý khác" chỉ bữa được chỉ định, kèm previous_suggestion_id (AC9)',
      () async {
    final c = await make();
    await c.analyze();
    repo.responses.add(result(id: 3052, refreshesRemaining: 1));
    final ok = await c.refresh(MealType.trua);
    expect(ok, isTrue);
    expect(repo.calls.last.type, MealType.trua);
    expect(repo.calls.last.previousSuggestionId, 3051);
    expect(c.stateOf(MealType.trua).result!.suggestionId, 3052);
    expect(c.stateOf(MealType.sang).result!.suggestionId, 3051);
    expect(c.refreshesRemaining, 1);
  });

  test('"Gợi ý khác" lỗi: giữ danh sách cũ, không trừ lượt (AC9)', () async {
    final c = await make();
    await c.analyze();
    repo.responses
        .add(const MealSuggestionFailure(MealFailureKind.llmUnavailable));
    final ok = await c.refresh(MealType.trua);
    expect(ok, isFalse);
    expect(c.lastRefreshFailure!.kind, MealFailureKind.llmUnavailable);
    expect(c.stateOf(MealType.trua).result!.suggestionId, 3051);
    expect(c.refreshesRemaining, 2);
  });

  test('429 hết lượt: lượt về 0, nút khóa (AC9b)', () async {
    final c = await make();
    await c.analyze();
    repo.responses
        .add(const MealSuggestionFailure(MealFailureKind.refreshLimit));
    expect(await c.refresh(MealType.trua), isFalse);
    expect(c.refreshesRemaining, 0);
    expect(c.refreshLocked, isTrue);
  });

  test('previous_suggestion_not_found: gợi ý lại từ đầu cho bữa đó', () async {
    final c = await make();
    await c.analyze();
    repo.responses.addAll([
      const MealSuggestionFailure(MealFailureKind.previousNotFound),
      result(id: 9),
    ]);
    expect(await c.refresh(MealType.trua), isTrue);
    expect(repo.calls.skip(3).map((x) => x.previousSuggestionId), [3051, null]);
    expect(c.stateOf(MealType.trua).result!.suggestionId, 9);
  });

  testWidgets('hỏi lại ảnh pending mỗi 3 giây, dừng khi hết pending',
      (tester) async {
    final c = await make();
    const pending = MealDishImage(imageId: 42, status: MealImageStatus.pending);
    repo.responses.add(
        result(type: MealType.sang, dishes: [dish('Món A', image: pending)]));
    await c.analyze();
    expect(c.isPolling, isTrue);
    await tester.pump(const Duration(seconds: 3));
    expect(repo.imageCalls, [
      [42]
    ]);
    repo.imageAnswer = (_) => const [
          MealDishImage(
              imageId: 42,
              status: MealImageStatus.ready,
              url: '/meal-images/42',
              attribution: attribution)
        ];
    await tester.pump(const Duration(seconds: 3));
    final d = c.stateOf(MealType.sang).dishes.first;
    expect(c.imageOf(d)!.isReady, isTrue);
    await tester.pump(const Duration(seconds: 3));
    expect(c.isPolling, isFalse);
    c.dispose();
  });

  testWidgets('hỏi ảnh tối đa 30 giây rồi dừng', (tester) async {
    final c = await make();
    const pending = MealDishImage(imageId: 7, status: MealImageStatus.pending);
    repo.responses.add(
        result(type: MealType.sang, dishes: [dish('Món A', image: pending)]));
    await c.analyze();
    for (var i = 0; i < 12; i++) {
      clock = clock.add(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 3));
    }
    expect(c.isPolling, isFalse);
    expect(repo.imageCalls.length, lessThanOrEqualTo(10));
    // Hết hạn vẫn pending: ảnh coi như không có → ảnh giữ chỗ, không xoay mãi.
    final d = c.stateOf(MealType.sang).dishes.first;
    expect(c.imageOf(d)!.status, MealImageStatus.failed);
    c.dispose();
  });
}
