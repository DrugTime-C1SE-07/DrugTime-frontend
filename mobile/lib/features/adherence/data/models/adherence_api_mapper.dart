import '../../domain/entities/adherence_history.dart';

abstract final class AdherenceApiMapper {
  static AdherenceHistory history(Object? payload) {
    final json = _object(payload);
    if (_string(json, 'group_by') != 'date' ||
        _string(json, 'timezone') != 'Asia/Ho_Chi_Minh') {
      throw const FormatException('Unsupported adherence history');
    }
    final groups = _list(json, 'groups')
        .map((value) => dateGroup(value))
        .toList(growable: false);
    return AdherenceHistory(
      patientId: _string(json, 'patient_id'),
      from: _date(_string(json, 'from')),
      to: _date(_string(json, 'to')),
      asOf: _timestamp(_string(json, 'as_of')),
      summary: summary(json['summary']),
      groups: List.unmodifiable(groups),
    );
  }

  static AdherenceDateGroup dateGroup(Object? payload) {
    final json = _object(payload);
    return AdherenceDateGroup(
      date: _date(_string(json, 'date')),
      summary: summary(json['summary']),
      doses: List.unmodifiable(_list(json, 'doses').map(dose)),
    );
  }

  static AdherenceSummary summary(Object? payload) {
    final json = _object(payload);
    final rateValue = json['adherence_rate'];
    if (rateValue != null && rateValue is! num) {
      throw const FormatException('Invalid adherence rate');
    }
    final result = AdherenceSummary(
      total: _integer(json, 'total'),
      taken: _integer(json, 'taken'),
      late: _integer(json, 'late'),
      missed: _integer(json, 'missed'),
      pending: _integer(json, 'pending'),
      counted: _integer(json, 'counted'),
      rate: (rateValue as num?)?.toDouble(),
    );
    if (result.total != result.counted + result.pending ||
        result.counted != result.taken + result.late + result.missed ||
        (result.counted == 0) != (result.rate == null) ||
        (result.rate != null && (result.rate! < 0 || result.rate! > 100))) {
      throw const FormatException('Invalid adherence summary');
    }
    return result;
  }

  static AdherenceDose dose(Object? payload) {
    final json = _object(payload);
    final statusValue = _string(json, 'status');
    final status = AdherenceDoseStatus.values.where(
      (value) => value.apiValue == statusValue,
    );
    if (status.isEmpty) throw const FormatException('Unknown dose status');
    final takenValue = json['taken_at'];
    if (takenValue != null && takenValue is! String) {
      throw const FormatException('Invalid taken time');
    }
    final source = _string(json, 'status_source');
    final confirmed = status.first == AdherenceDoseStatus.taken ||
        status.first == AdherenceDoseStatus.late;
    if ((confirmed && (takenValue == null || source != 'recorded')) ||
        (!confirmed && takenValue != null) ||
        (status.first == AdherenceDoseStatus.pending && source != 'inferred')) {
      throw const FormatException('Inconsistent dose status');
    }
    return AdherenceDose(
      medicationId: _integer(json, 'medication_id'),
      medicationName: _string(json, 'medication_name'),
      scheduleId: _integer(json, 'schedule_id'),
      scheduledAt: _timestamp(_string(json, 'scheduled_at')),
      takenAt: takenValue == null ? null : _timestamp(takenValue),
      status: status.first,
    );
  }

  static Map<String, dynamic> _object(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Invalid adherence object');
    }
    return value;
  }

  static String _string(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String || value.isEmpty) {
      throw const FormatException('Invalid adherence string');
    }
    return value;
  }

  static int _integer(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! int || value < 0) {
      throw const FormatException('Invalid adherence count');
    }
    return value;
  }

  static List<dynamic> _list(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! List) throw const FormatException('Invalid adherence list');
    return value;
  }

  static DateTime _date(String value) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      throw const FormatException('Invalid adherence date');
    }
    final date = DateTime.tryParse(value);
    if (date == null || adherenceDateQuery(date) != value) {
      throw const FormatException('Invalid adherence date');
    }
    return DateTime.utc(date.year, date.month, date.day);
  }

  static DateTime _timestamp(String value) {
    if (!RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(value)) {
      throw const FormatException('Missing time offset');
    }
    final date = DateTime.tryParse(value);
    if (date == null) {
      throw const FormatException('Invalid adherence timestamp');
    }
    return date.toUtc();
  }
}
