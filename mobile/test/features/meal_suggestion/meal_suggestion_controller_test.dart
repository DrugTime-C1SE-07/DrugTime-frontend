// MealSuggestionController (task 5.11): AC13, AC14, AC18, AC19, AC27 và hỏi lại ảnh (AC7).
import 'dart:async';

import 'package:drugtime_mobile/features/meal_suggestion/domain/entities/allergy_profile.dart';
import 'package:drugtime_mobile/features/meal_suggestion/domain/entities/meal_suggestion.dart';
import 'package:drugtime_mobile/features/meal_suggestion/presentation/state/dietary_session.dart';
import 'package:drugtime_mobile/features/meal_suggestion/presentation/state/meal_suggestion_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'meal_test_helpers.dart';

void main() {
  late FakeMealRepository repo;
  late DateTime clock;

  MealSuggestionController make({AllergyProfile allergy = reportedAllergy}) {
    final session = DietarySession.instance
      ..clear()
      ..restrictions = const DietaryDeclaration.none()
      ..preferences = const ['Ít cay'];
    return MealSuggestionController(
      repository: repo,
      allergyRepository: FakeAllergyRepository(allergy),
      patientId: 'p1',
      session: session,
      initialTab: MealType.trua,
      now: () => clock,
    );
  }

  setUp(() {
    repo = FakeMealRepository();
    clock = DateTime.utc(2026, 11, 16, 4);
  });

  test('chưa khai dị ứng: không gọi API (AC3)', () async {
    final c = make(allergy: const AllergyProfile.unreported());
    await c.loadAllergy();
    await c.load(MealType.trua);
    expect(c.canRequest, isFalse);
    expect(repo.calls, isEmpty);
  });

  test('gửi dị ứng từ hồ sơ + hạn chế/sở thích của phiên (AC4, AC5)', () async {
    final c = make();
    await c.loadAllergy();
    await c.load(MealType.trua);
    final call = repo.calls.single;
    expect(call.allergies.toJson(), {'none': false, 'items': ['Tôm', 'Đậu phộng']});
    expect(call.restrictions.none, isTrue);
    expect(call.preferences, ['Ít cay']);
    expect(call.previousSuggestionId, isNull);
    expect(c.current.status, MealTabStatus.data);
    expect(c.refreshesRemaining, 2);
  });

  test('chuyển tab không gọi lại tab đã có; response muộn không ghi đè (AC19)', () async {
    final c = make();
    await c.loadAllergy();
    final slow = Completer<MealSuggestionResult>();
    repo.responses.add(slow);
    final first = c.load(MealType.trua);
    c.selectTab(MealType.toi); // tải tab Tối
    await Future<void>.delayed(Duration.zero);
    expect(repo.calls.map((x) => x.type), [MealType.trua, MealType.toi]);

    // Thử lại Trưa trong lúc lần cũ còn treo: lần cũ trả về sau không được ghi đè.
    repo.responses.add(result(id: 2));
    await c.load(MealType.trua);
    slow.complete(result(id: 1));
    await first;
    expect(c.stateOf(MealType.trua).result!.suggestionId, 2);

    c.selectTab(MealType.trua);
    c.selectTab(MealType.toi);
    expect(repo.calls, hasLength(3)); // không gọi thêm khi đã có kết quả
  });

  test('"Đổi món" xoay vòng, có hoàn tác, không gọi API (AC13)', () async {
    final c = make();
    await c.loadAllergy();
    await c.load(MealType.trua);
    final names = <String>[];
    for (var i = 0; i < 4; i++) {
      c.rotate();
      names.add(c.current.mainDish!.name);
    }
    expect(names, ['Món B', 'Món C', 'Món D', 'Món A']);
    expect(c.current.previousMainIndex, 3);
    c.promote(c.current.previousMainIndex!);
    expect(c.current.mainDish!.name, 'Món D');
    expect(repo.calls, hasLength(1));
  });

  test('"Gợi ý khác" gửi previous_suggestion_id và cập nhật lượt (AC14, AC27)', () async {
    final c = make();
    await c.loadAllergy();
    await c.load(MealType.trua);
    repo.responses.add(result(id: 3052, refreshesRemaining: 1));
    await c.refresh();
    expect(repo.calls.last.previousSuggestionId, 3051);
    expect(c.current.result!.suggestionId, 3052);
    expect(c.refreshesRemaining, 1);
    expect(c.current.mainIndex, 0);
  });

  test('hết lượt: giữ gợi ý, tắt nút (AC27)', () async {
    final c = make();
    await c.loadAllergy();
    await c.load(MealType.trua);
    repo.responses.add(const MealSuggestionFailure(MealFailureKind.refreshLimit));
    await c.refresh();
    expect(c.refreshesRemaining, 0);
    expect(c.canRefresh, isFalse);
    expect(c.current.result!.suggestionId, 3051);
  });

  test('previous_suggestion_not_found: gợi ý lại từ đầu, không kèm gợi ý cũ (AC16)',
      () async {
    final c = make();
    await c.loadAllergy();
    await c.load(MealType.trua);
    repo.responses
      ..add(const MealSuggestionFailure(MealFailureKind.previousNotFound))
      ..add(result(id: 9));
    await c.refresh();
    expect(repo.calls.map((x) => x.previousSuggestionId), [null, 3051, null]);
    expect(c.current.result!.suggestionId, 9);
  });

  test('lỗi gợi ý lại khác: giữ gợi ý đang có, không tự retry (AC18)', () async {
    final c = make();
    await c.loadAllergy();
    await c.load(MealType.trua);
    repo.responses.add(const MealSuggestionFailure(MealFailureKind.llmUnavailable));
    await c.refresh();
    expect(c.current.status, MealTabStatus.data);
    expect(c.current.refreshFailure!.kind, MealFailureKind.llmUnavailable);
    expect(repo.calls, hasLength(2));
  });

  test('lỗi lần đầu: trạng thái error, chỉ gọi lại khi người dùng bấm (AC18)', () async {
    final c = make();
    await c.loadAllergy();
    repo.responses.add(const MealSuggestionFailure(MealFailureKind.llmDisabled));
    await c.load(MealType.trua);
    expect(c.current.status, MealTabStatus.error);
    expect(c.current.failure!.canRetry, isFalse);
    expect(repo.calls, hasLength(1));
  });

  testWidgets('hỏi lại ảnh pending mỗi 3 giây, dừng khi hết pending (AC7)', (tester) async {
    final c = make();
    await c.loadAllergy();
    const pending = MealDishImage(imageId: 42, status: MealImageStatus.pending);
    repo.responses.add(result(dishes: [dish('Món A', image: pending), dish('Món B')]));
    await c.load(MealType.trua);
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
    expect(c.imageOf(c.current.mainDish!)!.isReady, isTrue);
    await tester.pump(const Duration(seconds: 3));
    expect(c.isPolling, isFalse);
    expect(repo.imageCalls, hasLength(2));
    c.dispose();
  });

  testWidgets('hỏi ảnh tối đa 30 giây rồi dừng; dispose hủy timer (AC7)', (tester) async {
    final c = make();
    await c.loadAllergy();
    const pending = MealDishImage(imageId: 7, status: MealImageStatus.pending);
    repo.responses.add(result(dishes: [dish('Món A', image: pending)]));
    await c.load(MealType.trua);
    for (var i = 0; i < 12; i++) {
      clock = clock.add(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 3));
    }
    expect(c.isPolling, isFalse);
    expect(repo.imageCalls.length, lessThanOrEqualTo(10));
    expect(c.imageOf(c.current.mainDish!)!.status, MealImageStatus.pending);
    c.dispose();
  });
}
