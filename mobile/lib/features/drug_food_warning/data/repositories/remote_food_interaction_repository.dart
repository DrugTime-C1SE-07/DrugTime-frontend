library;

import '../../../../core/api/api_client.dart';
import '../../domain/entities/drug_food_interaction.dart';
import '../../domain/repositories/food_interaction_repository.dart';
import '../models/food_interaction_mapper.dart';

/// Repository kết nối Backend API thực tế cho tương tác thuốc - thức ăn (chuẩn bị sẵn cho Task 4.05).
class RemoteFoodInteractionRepository implements FoodInteractionRepository {
  RemoteFoodInteractionRepository(this._api);

  final ApiClient _api;

  @override
  Future<DrugFoodInteractionResult> checkFoodInteractions({
    required String patientId,
    String? medicationName,
    String? activeIngredient,
    int? catalogId,
    List<int>? medicationIds,
  }) async {
    final body = FoodInteractionMapper.toRequestBody(
      medicationName: medicationName,
      activeIngredient: activeIngredient,
      catalogId: catalogId,
      medicationIds: medicationIds,
    );
    final json = await _api.postJson(
      '/patients/$patientId/food-interaction-checks',
      body: body,
    );
    return FoodInteractionMapper.fromJson(json as Map<String, dynamic>);
  }
}
