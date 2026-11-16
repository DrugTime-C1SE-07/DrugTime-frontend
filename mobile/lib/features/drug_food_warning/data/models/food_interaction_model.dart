library;

/// Mô hình DTO truyền dữ liệu JSON cho cảnh báo tương tác thuốc - thức ăn (Task 4.06, chuẩn bị kết nối Task 4.05).
class FoodWarningItemModel {
  const FoodWarningItemModel({
    required this.id,
    required this.medicationName,
    required this.activeIngredient,
    required this.foodName,
    required this.foodCategory,
    required this.severityLevel,
    required this.mechanismAndRisk,
    required this.recommendation,
    this.timingAdvice,
    required this.source,
    this.catalogId,
  });

  final String id;
  final String medicationName;
  final String activeIngredient;
  final String foodName;
  final String foodCategory;
  final int severityLevel;
  final String mechanismAndRisk;
  final String recommendation;
  final String? timingAdvice;
  final String source;
  final int? catalogId;

  factory FoodWarningItemModel.fromJson(Map<String, dynamic> json) {
    return FoodWarningItemModel(
      id: json['id']?.toString() ?? '',
      medicationName: json['medication_name']?.toString() ?? '',
      activeIngredient: json['active_ingredient']?.toString() ?? '',
      foodName: json['food_name']?.toString() ?? '',
      foodCategory: json['food_category']?.toString() ?? '',
      severityLevel: (json['severity_level'] as num?)?.toInt() ?? 3,
      mechanismAndRisk: json['mechanism_and_risk']?.toString() ?? '',
      recommendation: json['recommendation']?.toString() ?? '',
      timingAdvice: json['timing_advice']?.toString(),
      source: json['source']?.toString() ?? '',
      catalogId: (json['catalog_id'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'medication_name': medicationName,
      'active_ingredient': activeIngredient,
      'food_name': foodName,
      'food_category': foodCategory,
      'severity_level': severityLevel,
      'mechanism_and_risk': mechanismAndRisk,
      'recommendation': recommendation,
      if (timingAdvice != null) 'timing_advice': timingAdvice,
      'source': source,
      if (catalogId != null) 'catalog_id': catalogId,
    };
  }
}

class DrugFoodInteractionResponseModel {
  const DrugFoodInteractionResponseModel({
    required this.status,
    required this.warnings,
    this.insufficientDataMedications = const [],
    this.disclaimer,
  });

  final String status;
  final List<FoodWarningItemModel> warnings;
  final List<String> insufficientDataMedications;
  final String? disclaimer;

  factory DrugFoodInteractionResponseModel.fromJson(Map<String, dynamic> json) {
    final rawWarnings = json['warnings'] as List<dynamic>? ?? const [];
    final warnings = rawWarnings
        .whereType<Map<String, dynamic>>()
        .map(FoodWarningItemModel.fromJson)
        .toList();

    final rawInsufficient =
        json['insufficient_data_medications'] as List<dynamic>? ?? const [];
    final insufficient = rawInsufficient.map((e) => e.toString()).toList();

    return DrugFoodInteractionResponseModel(
      status: json['status']?.toString() ?? 'da_kiem_tra_khong_thay',
      warnings: warnings,
      insufficientDataMedications: insufficient,
      disclaimer: json['disclaimer']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'warnings': warnings.map((w) => w.toJson()).toList(),
      'insufficient_data_medications': insufficientDataMedications,
      if (disclaimer != null) 'disclaimer': disclaimer,
    };
  }
}
