library;

import '../../domain/entities/drug_food_interaction.dart';
import 'food_interaction_model.dart';

abstract final class FoodInteractionMapper {
  static DrugFoodInteractionResult fromModel(
      DrugFoodInteractionResponseModel model) {
    return DrugFoodInteractionResult(
      status: FoodInteractionStatus.fromCode(model.status),
      warnings: model.warnings.map(itemFromModel).toList(),
      insufficientDataMedications: model.insufficientDataMedications,
      disclaimer: model.disclaimer ?? nfr03Disclaimer,
    );
  }

  static FoodWarningItem itemFromModel(FoodWarningItemModel model) {
    return FoodWarningItem(
      id: model.id,
      medicationName: model.medicationName,
      activeIngredient: model.activeIngredient,
      foodName: model.foodName,
      foodCategory: model.foodCategory,
      severity: FoodInteractionSeverity.fromLevel(model.severityLevel),
      mechanismAndRisk: model.mechanismAndRisk,
      recommendation: model.recommendation,
      timingAdvice: model.timingAdvice,
      source: model.source,
      catalogId: model.catalogId,
    );
  }

  static DrugFoodInteractionResult fromJson(Map<String, dynamic> json) {
    final model = DrugFoodInteractionResponseModel.fromJson(json);
    return fromModel(model);
  }

  static FoodWarningItem itemFromJson(Map<String, dynamic> json) {
    final model = FoodWarningItemModel.fromJson(json);
    return itemFromModel(model);
  }

  static Map<String, dynamic> toRequestBody({
    String? medicationName,
    String? activeIngredient,
    int? catalogId,
    List<int>? medicationIds,
  }) {
    final body = <String, dynamic>{};
    if (medicationName != null && medicationName.isNotEmpty) {
      body['medication_name'] = medicationName;
    }
    if (activeIngredient != null && activeIngredient.isNotEmpty) {
      body['active_ingredient'] = activeIngredient;
    }
    if (catalogId != null) {
      body['catalog_id'] = catalogId;
    }
    if (medicationIds != null) {
      body['medication_ids'] = medicationIds;
    }
    return body;
  }
}
