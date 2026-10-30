import '../entities/adherence_history.dart';

abstract interface class AdherenceHistoryRepository {
  Future<AdherenceHistory> fetch({
    required DateTime from,
    required DateTime to,
    required HistoryMode mode,
  });
}
