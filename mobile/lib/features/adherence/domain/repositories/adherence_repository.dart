import '../entities/adherence_history.dart';

abstract interface class AdherenceRepository {
  Future<AdherenceHistory> fetch({
    required String patientId,
    required DateTime from,
    required DateTime to,
  });
}
