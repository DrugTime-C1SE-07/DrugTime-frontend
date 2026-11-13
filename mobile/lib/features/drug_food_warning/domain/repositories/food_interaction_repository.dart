library;

import '../entities/drug_food_interaction.dart';

/// Hợp đồng Repository kiểm tra tương tác thuốc và thức ăn/đồ uống (Task 4.06).
abstract interface class FoodInteractionRepository {
  /// Kiểm tra các cảnh báo thực phẩm cho thuốc chỉ định hoặc toàn bộ danh mục thuốc của bệnh nhân.
  Future<DrugFoodInteractionResult> checkFoodInteractions({
    required String patientId,
    String? medicationName,
    String? activeIngredient,
    int? catalogId,
    List<int>? medicationIds,
  });
}
