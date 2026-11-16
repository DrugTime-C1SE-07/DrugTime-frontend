import 'dart:typed_data';

import '../entities/meal_suggestion.dart';

/// Ném [MealSuggestionFailure] khi lỗi. Không tự retry (contract 4.26).
abstract interface class MealSuggestionRepository {
  Future<MealSuggestionResult> suggest({
    required String patientId,
    required MealType mealType,
    required DietaryDeclaration allergies,
    required DietaryDeclaration restrictions,
    List<String> preferences = const [],
    int? previousSuggestionId,
  });

  /// Trạng thái hiện tại của các ảnh; id không còn tồn tại bị bỏ qua.
  Future<List<MealDishImage>> imageStates(List<int> imageIds);

  /// Nội dung ảnh qua Backend API (không gọi kho lưu trữ hay kho ảnh trực tiếp).
  Future<Uint8List> imageBytes(MealDishImage image);
}
