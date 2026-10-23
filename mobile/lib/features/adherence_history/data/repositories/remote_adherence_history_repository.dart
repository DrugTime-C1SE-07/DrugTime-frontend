import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_exception.dart';
import '../../domain/entities/adherence_history.dart';
import '../../domain/entities/adherence_history_failure.dart';
import '../../domain/repositories/adherence_history_repository.dart';
import '../models/adherence_history_api_mapper.dart';

class RemoteAdherenceHistoryRepository implements AdherenceHistoryRepository {
  RemoteAdherenceHistoryRepository(this._api);
  final ApiClient _api;

  @override
  Future<AdherenceHistory> fetch(
      {required DateTime from,
      required DateTime to,
      required HistoryMode mode}) async {
    try {
      final result = AdherenceHistoryApiMapper.parse(
          await _api.getJson('/adherence', query: {
        'from': AdherenceHistoryApiMapper.dateString(from),
        'to': AdherenceHistoryApiMapper.dateString(to),
        'group_by': mode.wire,
      }));
      if (result.mode != mode || result.from != from || result.to != to) {
        throw const FormatException('History selection mismatch');
      }
      return result;
    } on ApiException catch (error) {
      throw AdherenceHistoryApiMapper.failure(error);
    } on FormatException {
      throw const HistoryFailure(HistoryFailureKind.invalidResponse);
    } on TypeError {
      throw const HistoryFailure(HistoryFailureKind.invalidResponse);
    }
  }
}
