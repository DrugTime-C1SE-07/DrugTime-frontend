import 'dart:convert';

import '../../../../core/api/api_exception.dart';
import '../../domain/entities/adherence_history.dart';
import '../../domain/entities/adherence_history_failure.dart';

abstract final class AdherenceHistoryApiMapper {
  static Never _invalid() =>
      throw const FormatException('Invalid history shape');

  static Map<String, dynamic> _object(Object? raw) =>
      raw is Map<String, dynamic> ? raw : _invalid();
  static List<dynamic> _list(Object? raw) => raw is List ? raw : _invalid();
  static String _text(Object? raw) =>
      raw is String && raw.isNotEmpty ? raw : _invalid();
  static int _count(Object? raw) => raw is int && raw >= 0 ? raw : _invalid();
  static int _id(Object? raw) => raw is int && raw > 0 ? raw : _invalid();

  static String dateString(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  static DateTime _date(Object? raw) {
    if (raw is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw)) {
      return _invalid();
    }
    final date = DateTime.parse('${raw}T00:00:00Z');
    if (dateString(date) != raw) return _invalid();
    return date;
  }

  static DateTime _instant(Object? raw) {
    if (raw is! String ||
        !raw.contains('T') ||
        !RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(raw)) {
      return _invalid();
    }
    return DateTime.parse(raw).toUtc();
  }

  static AdherenceSummary _summary(Object? raw) {
    final j = _object(raw);
    final value = j['adherence_rate'];
    if (value != null &&
        (value is! num || !value.isFinite || value < 0 || value > 100)) {
      return _invalid();
    }
    final result = AdherenceSummary(
      total: _count(j['total']),
      taken: _count(j['taken']),
      late: _count(j['late']),
      missed: _count(j['missed']),
      pending: _count(j['pending']),
      counted: _count(j['counted']),
      rate: (value as num?)?.toDouble(),
    );
    if (result.total != result.counted + result.pending ||
        result.counted != result.taken + result.late + result.missed ||
        (result.counted == 0) != (result.rate == null)) {
      return _invalid();
    }
    return result;
  }

  static HistoryDose _dose(Object? raw) {
    final j = _object(raw);
    final states = HistoryDoseStatus.values.where((s) => s.wire == j['status']);
    if (states.length != 1) return _invalid();
    final status = states.single;
    final actual = j['taken_at'] == null ? null : _instant(j['taken_at']);
    final source = _text(j['status_source']);
    final confirmed =
        status == HistoryDoseStatus.taken || status == HistoryDoseStatus.late;
    if (confirmed != (actual != null) ||
        !{'recorded', 'inferred'}.contains(source) ||
        (confirmed && source != 'recorded') ||
        (status == HistoryDoseStatus.pending && source != 'inferred')) {
      return _invalid();
    }
    return HistoryDose(
      medicationId: _id(j['medication_id']),
      medicationName: _text(j['medication_name']),
      scheduleId: _id(j['schedule_id']),
      scheduledAt: _instant(j['scheduled_at']),
      takenAt: actual,
      status: status,
      statusSource: source,
    );
  }

  static AdherenceHistory parse(Object? raw) {
    final j = _object(raw);
    final modes = HistoryMode.values.where((m) => m.wire == j['group_by']);
    if (modes.length != 1 || j['timezone'] != 'Asia/Ho_Chi_Minh') {
      return _invalid();
    }
    final mode = modes.single;
    final summary = _summary(j['summary']);
    final dates = <DateHistoryGroup>[];
    final medications = <MedicationHistoryGroup>[];
    final keys = <String>{};
    final groupKeys = <String>{};
    final sums = List<int>.filled(5, 0);
    final from = _date(j['from']);
    final to = _date(j['to']);
    final asOf = _instant(j['as_of']);
    if (from.isAfter(to) || to.difference(from).inDays >= 90) return _invalid();
    for (final rawGroup in _list(j['groups'])) {
      final group = _object(rawGroup);
      final groupSummary = _summary(group['summary']);
      final doses = _list(group['doses']).map(_dose).toList();
      final counts = List<int>.filled(4, 0);
      if (doses.isEmpty || doses.length != groupSummary.total) {
        return _invalid();
      }
      for (final dose in doses) {
        if (!keys.add(
                '${dose.scheduleId}/${dose.scheduledAt.toIso8601String()}') ||
            dose.scheduledAt.isAfter(asOf)) {
          return _invalid();
        }
        counts[dose.status.index]++;
        final vn = dose.scheduledAt.add(const Duration(hours: 7));
        final day = DateTime.utc(vn.year, vn.month, vn.day);
        if (day.isBefore(from) || day.isAfter(to)) return _invalid();
        if (mode == HistoryMode.date && dateString(day) != group['date']) {
          return _invalid();
        }
        if (mode == HistoryMode.medication &&
            dose.medicationId != group['medication_id']) {
          return _invalid();
        }
      }
      final expected = [
        groupSummary.taken,
        groupSummary.late,
        groupSummary.missed,
        groupSummary.pending
      ];
      for (var i = 0; i < 4; i++) {
        if (counts[i] != expected[i]) return _invalid();
        sums[i] += counts[i];
      }
      sums[4] += doses.length;
      if (mode == HistoryMode.date) {
        final date = _date(group['date']);
        if (!groupKeys.add(dateString(date))) return _invalid();
        dates.add(DateHistoryGroup(date, groupSummary, doses));
      } else {
        final id = _id(group['medication_id']);
        if (!groupKeys.add('$id')) return _invalid();
        medications.add(MedicationHistoryGroup(
            id, _text(group['medication_name']), groupSummary, doses));
      }
    }
    final expected = [
      summary.taken,
      summary.late,
      summary.missed,
      summary.pending,
      summary.total
    ];
    for (var i = 0; i < 5; i++) {
      if (sums[i] != expected[i]) return _invalid();
    }
    return AdherenceHistory(
      patientId: _text(j['patient_id']),
      from: from,
      to: to,
      asOf: asOf,
      mode: mode,
      summary: summary,
      dates: dates,
      medications: medications,
    );
  }

  static HistoryFailure failure(ApiException error) {
    String? code;
    try {
      final body = jsonDecode(error.message);
      if (body is Map && body['detail'] is String) {
        code = body['detail'] as String;
      }
    } on FormatException {
      // A non-JSON body is classified by status, never shown to the user.
    }
    return HistoryFailure(switch (error.statusCode) {
      401 => HistoryFailureKind.unauthorized,
      403 => code == 'consent_revoked' || code == 'health_data_consent_required'
          ? HistoryFailureKind.consent
          : HistoryFailureKind.forbidden,
      422 => HistoryFailureKind.validation,
      null => HistoryFailureKind.network,
      _ => HistoryFailureKind.unavailable,
    });
  }
}
