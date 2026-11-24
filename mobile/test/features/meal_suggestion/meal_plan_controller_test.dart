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
      {AllergyProfile allergy = reportedAllergy,
      Duration pollInterval = const Duration(seconds: 3)}) async {
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
      pollInterval: pollInterval,
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

  test('reset xóa luôn lastRefreshFailure (task 6.03, AC6)', () async {
    final c = await make();
    await c.analyze();
    repo.responses
        .add(const MealSuggestionFailure(MealFailureKind.consentRevoked));
    expect(await c.refresh(MealType.trua), isFalse);
    expect(c.lastRefreshFailure?.kind, MealFailureKind.consentRevoked);
    c.reset();
    expect(c.lastRefreshFailure, isNull);
    expect(c.hasMenu, isFalse);
    c.dispose();
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

  // ---- adhoc-20261120-meal-image-loading: tải sẵn ảnh, chờ ảnh có giới hạn ----

  MealDishImage ready(int id) => MealDishImage(
      imageId: id,
      status: MealImageStatus.ready,
      url: '/meal-images/$id',
      attribution: attribution);

  test('mặc định: hỏi ảnh mỗi 2 giây, chờ ảnh 20 giây, tải song song 3', () {
    final c = MealPlanController(
        repository: repo,
        allergyRepository: FakeAllergyRepository(reportedAllergy));
    expect(c.pollInterval, const Duration(seconds: 2));
    expect(c.imageWaitLimit, const Duration(seconds: 20));
    expect(c.imagePrefetchConcurrency, 3);
    c.dispose();
  });

  test('tải sẵn ảnh ready, tối đa 3 lượt cùng lúc (AC7)', () async {
    final c = await make();
    final ids = [for (var i = 1; i <= 7; i++) i];
    for (final id in ids) {
      repo.bytesGates[id] = Completer<void>();
    }
    repo.responses.add(result(
        type: MealType.sang,
        dishes: [for (final id in ids) dish('Món $id', image: ready(id))]));
    await c.load(MealType.sang);
    await Future<void>.delayed(Duration.zero);
    expect(repo.bytesInFlight, 3);
    expect(c.leadImageSettled(MealType.sang), isFalse);
    for (final id in ids) {
      repo.bytesGates[id]!.complete();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
    }
    expect(repo.maxBytesInFlight, 3);
    expect(repo.bytesCalls.toSet(), ids.toSet());
    expect(c.leadImageSettled(MealType.sang), isTrue);
    final first = c.stateOf(MealType.sang).dishes.first;
    expect(c.cachedImageBytes(c.imageOf(first)!), isNotNull);
    c.dispose();
  });

  test(
      'leadImageSettled: pending → chưa xong; failed hoặc không có ảnh → xong (AC4, AC6)',
      () async {
    final c = await make();
    const pending = MealDishImage(imageId: 5, status: MealImageStatus.pending);
    const failed = MealDishImage(imageId: 6, status: MealImageStatus.failed);
    repo.responses.addAll([
      result(
          type: MealType.sang, dishes: [dish('A', image: pending), dish('B')]),
      result(
          type: MealType.trua, dishes: [dish('C', image: failed), dish('D')]),
    ]);
    await c.load(MealType.sang);
    await c.load(MealType.trua);
    expect(c.leadImageSettled(MealType.sang), isFalse);
    expect(c.leadImageSettled(MealType.trua), isTrue);
    // Bữa chưa có kết quả: không có món nào để chờ.
    expect(c.leadImageSettled(MealType.toi), isTrue);
    c.dispose();
  });

  test(
      'leadImageSettled: món đầu ready + đã tải là xong dù món khác còn pending (AC4)',
      () async {
    final c = await make();
    const pending = MealDishImage(imageId: 21, status: MealImageStatus.pending);
    repo.responses.add(result(
        type: MealType.sang,
        dishes: [dish('A', image: ready(20)), dish('B', image: pending)]));
    await c.load(MealType.sang);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(c.leadImageSettled(MealType.sang), isTrue);
    c.dispose();
  });

  test('leadImageSettled theo pageIndex; bữa không có món là xong (AC4, AC6)',
      () async {
    final c = await make();
    const pending = MealDishImage(imageId: 31, status: MealImageStatus.pending);
    repo.responses.addAll([
      result(
          type: MealType.sang,
          dishes: [dish('A', image: ready(30)), dish('B', image: pending)]),
      result(type: MealType.trua, dishes: const []),
    ]);
    await c.load(MealType.sang);
    await c.load(MealType.trua);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(c.leadImageSettled(MealType.sang), isTrue);
    c.setPage(MealType.sang, 1);
    expect(c.leadImageSettled(MealType.sang), isFalse);
    expect(c.leadImageSettled(MealType.trua), isTrue);
    c.dispose();
  });

  testWidgets(
      'ảnh món đầu được tải trước các ảnh khác đang chờ trong hàng (AC7)',
      (tester) async {
    final c = await make(pollInterval: const Duration(seconds: 2));
    const pending = MealDishImage(imageId: 11, status: MealImageStatus.pending);
    for (final id in [12, 13, 14]) {
      repo.bytesGates[id] = Completer<void>();
    }
    repo.responses.add(result(type: MealType.sang, dishes: [
      dish('A', image: pending),
      for (final id in [12, 13, 14, 15]) dish('Món $id', image: ready(id)),
    ]));
    await c.load(MealType.sang);
    await tester.pump();
    expect(repo.bytesCalls, [12, 13, 14]); // 15 đang chờ trong hàng
    repo.imageAnswer = (_) => [ready(11)];
    await tester.pump(const Duration(seconds: 2)); // món đầu thành ready
    repo.bytesGates[12]!.complete();
    await tester.pump();
    await tester.pump();
    // Chỗ trống đầu tiên dành cho món đầu (11), không phải ảnh đã xếp hàng trước (15).
    expect(repo.bytesCalls.sublist(0, 4), [12, 13, 14, 11]);
    for (final id in [13, 14]) {
      repo.bytesGates[id]!.complete();
    }
    await tester.pump();
    await tester.pump();
    expect(repo.bytesCalls, [12, 13, 14, 11, 15]);
    expect(c.leadImageSettled(MealType.sang), isTrue);
    c.dispose();
  });

  test('imageWaitExpired sau 20 giây kể từ lúc có gợi ý (AC5)', () async {
    final c = await make();
    expect(c.imageWaitExpired(MealType.sang),
        isTrue); // chưa có kết quả: không chờ
    const pending = MealDishImage(imageId: 5, status: MealImageStatus.pending);
    repo.responses
        .add(result(type: MealType.sang, dishes: [dish('A', image: pending)]));
    await c.load(MealType.sang);
    expect(c.imageWaitExpired(MealType.sang), isFalse);
    expect(c.imageWaitRemaining(MealType.sang), const Duration(seconds: 20));
    clock = clock.add(const Duration(seconds: 19));
    expect(c.imageWaitExpired(MealType.sang), isFalse);
    expect(c.imageWaitRemaining(MealType.sang), const Duration(seconds: 1));
    clock = clock.add(const Duration(seconds: 1));
    expect(c.imageWaitExpired(MealType.sang), isTrue);
    expect(c.imageWaitRemaining(MealType.sang), Duration.zero);
    c.dispose();
  });

  test('tải nội dung ảnh lỗi: ảnh thành failed, bữa coi như xong (AC8)',
      () async {
    final c = await make();
    repo.failBytes.add(9);
    repo.responses
        .add(result(type: MealType.sang, dishes: [dish('A', image: ready(9))]));
    await c.load(MealType.sang);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    final d = c.stateOf(MealType.sang).dishes.first;
    expect(c.imageOf(d)!.status, MealImageStatus.failed);
    expect(c.leadImageSettled(MealType.sang), isTrue);
    c.dispose();
  });

  testWidgets(
      'hỏi trạng thái lỗi tạm thời: thử lại nhịp sau, ready thì tải sẵn (AC8)',
      (tester) async {
    final c = await make(pollInterval: const Duration(seconds: 2));
    const pending = MealDishImage(imageId: 42, status: MealImageStatus.pending);
    repo.responses
        .add(result(type: MealType.sang, dishes: [dish('A', image: pending)]));
    await c.load(MealType.sang);
    var calls = 0;
    repo.imageAnswer = (_) {
      calls++;
      if (calls == 1) {
        throw const MealSuggestionFailure(MealFailureKind.network);
      }
      return [ready(42)];
    };
    await tester.pump(const Duration(seconds: 2)); // lỗi tạm thời
    expect(c.leadImageSettled(MealType.sang), isFalse);
    await tester.pump(const Duration(seconds: 2)); // ready → tải sẵn
    await tester.pump();
    expect(repo.bytesCalls, [42]);
    expect(c.leadImageSettled(MealType.sang), isTrue);
    c.dispose();
  });

  test('xóa thực đơn: bỏ nội dung đã tải và kết quả tải về muộn', () async {
    final c = await make();
    repo.bytesGates[3] = Completer<void>();
    repo.responses
        .add(result(type: MealType.sang, dishes: [dish('A', image: ready(3))]));
    await c.load(MealType.sang);
    c.reset();
    repo.bytesGates[3]!.complete();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(c.cachedImageBytes(ready(3)), isNull);
    expect(c.imagesFetching, 0);
    c.dispose();
  });
}
