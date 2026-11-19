import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/entities/meal_suggestion.dart';

/// Món người dùng đã chọn cho một bữa. Chỉ gồm thông tin món, không có thuốc/bệnh (AC13, AC14c).
@immutable
class MealChoice {
  const MealChoice({
    required this.name,
    required this.kcal,
    required this.suggestionId,
    required this.dishIndex,
    this.imageId,
  });

  final String name;
  final int kcal;

  /// Để đánh dấu "Đã chọn" đúng thẻ trong thực đơn đang hiện.
  final int suggestionId;
  final int dishIndex;
  final int? imageId;

  Map<String, Object?> toJson() => {
        'name': name,
        'kcal': kcal,
        'suggestion_id': suggestionId,
        'dish_index': dishIndex,
        'image_id': imageId,
      };

  static MealChoice fromJson(Map<String, Object?> json) => MealChoice(
        name: json['name']! as String,
        kcal: (json['kcal']! as num).toInt(),
        suggestionId: (json['suggestion_id']! as num).toInt(),
        dishIndex: (json['dish_index']! as num).toInt(),
        imageId: (json['image_id'] as num?)?.toInt(),
      );
}

/// Các món đã chọn trong một ngày (giờ VN).
@immutable
class MealDayChoices {
  const MealDayChoices({required this.day, required this.meals});

  final String day;
  final Map<MealType, MealChoice> meals;

  String encode() => jsonEncode({
        'day': day,
        'meals': {
          for (final e in meals.entries) e.key.apiValue: e.value.toJson()
        },
      });

  static MealDayChoices decode(String raw) {
    final json = jsonDecode(raw) as Map<String, Object?>;
    final meals = (json['meals']! as Map).cast<String, Object?>();
    return MealDayChoices(
      day: json['day']! as String,
      meals: {
        for (final e in meals.entries)
          MealType.fromApi(e.key):
              MealChoice.fromJson((e.value! as Map).cast<String, Object?>()),
      },
    );
  }
}

/// Kho món đã chọn trên máy, tách theo tài khoản (QD-19).
abstract class MealChoiceStore {
  Future<MealDayChoices?> read(String userId);
  Future<void> write(String userId, MealDayChoices choices);
  Future<void> clear(String userId);
}

/// Lưu qua `flutter_secure_storage` (mã hóa bằng Keystore/Keychain), key theo tài khoản.
class SecureMealChoiceStore implements MealChoiceStore {
  SecureMealChoiceStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;

  String _key(String userId) => 'meal_choices_$userId';

  @override
  Future<MealDayChoices?> read(String userId) async {
    try {
      final raw = await _storage.read(key: _key(userId));
      return raw == null ? null : MealDayChoices.decode(raw);
    } catch (e) {
      // Dữ liệu hỏng hoặc kho lỗi: coi như chưa chọn món nào, không làm hỏng màn hình.
      debugPrint('MealChoiceStore.read: $e');
      return null;
    }
  }

  @override
  Future<void> write(String userId, MealDayChoices choices) async {
    try {
      await _storage.write(key: _key(userId), value: choices.encode());
    } catch (e) {
      debugPrint('MealChoiceStore.write: $e');
    }
  }

  @override
  Future<void> clear(String userId) async {
    try {
      await _storage.delete(key: _key(userId));
    } catch (e) {
      debugPrint('MealChoiceStore.clear: $e');
    }
  }
}

class MemoryMealChoiceStore implements MealChoiceStore {
  final data = <String, String>{};

  @override
  Future<MealDayChoices?> read(String userId) async {
    final raw = data[userId];
    return raw == null ? null : MealDayChoices.decode(raw);
  }

  @override
  Future<void> write(String userId, MealDayChoices choices) async =>
      data[userId] = choices.encode();

  @override
  Future<void> clear(String userId) async => data.remove(userId);
}
