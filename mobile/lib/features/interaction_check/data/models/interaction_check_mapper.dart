library;

import '../../domain/entities/interaction_check_result.dart';

abstract final class InteractionCheckMapper {
  static InteractionCheckResult fromJson(Map<String, dynamic> json) {
    final statusStr = json['status']?.toString() ?? 'da_kiem_tra_khong_thay';
    final status = InteractionCheckStatus.fromCode(statusStr);

    final rawInteractions = json['interactions'] as List<dynamic>? ?? const [];
    final interactions = rawInteractions
        .whereType<Map<String, dynamic>>()
        .map(findingFromJson)
        .toList();

    final rawInsufficient =
        json['insufficient_data_medications'] as List<dynamic>? ?? const [];
    final insufficient = rawInsufficient
        .whereType<Map<String, dynamic>>()
        .map(insufficientFromJson)
        .toList();

    final disclaimer = json['disclaimer']?.toString() ?? nfr03Disclaimer;

    return InteractionCheckResult(
      status: status,
      interactions: interactions,
      insufficientDataMedications: insufficient,
      disclaimer: disclaimer,
    );
  }

  static InteractionFinding findingFromJson(Map<String, dynamic> json) {
    return InteractionFinding(
      ingredientAId: (json['ingredient_a_id'] as num?)?.toInt() ?? 0,
      ingredientAName: json['ingredient_a_name']?.toString() ?? '',
      ingredientBId: (json['ingredient_b_id'] as num?)?.toInt(),
      ingredientBName: json['ingredient_b_name']?.toString() ?? '',
      medicationAId: (json['medication_a_id'] as num?)?.toInt(),
      medicationAName: json['medication_a_name']?.toString(),
      medicationBId: (json['medication_b_id'] as num?)?.toInt(),
      medicationBName: json['medication_b_name']?.toString(),
      severityLevel: (json['severity_level'] as num?)?.toInt() ?? 1,
      interactionType: json['interaction_type']?.toString() ?? '',
      handlingType: json['handling_type']?.toString() ?? '',
      minIntervalHours: (json['min_interval_hours'] as num?)?.toDouble(),
      description: json['description']?.toString() ?? '',
      warningMessage: json['warning_message']?.toString() ?? '',
      source: json['source']?.toString() ?? '',
    );
  }

  static InsufficientDataMedication insufficientFromJson(
      Map<String, dynamic> json) {
    return InsufficientDataMedication(
      medicationId: (json['medication_id'] as num?)?.toInt() ?? 0,
      medicationName: json['medication_name']?.toString() ?? '',
      reason: json['reason']?.toString() ?? '',
    );
  }

  static Map<String, dynamic> toRequestBody({
    int? candidateMedicationId,
    double? candidateDoseAmount,
    String? candidateDoseUnit,
    List<int>? medicationIds,
  }) {
    final body = <String, dynamic>{};
    if (candidateMedicationId != null) {
      body['candidate_medication_id'] = candidateMedicationId;
    }
    if (candidateDoseAmount != null) {
      body['candidate_dose_amount'] = candidateDoseAmount;
    }
    if (candidateDoseUnit != null && candidateDoseUnit.isNotEmpty) {
      body['candidate_dose_unit'] = candidateDoseUnit;
    }
    if (medicationIds != null) {
      body['medication_ids'] = medicationIds;
    }
    return body;
  }
}
