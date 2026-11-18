import 'dart:convert';

import '../../../../core/api/api_exception.dart';
import '../../domain/entities/meal_suggestion.dart';

/// JSON contract 5.11 ↔ thực thể. `image_query` không bao giờ có trong response nên không đọc.
class MealSuggestionMapper {
  const MealSuggestionMapper._();

  static Map<String, Object> toRequestBody({
    required MealType mealType,
    required DietaryDeclaration allergies,
    required DietaryDeclaration restrictions,
    List<String> preferences = const [],
    int? previousSuggestionId,
  }) =>
      {
        'meal_type': mealType.apiValue,
        'allergies': allergies.toJson(),
        'dietary_restrictions': restrictions.toJson(),
        'preferences': preferences,
        if (previousSuggestionId != null)
          'previous_suggestion_id': previousSuggestionId,
      };

  static MealSuggestionResult fromJson(Map<String, dynamic> json) =>
      MealSuggestionResult(
        suggestionId: json['suggestion_id'] as int,
        mealType: MealType.fromApi(json['meal_type'] as String),
        dishes: (json['suggestions'] as List)
            .map((d) => dishFromJson(d as Map<String, dynamic>))
            .toList(),
        foodCheck: _foodCheck(json['food_check'] as Map<String, dynamic>),
        disclaimer: json['disclaimer'] as String,
        refreshesRemaining: json['refreshes_remaining'] as int,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  static MealDish dishFromJson(Map<String, dynamic> json) => MealDish(
        name: json['name'] as String,
        dishType: MealDishType.fromApi(json['dish_type'] as String?),
        isNew: json['is_new'] as bool? ?? true,
        tags: List<String>.from(json['tags'] as List),
        kcalEstimate: json['kcal_estimate'] as int,
        cookMinutes: json['cook_minutes'] as int,
        image: json['image'] == null
            ? null
            : imageFromJson(json['image'] as Map<String, dynamic>),
        benefits: (json['benefits'] as List).map((b) {
          final related = (b as Map<String, dynamic>)['related_to']
              as Map<String, dynamic>;
          return MealBenefit(
            text: b['text'] as String,
            type: related['type'] as String,
            label: related['label'] as String?,
          );
        }).toList(),
        ingredients: (json['ingredients'] as List).map((i) {
          final m = i as Map<String, dynamic>;
          return MealIngredient(
            name: m['name'] as String,
            amount: m['amount'] as String,
            isMain: m['group'] == 'chinh',
            useSparingly: m['use_sparingly'] as bool,
          );
        }).toList(),
      );

  static MealDishImage imageFromJson(Map<String, dynamic> json) {
    final status = switch (json['status']) {
      'ready' => MealImageStatus.ready,
      'pending' => MealImageStatus.pending,
      _ => MealImageStatus.failed,
    };
    final attribution = json['attribution'] as Map<String, dynamic>?;
    return MealDishImage(
      imageId: json['image_id'] as int,
      status: status,
      url: json['url'] as String?,
      attribution: attribution == null
          ? null
          : MealImageAttribution(
              photographerName: attribution['photographer_name'] as String,
              photographerUrl: attribution['photographer_url'] as String,
              sourceUrl: attribution['source_url'] as String,
            ),
    );
  }

  static MealFoodCheck _foodCheck(Map<String, dynamic> json) => MealFoodCheck(
        status: switch (json['status']) {
          'co_tuong_tac' => FoodCheckStatus.coTuongTac,
          'da_kiem_tra_khong_thay' => FoodCheckStatus.daKiemTraKhongThay,
          _ => FoodCheckStatus.khongDuDuLieu,
        },
        warnings: (json['warnings'] as List).map((w) {
          final m = w as Map<String, dynamic>;
          return MealFoodWarning(
            foodToAvoid: m['food_to_avoid'] as String,
            reason: m['reason'] as String,
            severityLevel: m['severity_level'] as int,
            source: m['source'] as String,
          );
        }).toList(),
      );

  /// Đổi lỗi API sang lỗi domain theo mã trong contract; không giữ body thô.
  static MealSuggestionFailure failureFrom(ApiException error) {
    final status = error.statusCode;
    if (status == null) return const MealSuggestionFailure(MealFailureKind.network);
    String? detail;
    try {
      final body = jsonDecode(error.message);
      if (body is Map && body['detail'] is String) detail = body['detail'] as String;
    } on FormatException {
      detail = null;
    }
    final kind = switch ((status, detail)) {
      (403, 'consent_revoked') => MealFailureKind.consentRevoked,
      (403, _) => MealFailureKind.forbidden,
      (422, 'previous_suggestion_not_found') => MealFailureKind.previousNotFound,
      (429, _) => MealFailureKind.refreshLimit,
      (502, _) => MealFailureKind.llmInvalidOutput,
      (503, 'llm_disabled') => MealFailureKind.llmDisabled,
      (503, 'llm_unavailable') => MealFailureKind.llmUnavailable,
      (503, _) => MealFailureKind.serviceUnavailable,
      (408, _) => MealFailureKind.network,
      _ => MealFailureKind.unknown,
    };
    return MealSuggestionFailure(kind);
  }
}
