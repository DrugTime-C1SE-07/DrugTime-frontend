library;

import '../entities/interaction_check_result.dart';

abstract interface class InteractionCheckRepository {
  Future<InteractionCheckResult> checkPatientInteractions({
    required String patientId,
    int? candidateMedicationId,
    double? candidateDoseAmount,
    String? candidateDoseUnit,
    List<int>? medicationIds,
  });
}
