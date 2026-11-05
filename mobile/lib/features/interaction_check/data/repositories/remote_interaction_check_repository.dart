library;

import '../../../../core/api/api_client.dart';
import '../../domain/entities/interaction_check_result.dart';
import '../../domain/repositories/interaction_check_repository.dart';
import '../models/interaction_check_mapper.dart';

class RemoteInteractionCheckRepository implements InteractionCheckRepository {
  RemoteInteractionCheckRepository(this._api);

  final ApiClient _api;

  @override
  Future<InteractionCheckResult> checkPatientInteractions({
    required String patientId,
    int? candidateMedicationId,
    double? candidateDoseAmount,
    String? candidateDoseUnit,
    List<int>? medicationIds,
  }) async {
    final body = InteractionCheckMapper.toRequestBody(
      candidateMedicationId: candidateMedicationId,
      candidateDoseAmount: candidateDoseAmount,
      candidateDoseUnit: candidateDoseUnit,
      medicationIds: medicationIds,
    );
    final json = await _api.postJson(
      '/patients/$patientId/interaction-checks',
      body: body,
    );
    return InteractionCheckMapper.fromJson(json as Map<String, dynamic>);
  }
}
