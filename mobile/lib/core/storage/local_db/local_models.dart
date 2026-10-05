enum DoseLogStatus {
  taken('da_uong'),
  missed('bo_lo'),
  late('uong_tre');

  const DoseLogStatus(this.serverValue);

  final String serverValue;

  static DoseLogStatus fromServerValue(String value) {
    return DoseLogStatus.values.firstWhere(
      (status) => status.serverValue == value,
      orElse: () => throw ArgumentError('Unknown dose log status: $value'),
    );
  }
}

enum DoseLogSyncState {
  pendingUpload('pending_upload'),
  synced('synced'),
  failed('failed');

  const DoseLogSyncState(this.value);

  final String value;

  static DoseLogSyncState fromValue(String value) {
    return DoseLogSyncState.values.firstWhere(
      (state) => state.value == value,
      orElse: () => throw ArgumentError('Unknown dose log sync state: $value'),
    );
  }
}

class LocalMedicationSchedule {
  const LocalMedicationSchedule({
    required this.id,
    required this.patientUserId,
    required this.userMedicationId,
    required this.medicationId,
    required this.medicationName,
    this.strengthText,
    this.dosageForm,
    required this.quantityPerDose,
    required this.dosesPerDay,
    required this.intakeTime,
    required this.daysOfWeek,
    required this.reminderEnabled,
    required this.effectiveFrom,
    this.endedAt,
    required this.serverSyncedAt,
  });

  final int id;
  final String patientUserId;
  final int userMedicationId;
  final int medicationId;
  final String medicationName;
  final String? strengthText;
  final String? dosageForm;
  final String quantityPerDose;
  final int dosesPerDay;

  /// Server sends SQL time, for example: "08:00:00".
  final String intakeTime;

  /// Server uses 1..7. Keep the same rule locally to avoid remapping bugs.
  final List<int> daysOfWeek;
  final bool reminderEnabled;
  final DateTime effectiveFrom;
  final DateTime? endedAt;
  final DateTime serverSyncedAt;

  bool get isActive => reminderEnabled && endedAt == null;

  Map<String, Object?> toDbMap() {
    return {
      'id': id,
      'patient_user_id': patientUserId,
      'user_medication_id': userMedicationId,
      'medication_id': medicationId,
      'medication_name': medicationName,
      'strength_text': strengthText,
      'dosage_form': dosageForm,
      'quantity_per_dose': quantityPerDose,
      'doses_per_day': dosesPerDay,
      'intake_time': intakeTime,
      'days_of_week': _encodeIntList(daysOfWeek),
      'reminder_enabled': reminderEnabled ? 1 : 0,
      'effective_from': _encodeDateTime(effectiveFrom),
      'ended_at': _encodeNullableDateTime(endedAt),
      'server_synced_at': _encodeDateTime(serverSyncedAt),
    };
  }

  factory LocalMedicationSchedule.fromDbMap(Map<String, Object?> map) {
    return LocalMedicationSchedule(
      id: map['id'] as int,
      patientUserId: map['patient_user_id'] as String,
      userMedicationId: map['user_medication_id'] as int,
      medicationId: map['medication_id'] as int,
      medicationName: map['medication_name'] as String,
      strengthText: map['strength_text'] as String?,
      dosageForm: map['dosage_form'] as String?,
      quantityPerDose: map['quantity_per_dose'] as String,
      dosesPerDay: map['doses_per_day'] as int,
      intakeTime: map['intake_time'] as String,
      daysOfWeek: _decodeIntList(map['days_of_week'] as String),
      reminderEnabled: map['reminder_enabled'] == 1,
      effectiveFrom: DateTime.parse(map['effective_from'] as String),
      endedAt: _parseNullableDateTime(map['ended_at'] as String?),
      serverSyncedAt: DateTime.parse(map['server_synced_at'] as String),
    );
  }
}

class LocalDoseLog {
  const LocalDoseLog({
    this.id,
    required this.clientUuid,
    required this.medicationScheduleId,
    required this.scheduledAt,
    this.takenAt,
    required this.status,
    required this.syncState,
    this.syncedAt,
    this.lastError,
    required this.localUpdatedAt,
  });

  /// Server id. Null while this row only exists on the device.
  final int? id;
  final String clientUuid;
  final int medicationScheduleId;
  final DateTime scheduledAt;
  final DateTime? takenAt;
  final DoseLogStatus status;
  final DoseLogSyncState syncState;
  final DateTime? syncedAt;
  final String? lastError;
  final DateTime localUpdatedAt;

  Map<String, Object?> toDbMap() {
    return {
      'id': id,
      'client_uuid': clientUuid,
      'medication_schedule_id': medicationScheduleId,
      'scheduled_at': _encodeDateTime(scheduledAt),
      'taken_at': _encodeNullableDateTime(takenAt),
      'status': status.serverValue,
      'sync_state': syncState.value,
      'synced_at': _encodeNullableDateTime(syncedAt),
      'last_error': lastError,
      'local_updated_at': _encodeDateTime(localUpdatedAt),
    };
  }

  factory LocalDoseLog.fromDbMap(Map<String, Object?> map) {
    return LocalDoseLog(
      id: map['id'] as int?,
      clientUuid: map['client_uuid'] as String,
      medicationScheduleId: map['medication_schedule_id'] as int,
      scheduledAt: DateTime.parse(map['scheduled_at'] as String),
      takenAt: _parseNullableDateTime(map['taken_at'] as String?),
      status: DoseLogStatus.fromServerValue(map['status'] as String),
      syncState: DoseLogSyncState.fromValue(map['sync_state'] as String),
      syncedAt: _parseNullableDateTime(map['synced_at'] as String?),
      lastError: map['last_error'] as String?,
      localUpdatedAt: DateTime.parse(map['local_updated_at'] as String),
    );
  }
}

String _encodeDateTime(DateTime value) {
  return value.toUtc().toIso8601String();
}

String? _encodeNullableDateTime(DateTime? value) {
  return value == null ? null : _encodeDateTime(value);
}

DateTime? _parseNullableDateTime(String? value) {
  return value == null ? null : DateTime.parse(value);
}

String _encodeIntList(List<int> values) {
  return values.join(',');
}

List<int> _decodeIntList(String value) {
  if (value.isEmpty) {
    return const [];
  }

  return value.split(',').map(int.parse).toList(growable: false);
}
