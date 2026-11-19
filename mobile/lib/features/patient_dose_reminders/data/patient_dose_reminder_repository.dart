import '../../../core/api/api_client.dart';

typedef OccurrenceKey = (int, DateTime);

class ReminderReceipt {
  ReminderReceipt(this.id, this.patientId, this.scheduleId, this.scheduledAt,
      this.requestedAt, this.nextAllowedAt, this.status);
  final int id, scheduleId;
  final String patientId, status;
  final DateTime scheduledAt, requestedAt, nextAllowedAt;

  factory ReminderReceipt.fromJson(Map<String, dynamic> json) =>
      ReminderReceipt(
          json['id'] as int,
          json['patient_id'] as String,
          json['schedule_id'] as int,
          DateTime.parse(json['scheduled_at'] as String).toUtc(),
          DateTime.parse(json['requested_at'] as String).toUtc(),
          DateTime.parse(json['next_allowed_at'] as String).toUtc(),
          json['status'] as String);
}

class PatientDoseReminderRepository {
  PatientDoseReminderRepository(this.api);
  final ApiClient api;

  Future<ReminderReceipt?> status(String patientId, OccurrenceKey key) async {
    final json =
        await api.getJson('/patients/$patientId/dose-reminders/status', query: {
      'schedule_id': '${key.$1}',
      'scheduled_at': key.$2.toUtc().toIso8601String(),
    }) as Map<String, dynamic>;
    if (json['patient_id'] != patientId ||
        json['schedule_id'] != key.$1 ||
        DateTime.parse(json['scheduled_at'] as String).toUtc() !=
            key.$2.toUtc()) {
      throw const FormatException('Unexpected reminder state');
    }
    return json['last_reminder'] == null
        ? null
        : _receipt(json['last_reminder'], patientId, key);
  }

  ReminderReceipt _receipt(Object? json, String patientId, OccurrenceKey key) {
    final result = ReminderReceipt.fromJson(json as Map<String, dynamic>);
    if (result.id <= 0 ||
        result.patientId != patientId ||
        result.scheduleId != key.$1 ||
        result.scheduledAt != key.$2.toUtc() ||
        !const {'accepted', 'dispatched', 'cancelled', 'failed'}
            .contains(result.status)) {
      throw const FormatException('Unexpected reminder');
    }
    return result;
  }

  Future<ReminderReceipt> send(
          String patientId, OccurrenceKey key, String uuid) async =>
      _receipt(
          await api.postJson('/patients/$patientId/dose-reminders', body: {
            'client_uuid': uuid,
            'schedule_id': key.$1,
            'scheduled_at': key.$2.toUtc().toIso8601String(),
          }),
          patientId,
          key);

  Future<Map<String, dynamic>> received({int offset = 0}) async =>
      await api.getJson('/dose-reminders/received',
          query: {'offset': '$offset', 'limit': '100'}) as Map<String, dynamic>;

  Future<Map<String, dynamic>> detail(int id) async =>
      await api.getJson('/dose-reminders/received/$id') as Map<String, dynamic>;

  Future<void> markRead(int id) async {
    await api
        .patchJson('/dose-reminders/received/$id', body: {'is_read': true});
  }
}
