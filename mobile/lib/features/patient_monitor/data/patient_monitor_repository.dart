import '../../../core/api/api_client.dart';
import '../../adherence/data/models/adherence_api_mapper.dart';
import '../../adherence/domain/entities/adherence_history.dart';
import '../../family_link/presentation/state/linked_patients_controller.dart';
import '../../interaction_check/data/repositories/remote_interaction_check_repository.dart';
import '../../interaction_check/domain/entities/interaction_check_result.dart';
import '../../medication/data/models/medication_api_mapper.dart';
import '../../medication/domain/entities/medication.dart';
import '../domain/monitor_models.dart';

class PatientMonitorRepository {
  PatientMonitorRepository(this.api);
  final ApiClient api;

  Future<List<LinkedPatient>> patients() async {
    final json = await api.getJson('/family/patients') as Map<String, dynamic>;
    return [
      for (final item in json['items'] as List)
        LinkedPatient(
            id: item['patient_id'] as String,
            name: (item['patient_full_name'] as String?)?.trim() ?? '')
    ];
  }

  Future<List<Map<String, dynamic>>> _pages(String path) async {
    final rows = <Map<String, dynamic>>[];
    final seen = <String>{};
    String? cursor;
    do {
      final page = await api.getJson(path, query: {
        'limit': '200',
        if (cursor != null) 'cursor': cursor,
      }) as Map<String, dynamic>;
      rows.addAll((page['items'] as List).cast<Map<String, dynamic>>());
      cursor = page['next_cursor'] as String?;
      if (cursor != null && !seen.add(cursor)) {
        throw const FormatException('Repeated pagination cursor');
      }
    } while (cursor != null);
    return rows;
  }

  Future<MonitorHistory> history(
      String patientId, DateTime from, DateTime to) async {
    final json = await api.getJson('/adherence', query: {
      'patient_id': patientId,
      'from': adherenceDateQuery(from),
      'to': adherenceDateQuery(to),
      'group_by': 'date',
    }) as Map<String, dynamic>;
    final result = AdherenceApiMapper.history(json);
    if (result.patientId != patientId) {
      throw const FormatException('Unexpected patient');
    }
    return MonitorHistory(
        result,
        json['patient_last_synced_at'] == null
            ? null
            : DateTime.parse(json['patient_last_synced_at'] as String).toUtc());
  }

  Future<MonitorSnapshot> today(String patientId,
      {required DateTime now, bool includeMedications = true}) async {
    final day = monitorDay(now);
    final results = await Future.wait<Object>([
      _pages('/patients/$patientId/schedules'),
      history(patientId, day.subtract(const Duration(days: 6)), day),
      if (includeMedications) _pages('/patients/$patientId/medications'),
    ], eagerError: true);
    return MonitorSnapshot(
      patientId,
      (results[0] as List<Map<String, dynamic>>)
          .map(MonitorSchedule.fromJson)
          .toList(),
      results[1] as MonitorHistory,
      includeMedications
          ? (results[2] as List<Map<String, dynamic>>)
              .map(MedicationApiMapper.medicationFromJson)
              .toList()
          : <Medication>[],
    );
  }

  Future<InteractionCheckResult> interactions(String patientId) =>
      RemoteInteractionCheckRepository(api)
          .checkPatientInteractions(patientId: patientId);

  // The legacy food-warning repository targets a different, unimplemented POST.
  // This monitor reads the canonical GET and keeps every medication's three-state result.
  Future<Map<String, dynamic>> foodInteractions(String patientId) async {
    final json = await api.getJson('/patients/$patientId/food-interactions')
        as Map<String, dynamic>;
    if (json['patient_id'] != patientId ||
        !const {'co_tuong_tac', 'da_kiem_tra_khong_thay', 'khong_du_du_lieu'}
            .contains(json['status'])) {
      throw const FormatException('Unexpected food interaction report');
    }
    return json;
  }
}
