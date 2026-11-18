// Widget "Thực đơn hôm nay": dữ liệu đẩy qua home_widget (AC14c) và link mở app (AC14d).

import 'package:drugtime_mobile/features/meal_suggestion/data/meal_widget_bridge.dart';
import 'package:drugtime_mobile/features/meal_suggestion/domain/entities/meal_suggestion.dart';
import 'package:drugtime_mobile/features/meal_suggestion/presentation/screens/meal_suggestion_screen.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('home_widget');
  late Map<String, Object?> saved;
  late List<String> calls;
  bool pinSupported = true;

  setUp(() {
    saved = {};
    calls = [];
    FlutterSecureStorage.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      final args = (call.arguments as Map?)?.cast<String, Object?>();
      switch (call.method) {
        case 'saveWidgetData':
          saved[args!['id']! as String] = args['data'];
          return true;
        case 'getWidgetData':
          return saved[args!['id']];
        case 'updateWidget':
          return true;
        case 'isRequestPinWidgetSupported':
          return pinSupported;
        case 'requestPinWidget':
          return null;
      }
      return null;
    });
  });

  tearDown(() => TestDefaultBinaryMessengerBinding
      .instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, null));

  test(
      'publish: chỉ khóa bữa/tên/kcal/ngày/trạng thái, rồi vẽ lại widget (AC14c)',
      () async {
    await HomeWidgetMealBridge().publish(const TodayMenuSnapshot(
      state: TodayMenuState.ok,
      day: '2026-11-18',
      meals: {
        MealType.trua:
            TodayMenuItem(name: 'Cơm gạo lứt', kcal: 480, imageId: 7),
      },
    ));
    expect(saved['menu_state'], 'ok');
    expect(saved['menu_day'], '2026-11-18');
    expect(saved['meal_trua_name'], 'Cơm gạo lứt');
    expect(saved['meal_trua_kcal'], '~480 kcal');
    expect(saved['meal_sang_name'], isNull);
    final allowed =
        RegExp(r'^(menu_state|menu_day|meal_(sang|trua|toi)_(name|kcal|img))$');
    for (final k in saved.keys) {
      expect(allowed.hasMatch(k), isTrue, reason: 'khóa lạ: $k');
    }
    expect(calls.last, 'updateWidget');
  });

  test('đăng xuất: trạng thái signed_out, không còn tên món', () async {
    final bridge = HomeWidgetMealBridge();
    await bridge.publish(const TodayMenuSnapshot(
        state: TodayMenuState.ok,
        day: '2026-11-18',
        meals: {MealType.toi: TodayMenuItem(name: 'Phở gà', kcal: 400)}));
    await bridge.publish(const TodayMenuSnapshot.signedOut());
    expect(saved['menu_state'], 'signed_out');
    expect(saved['meal_toi_name'], isNull);
    expect(saved['meal_toi_kcal'], isNull);
  });

  test('xóa ảnh nhỏ: khóa ảnh về null', () async {
    await HomeWidgetMealBridge().saveThumbnail(MealType.sang, null);
    expect(saved.containsKey('meal_sang_img'), isTrue);
    expect(saved['meal_sang_img'], isNull);
  });

  test('gợi ý ghim widget chỉ một lần, khi launcher hỗ trợ', () async {
    final bridge = HomeWidgetMealBridge();
    expect(await bridge.shouldOfferPin(), isTrue);
    await bridge.markPinOffered();
    expect(await bridge.shouldOfferPin(), isFalse);
    pinSupported = false;
    FlutterSecureStorage.setMockInitialValues({});
    expect(await HomeWidgetMealBridge().shouldOfferPin(), isFalse);
    pinSupported = true;
  });

  test('link widget: drugtime://meal?meal=toi → Tối; link khác bị bỏ (AC14d)',
      () {
    expect(MealWidgetLink.parse(Uri.parse('drugtime://meal?meal=toi'))!.meal,
        MealType.toi);
    expect(MealWidgetLink.parse(Uri.parse('drugtime://meal'))!.meal, isNull);
    expect(MealWidgetLink.parse(Uri.parse('drugtime://meal?meal=xyz'))!.meal,
        isNull);
    expect(MealWidgetLink.parse(Uri.parse('https://x.vn/meal')), isNull);
    expect(MealWidgetLink.parse(null), isNull);
  });

  test('ảnh nhỏ cho widget: PNG 128 px; dữ liệu không phải ảnh → null', () {
    // PNG 1×1 hợp lệ.
    final png = Uint8List.fromList(const [
      0x89,
      0x50,
      0x4E,
      0x47,
      0x0D,
      0x0A,
      0x1A,
      0x0A,
      0x00,
      0x00,
      0x00,
      0x0D,
      0x49,
      0x48,
      0x44,
      0x52,
      0x00,
      0x00,
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
      0x01,
      0x08,
      0x06,
      0x00,
      0x00,
      0x00,
      0x1F,
      0x15,
      0xC4,
      0x89,
      0x00,
      0x00,
      0x00,
      0x0D,
      0x49,
      0x44,
      0x41,
      0x54,
      0x78,
      0x9C,
      0x63,
      0xF8,
      0xCF,
      0xC0,
      0xF0,
      0x1F,
      0x00,
      0x05,
      0x00,
      0x01,
      0xFF,
      0x89,
      0x99,
      0x3D,
      0x1D,
      0x00,
      0x00,
      0x00,
      0x00,
      0x49,
      0x45,
      0x4E,
      0x44,
      0xAE,
      0x42,
      0x60,
      0x82,
    ]);
    final out = mealThumbnailPng(png)!;
    expect(out.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
    // Chiều rộng trong header IHDR (byte 16–19) = 128.
    expect(ByteData.sublistView(out, 16, 20).getUint32(0), 128);
    expect(mealThumbnailPng(Uint8List.fromList([1, 2, 3])), isNull);
  });
}
