import 'dart:typed_data';

// Kho và controller món đã chọn (AC8, AC13, AC14c).
import 'package:drugtime_mobile/features/meal_suggestion/data/meal_choice_store.dart';
import 'package:drugtime_mobile/features/meal_suggestion/data/meal_widget_bridge.dart';
import 'package:drugtime_mobile/features/meal_suggestion/domain/entities/meal_suggestion.dart';
import 'package:drugtime_mobile/features/meal_suggestion/presentation/state/meal_choice_controller.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class RecordingBridge implements MealWidgetBridge {
  final published = <TodayMenuSnapshot>[];

  @override
  Future<void> publish(TodayMenuSnapshot snapshot) async =>
      published.add(snapshot);

  final thumbnails = <MealType, Uint8List?>{};
  bool pinSupported = false;
  bool pinOffered = false;
  int pinRequests = 0;

  @override
  Future<void> saveThumbnail(MealType meal, Uint8List? png) async =>
      thumbnails[meal] = png;

  @override
  Future<bool> shouldOfferPin() async => pinSupported && !pinOffered;

  @override
  Future<void> markPinOffered() async => pinOffered = true;

  @override
  Future<void> requestPin() async => pinRequests++;
}

const pho = MealChoice(
    name: 'Phở gà', kcal: 420, suggestionId: 11, dishIndex: 1, imageId: 5);
const com =
    MealChoice(name: 'Cơm gạo lứt', kcal: 480, suggestionId: 12, dishIndex: 0);

void main() {
  late MemoryMealChoiceStore store;
  late RecordingBridge bridge;
  late DateTime clock;

  MealChoiceController make() =>
      MealChoiceController(store: store, bridge: bridge, now: () => clock);

  setUp(() {
    store = MemoryMealChoiceStore();
    bridge = RecordingBridge();
    clock = DateTime.utc(2026, 11, 16, 4); // 11:00 VN
  });

  test('chọn, thay món, bỏ chọn; lưu theo tài khoản (AC8, AC13)', () async {
    final c = make();
    await c.bind('u1');
    await c.choose(MealType.trua, pho);
    expect(c.isChosen(MealType.trua, 11, 1), isTrue);
    await c.choose(MealType.trua, com);
    expect(c.isChosen(MealType.trua, 11, 1), isFalse);
    expect(c.choiceOf(MealType.trua)!.name, 'Cơm gạo lứt');

    // "Khởi động lại app": controller mới, cùng kho.
    final again = make();
    await again.bind('u1');
    expect(again.choiceOf(MealType.trua)!.name, 'Cơm gạo lứt');
    final other = make();
    await other.bind('u2');
    expect(other.hasAny, isFalse);

    await again.unchoose(MealType.trua);
    expect(store.data.containsKey('u1'), isFalse);
  });

  test('qua ngày: kho đọc ra rỗng và bị xóa (AC13)', () async {
    final c = make();
    await c.bind('u1');
    await c.choose(MealType.sang, pho);
    clock = DateTime.utc(2026, 11, 16, 17, 5); // 00:05 hôm sau giờ VN
    final next = make();
    await next.bind('u1');
    expect(next.hasAny, isFalse);
    expect(store.data, isEmpty);
    expect(c.choices, isEmpty); // controller đang chạy cũng tự bỏ
  });

  test('đăng xuất: xóa kho, widget về signed_out (AC13, AC14c)', () async {
    final c = make();
    await c.bind('u1');
    await c.choose(MealType.toi, pho);
    await c.signOut();
    expect(store.data, isEmpty);
    expect(bridge.published.last.state, TodayMenuState.signedOut);
  });

  test('widget nhận đúng trường; thu hồi consent thì về empty (AC14c)',
      () async {
    final c = make();
    await c.bind('u1');
    await c.choose(MealType.trua, pho);
    final snap = bridge.published.last;
    expect(snap.state, TodayMenuState.ok);
    expect(snap.day, '2026-11-16');
    final item = snap.meals[MealType.trua]!;
    expect((item.name, item.kcal, item.imageId), ('Phở gà', 420, 5));
    await c.clear();
    expect(bridge.published.last.state, TodayMenuState.empty);
    expect(bridge.published.last.meals, isEmpty);
    expect(store.data, isEmpty);
  });

  test('kho bảo mật lỗi: đọc trả null, không ném', () async {
    FlutterSecureStorage.setMockInitialValues({'meal_choices_u1': '{hỏng'});
    final s = SecureMealChoiceStore();
    expect(await s.read('u1'), isNull);
    await s.write('u1',
        const MealDayChoices(day: '2026-11-16', meals: {MealType.sang: pho}));
    expect((await s.read('u1'))!.meals[MealType.sang]!.name, 'Phở gà');
  });
}
