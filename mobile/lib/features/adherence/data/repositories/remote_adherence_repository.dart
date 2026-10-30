import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_exception.dart';
import '../../domain/entities/adherence_failure.dart';
import '../../domain/entities/adherence_history.dart';
import '../../domain/repositories/adherence_repository.dart';
import '../models/adherence_api_mapper.dart';

class RemoteAdherenceRepository implements AdherenceRepository {
  const RemoteAdherenceRepository(this._api);

  final ApiClient _api;

  @override
  Future<AdherenceHistory> fetch({
    required String patientId,
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final payload = await _api.getJson('/adherence', query: {
        'patient_id': patientId,
        'from': adherenceDateQuery(from),
        'to': adherenceDateQuery(to),
        'group_by': 'date',
      });
      final history = AdherenceApiMapper.history(payload);
      if (history.patientId != patientId) {
        throw const FormatException('Unexpected patient');
      }
      return history;
    } on ApiException catch (error) {
      final kind = switch (error.statusCode) {
        401 => AdherenceFailureKind.unauthorized,
        403 => AdherenceFailureKind.denied,
        422 => AdherenceFailureKind.invalidRange,
        int code when code >= 500 => AdherenceFailureKind.unavailable,
        _ => error.isTransient
            ? AdherenceFailureKind.network
            : AdherenceFailureKind.invalidResponse,
      };
      throw AdherenceFailure(kind);
    } on FormatException {
      throw const AdherenceFailure(AdherenceFailureKind.invalidResponse);
    } on TypeError {
      throw const AdherenceFailure(AdherenceFailureKind.invalidResponse);
    }
  }
}
