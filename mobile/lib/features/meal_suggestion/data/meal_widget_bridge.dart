import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:home_widget/home_widget.dart';

import '../domain/entities/meal_suggestion.dart';

enum TodayMenuState { ok, empty, signedOut }

/// Một dòng trên widget màn hình chính: chỉ tên món, kcal, ảnh (AC14c).
@immutable
class TodayMenuItem {
  const TodayMenuItem({required this.name, required this.kcal, this.imageId});

  final String name;
  final int kcal;
  final int? imageId;
}

/// Dữ liệu đẩy cho widget "Thực đơn hôm nay". Không chứa thuốc, bệnh, dị ứng.
@immutable
class TodayMenuSnapshot {
  const TodayMenuSnapshot({
    required this.state,
    required this.day,
    this.meals = const {},
  });

  const TodayMenuSnapshot.signedOut()
      : state = TodayMenuState.signedOut,
        day = '',
        meals = const {};

  final TodayMenuState state;
  final String day;
  final Map<MealType, TodayMenuItem> meals;
}

/// Cầu nối tới widget Android; bản Noop cho test và nền tảng không có widget.
abstract class MealWidgetBridge {
  Future<void> publish(TodayMenuSnapshot snapshot);

  /// Ảnh nhỏ (PNG) của món đã chọn cho [meal]; `null` thì xóa ảnh.
  Future<void> saveThumbnail(MealType meal, Uint8List? png);

  /// Có nên gợi ý "Thêm widget ra màn hình chính" (launcher hỗ trợ ghim, chưa gợi ý lần nào).
  Future<bool> shouldOfferPin();

  /// Đánh dấu đã gợi ý (bấm "Thêm" hoặc đóng gợi ý): không hiện lại.
  Future<void> markPinOffered();

  /// Mở hộp thoại ghim widget của Android.
  Future<void> requestPin();
}

class NoopMealWidgetBridge implements MealWidgetBridge {
  const NoopMealWidgetBridge();

  @override
  Future<void> publish(TodayMenuSnapshot snapshot) async {}

  @override
  Future<void> saveThumbnail(MealType meal, Uint8List? png) async {}

  @override
  Future<bool> shouldOfferPin() async => false;

  @override
  Future<void> markPinOffered() async {}

  @override
  Future<void> requestPin() async {}
}

/// Khóa dữ liệu dùng chung với `MealMenuWidgetProvider.kt`.
abstract final class MealWidgetKeys {
  static const state = 'menu_state';
  static const day = 'menu_day';
  static String name(MealType m) => 'meal_${m.apiValue}_name';
  static String kcal(MealType m) => 'meal_${m.apiValue}_kcal';
  static String image(MealType m) => 'meal_${m.apiValue}_img';

  static String stateValue(TodayMenuState s) => switch (s) {
        TodayMenuState.ok => 'ok',
        TodayMenuState.empty => 'empty',
        TodayMenuState.signedOut => 'signed_out',
      };
}

/// Ghi dữ liệu cho widget qua `home_widget` (SharedPreferences của app) rồi yêu cầu vẽ lại.
///
/// Chỉ ghi tên món, kcal, ảnh nhỏ (AC14c); dữ liệu này không mã hóa nên không có thuốc/bệnh.
class HomeWidgetMealBridge implements MealWidgetBridge {
  HomeWidgetMealBridge([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  static const provider = 'vn.drugtime.drugtime_mobile.MealMenuWidgetProvider';
  static const _pinKey = 'meal_widget_pin_offered';

  final FlutterSecureStorage _storage;

  @override
  Future<void> publish(TodayMenuSnapshot snapshot) async {
    try {
      await HomeWidget.saveWidgetData<String>(
          MealWidgetKeys.state, MealWidgetKeys.stateValue(snapshot.state));
      await HomeWidget.saveWidgetData<String>(MealWidgetKeys.day, snapshot.day);
      for (final m in MealType.values) {
        final item = snapshot.meals[m];
        await HomeWidget.saveWidgetData<String>(
            MealWidgetKeys.name(m), item?.name);
        await HomeWidget.saveWidgetData<String>(
            MealWidgetKeys.kcal(m), item == null ? null : '~${item.kcal} kcal');
        if (item == null) {
          await HomeWidget.saveWidgetData<String>(
              MealWidgetKeys.image(m), null);
        }
      }
      await HomeWidget.updateWidget(qualifiedAndroidName: provider);
    } catch (e) {
      // Widget là phần phụ: lỗi kênh nền tảng không được làm hỏng việc chọn món.
      debugPrint('MealWidgetBridge.publish: $e');
    }
  }

  @override
  Future<void> saveThumbnail(MealType meal, Uint8List? png) async {
    try {
      if (png == null) {
        await HomeWidget.saveWidgetData<String>(
            MealWidgetKeys.image(meal), null);
      } else {
        await HomeWidget.saveFile(MealWidgetKeys.image(meal), png,
            extension: 'png');
      }
    } catch (e) {
      debugPrint('MealWidgetBridge.saveThumbnail: $e');
    }
  }

  @override
  Future<bool> shouldOfferPin() async {
    try {
      if (await _storage.read(key: _pinKey) != null) return false;
      return await HomeWidget.isRequestPinWidgetSupported() ?? false;
    } catch (e) {
      debugPrint('MealWidgetBridge.shouldOfferPin: $e');
      return false;
    }
  }

  @override
  Future<void> markPinOffered() async {
    try {
      await _storage.write(key: _pinKey, value: '1');
    } catch (e) {
      debugPrint('MealWidgetBridge.markPinOffered: $e');
    }
  }

  @override
  Future<void> requestPin() async {
    try {
      await HomeWidget.requestPinWidget(qualifiedAndroidName: provider);
    } catch (e) {
      debugPrint('MealWidgetBridge.requestPin: $e');
    }
  }
}

/// Mở app từ widget: `drugtime://meal?meal=toi` (một bữa) hoặc `drugtime://meal` (Dumi AI).
@immutable
class MealWidgetLink {
  const MealWidgetLink({this.meal});
  final MealType? meal;

  static MealWidgetLink? parse(Uri? uri) {
    if (uri == null || uri.scheme != 'drugtime' || uri.host != 'meal') {
      return null;
    }
    final raw = uri.queryParameters['meal'];
    final meal = MealType.values.where((t) => t.apiValue == raw).firstOrNull;
    return MealWidgetLink(meal: meal);
  }
}

/// Nguồn link mở từ widget (lần mở app đầu + khi app đang chạy).
abstract class MealWidgetLinkSource {
  Future<MealWidgetLink?> initial();
  Stream<MealWidgetLink> get links;
}

class HomeWidgetMealLinkSource implements MealWidgetLinkSource {
  @override
  Future<MealWidgetLink?> initial() async {
    try {
      return MealWidgetLink.parse(
          await HomeWidget.initiallyLaunchedFromHomeWidget());
    } catch (e) {
      debugPrint('MealWidgetLinkSource.initial: $e');
      return null;
    }
  }

  @override
  Stream<MealWidgetLink> get links => HomeWidget.widgetClicked
      .map(MealWidgetLink.parse)
      .where((l) => l != null)
      .cast<MealWidgetLink>();
}
