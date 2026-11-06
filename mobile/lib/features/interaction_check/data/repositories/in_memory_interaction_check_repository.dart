library;

import '../../domain/entities/interaction_check_result.dart';
import '../../domain/repositories/interaction_check_repository.dart';

class InMemoryInteractionCheckRepository implements InteractionCheckRepository {
  InMemoryInteractionCheckRepository({
    this.stubResult,
    this.onCheck,
  });

  InteractionCheckResult? stubResult;
  Future<InteractionCheckResult> Function({
    required String patientId,
    int? candidateMedicationId,
    double? candidateDoseAmount,
    String? candidateDoseUnit,
    List<int>? medicationIds,
  })? onCheck;

  @override
  Future<InteractionCheckResult> checkPatientInteractions({
    required String patientId,
    int? candidateMedicationId,
    double? candidateDoseAmount,
    String? candidateDoseUnit,
    List<int>? medicationIds,
  }) async {
    if (onCheck != null) {
      return onCheck!(
        patientId: patientId,
        candidateMedicationId: candidateMedicationId,
        candidateDoseAmount: candidateDoseAmount,
        candidateDoseUnit: candidateDoseUnit,
        medicationIds: medicationIds,
      );
    }
    return stubResult ??
        const InteractionCheckResult(
          status: InteractionCheckStatus.noneFound,
          interactions: [],
          insufficientDataMedications: [],
          disclaimer: nfr03Disclaimer,
        );
  }
}
