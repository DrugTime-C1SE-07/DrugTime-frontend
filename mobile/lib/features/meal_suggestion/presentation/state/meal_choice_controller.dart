import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/meal_choice_store.dart';
import '../../data/meal_widget_bridge.dart';
import '../../domain/entities/meal_suggestion.dart';
import 'meal_plan_controller.dart';

/// Món đã chọn hôm nay, mức phiên app (AC8, AC13). Lưu trên máy, không gửi lên server.
class MealChoiceController extends ChangeNotifier {
  MealChoiceController({
    required MealChoiceStore store,
    MealWidgetBridge bridge = const NoopMealWidgetBridge(),
    DateTime Function()? now,
    this.readOnly = false,
  })  : _store = store,
        _bridge = bridge,
        _now = now ?? DateTime.now;

  final MealChoiceStore _store;
  final MealWidgetBridge _bridge;
  final DateTime Function() _now;

  /// Phía người thân chỉ xem (QD-27): không chọn món và không ghi widget chính chủ.
  final bool readOnly;

  String? _userId;
  String _day = '';
  Map<MealType, MealChoice> _meals = const {};
  bool _disposed = false;
  int _bindSeq = 0;

  /// Cầu nối widget màn hình chính (gợi ý ghim widget).
  MealWidgetBridge get bridge => _bridge;

  Map<MealType, MealChoice> get choices {
    _rollDay();
    return _meals;
  }

  MealChoice? choiceOf(MealType type) => choices[type];
  bool get hasAny => choices.isNotEmpty;

  bool isChosen(MealType type, int suggestionId, int dishIndex) {
    final c = choices[type];
    return c != null &&
        c.suggestionId == suggestionId &&
        c.dishIndex == dishIndex;
  }

  /// Gắn tài khoản và đọc kho. Dữ liệu của ngày khác bị bỏ và xóa.
  Future<void> bind(String? userId) async {
    if (userId == _userId) {
      _rollDay();
      return;
    }
    final seq = ++_bindSeq;
    _userId = userId;
    _meals = const {};
    _day = vietnamDay(_now());
    if (readOnly) {
      _notify();
      return;
    }
    if (userId == null) {
      _notify();
      await _bridge.publish(const TodayMenuSnapshot.signedOut());
      return;
    }
    final stored = await _store.read(userId);
    if (_disposed || seq != _bindSeq) return;
    if (stored != null && stored.day == _day) {
      _meals = stored.meals;
    } else if (stored != null) {
      await _store.clear(userId);
    }
    _notify();
    await _publish();
  }

  /// [thumbnail]: ảnh nhỏ PNG của món cho widget màn hình chính (nếu có).
  Future<void> choose(MealType type, MealChoice choice,
      {Uint8List? thumbnail}) async {
    if (readOnly) return;
    _rollDay();
    _meals = {..._meals, type: choice};
    await _bridge.saveThumbnail(type, thumbnail);
    await _save();
  }

  /// Gắn ảnh nhỏ cho món đã chọn của [type] (tải ảnh xong sau khi chọn), rồi vẽ lại widget.
  Future<void> attachThumbnail(
      MealType type, MealChoice choice, Uint8List png) async {
    if (readOnly) return;
    final current = _meals[type];
    if (current == null ||
        current.suggestionId != choice.suggestionId ||
        current.dishIndex != choice.dishIndex) {
      return; // đã đổi hoặc bỏ chọn trong lúc tải ảnh
    }
    await _bridge.saveThumbnail(type, png);
    await _publish();
  }

  Future<void> unchoose(MealType type) async {
    if (readOnly) return;
    _rollDay();
    if (!_meals.containsKey(type)) return;
    _meals = {..._meals}..remove(type);
    await _bridge.saveThumbnail(type, null);
    await _save();
  }

  /// Thu hồi consent `ai_meal`: xóa món đã chọn và dữ liệu widget.
  Future<void> clear() async {
    _meals = const {};
    final user = _userId;
    _notify();
    if (readOnly) return;
    if (user != null) await _store.clear(user);
    await _clearThumbnails();
    await _publish();
  }

  /// Đăng xuất: xóa kho của tài khoản cũ, widget về "Đăng nhập để xem".
  Future<void> signOut() async {
    final user = _userId;
    _bindSeq++;
    _userId = null;
    _meals = const {};
    _notify();
    if (readOnly) return;
    if (user != null) await _store.clear(user);
    await _clearThumbnails();
    await _bridge.publish(const TodayMenuSnapshot.signedOut());
  }

  Future<void> _clearThumbnails() async {
    for (final m in MealType.values) {
      await _bridge.saveThumbnail(m, null);
    }
  }

  /// Qua 00:00 giờ VN thì danh sách hôm qua không còn giá trị.
  void _rollDay() {
    final today = vietnamDay(_now());
    if (today == _day) return;
    _day = today;
    if (_meals.isEmpty) return;
    _meals = const {};
    final user = _userId;
    if (user != null) unawaited(_store.clear(user));
    unawaited(_clearThumbnails().then((_) => _publish()));
    // Báo listener sau khung hình hiện tại: _rollDay có thể chạy trong lúc build.
    scheduleMicrotask(_notify);
  }

  Future<void> _save() async {
    _notify();
    final user = _userId;
    if (user == null) return;
    if (_meals.isEmpty) {
      await _store.clear(user);
    } else {
      await _store.write(user, MealDayChoices(day: _day, meals: _meals));
    }
    await _publish();
  }

  /// Đẩy lại dữ liệu hiện tại cho widget (gọi khi mở app để widget đúng ngày).
  Future<void> publish() {
    _rollDay();
    return _publish();
  }

  Future<void> _publish() {
    if (_userId == null) {
      return _bridge.publish(const TodayMenuSnapshot.signedOut());
    }
    return _bridge.publish(TodayMenuSnapshot(
      state: _meals.isEmpty ? TodayMenuState.empty : TodayMenuState.ok,
      day: _day,
      meals: {
        for (final e in _meals.entries)
          e.key: TodayMenuItem(
              name: e.value.name, kcal: e.value.kcal, imageId: e.value.imageId),
      },
    ));
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
