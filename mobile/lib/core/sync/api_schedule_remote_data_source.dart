import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../storage/local_db/local_models.dart';
import 'schedule_sync_service.dart';

/// Lấy lịch uống của patient từ `GET /patients/{patient_id}/schedules` (đã qua PEP ở
/// backend), đi hết các trang theo `next_cursor`.
class ApiScheduleRemoteDataSource implements ScheduleRemoteDataSource {
  ApiScheduleRemoteDataSource(this._apiClient, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.timestamp;

  static const int pageSize = 100;

  final ApiClient _apiClient;
  final DateTime Function() _clock;

  @override
  Future<List<LocalMedicationSchedule>> fetchSchedules({
    required String patientId,
  }) async {
    final syncedAt = _clock().toUtc();
    final result = <LocalMedicationSchedule>[];
    String? cursor;
    do {
      final response = await _apiClient.getJson(
        '/patients/${Uri.encodeComponent(patientId)}/schedules',
        query: {
          'limit': '$pageSize',
          if (cursor != null) 'cursor': cursor,
        },
      );
      if (response is! Map || response['items'] is! List) {
        throw const ApiException('Invalid schedules response');
      }
      for (final item in response['items'] as List) {
        result.add(_toLocal(item, patientId, syncedAt));
      }
      final next = response['next_cursor'];
      cursor = next is String && next.isNotEmpty ? next : null;
    } while (cursor != null);
    return result;
  }

  LocalMedicationSchedule _toLocal(
    Object? item,
    String patientId,
    DateTime syncedAt,
  ) {
    if (item
        case {
          'id': final int id,
          'user_medication_id': final int userMedicationId,
          'medication': {
            'id': final int medicationId,
            'name': final String medicationName,
            'strength_text': final String? strengthText,
            'dosage_form': final String? dosageForm,
          },
          'quantity_per_dose': final num quantityPerDose,
          'doses_per_day': final int dosesPerDay,
          'intake_time': final String intakeTime,
          'days_of_week': final List daysOfWeek,
          'reminder_enabled': final bool reminderEnabled,
          'effective_from': final String effectiveFrom,
        } when daysOfWeek.every((d) => d is int)) {
      final endedAt = item['ended_at'];
      return LocalMedicationSchedule(
        id: id,
        patientUserId: patientId,
        userMedicationId: userMedicationId,
        medicationId: medicationId,
        medicationName: medicationName,
        strengthText: strengthText,
        dosageForm: dosageForm,
        quantityPerDose: _formatQuantity(quantityPerDose),
        dosesPerDay: dosesPerDay,
        intakeTime: intakeTime,
        daysOfWeek: List<int>.from(daysOfWeek),
        reminderEnabled: reminderEnabled,
        effectiveFrom: DateTime.parse(effectiveFrom).toUtc(),
        endedAt: endedAt is String ? DateTime.parse(endedAt).toUtc() : null,
        serverSyncedAt: syncedAt,
      );
    }
    throw const ApiException('Invalid schedule item');
  }

  static String _formatQuantity(num value) =>
      value == value.roundToDouble() ? '${value.toInt()}' : '$value';
}
