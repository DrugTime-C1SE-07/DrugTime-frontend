import '../../domain/entities/adherence_demo_preset.dart';
import '../../domain/entities/adherence_history.dart';
import '../../domain/entities/adherence_history_failure.dart';
import 'adherence_history_api_mapper.dart';

/// Synthetic fixtures, never used as a fallback for the remote repository.
abstract final class AdherenceDemoFixtures {
  static const patientId = 'adherence-demo';
  static const _names = {
    7: 'Metformin 500 mg',
    8: 'Vitamin D3 1000 IU',
    9: 'Losartan 50 mg',
    10: 'Thuốc mô phỏng tên dài Metformin Hydrochloride giải phóng kéo dài 500 mg',
    11: 'Vitamin C 500 mg',
    12: 'Thuốc mô phỏng F',
    13: 'Metformin 500 mg',
  };

  static DateTime _day(DateTime instant) {
    final vn = instant.toUtc().add(const Duration(hours: 7));
    return DateTime.utc(vn.year, vn.month, vn.day);
  }

  static String _wireTime(DateTime instant) =>
      '${instant.toUtc().add(const Duration(hours: 7)).toIso8601String().replaceFirst('Z', '')}+07:00';

  static Map<String, dynamic> _dose(int id, int medicationId,
          DateTime scheduled, HistoryDoseStatus status,
          {DateTime? actual}) =>
      {
        'schedule_id': id,
        'medication_id': medicationId,
        'medication_name': _names[medicationId]!,
        'scheduled_at': _wireTime(scheduled),
        'taken_at': switch (status) {
          HistoryDoseStatus.taken =>
            _wireTime(actual ?? scheduled.add(const Duration(minutes: 5))),
          HistoryDoseStatus.late =>
            _wireTime(actual ?? scheduled.add(const Duration(minutes: 45))),
          _ => null,
        },
        'status': status.wire,
        'status_source': status == HistoryDoseStatus.pending ||
                status == HistoryDoseStatus.unverified
            ? 'inferred'
            : 'recorded',
      };

  static List<Map<String, dynamic>> _rows(
      AdherenceDemoPreset preset, DateTime clock) {
    final today = _day(clock);
    DateTime at(int month, int day, int hour, [int minute = 0]) {
      final date = month == 9
          ? DateTime.utc(today.year, today.month, -1)
          : today.add(Duration(days: day - 22));
      return DateTime.utc(date.year, date.month, date.day, hour - 7, minute);
    }

    if (preset == AdherenceDemoPreset.empty) return [];
    if (preset == AdherenceDemoPreset.longList) {
      return [
        for (var i = 0; i < 24; i++)
          _dose(
              2000 + i,
              7 + i % 6,
              switch (i ~/ 6) {
                0 => at(10, 22, 7, i * 5),
                1 => at(10, 22, 8, (i - 6) * 5),
                2 => at(10, 22, 10, (i - 12) * 10),
                _ => at(10, 22, 12, 30 + (i - 18) * 10),
              },
              HistoryDoseStatus.values[i ~/ 6]),
      ];
    }
    final statuses = switch (preset) {
      AdherenceDemoPreset.allTaken => List.filled(4, HistoryDoseStatus.taken),
      AdherenceDemoPreset.allLate => List.filled(4, HistoryDoseStatus.late),
      AdherenceDemoPreset.someMissed => [
          HistoryDoseStatus.taken,
          HistoryDoseStatus.taken,
          HistoryDoseStatus.late,
          HistoryDoseStatus.missed
        ],
      AdherenceDemoPreset.allMissed => List.filled(3, HistoryDoseStatus.missed),
      AdherenceDemoPreset.pendingOnly =>
        List.filled(3, HistoryDoseStatus.pending),
      _ => [
          HistoryDoseStatus.taken,
          HistoryDoseStatus.taken,
          HistoryDoseStatus.taken,
          HistoryDoseStatus.late,
          HistoryDoseStatus.missed,
          HistoryDoseStatus.pending
        ],
    };
    final rows = <Map<String, dynamic>>[
      for (var i = 0; i < statuses.length; i++)
        _dose(
            1000 + i,
            7 + i,
            statuses[i] == HistoryDoseStatus.pending
                ? at(10, 22, 13, i * 5)
                : at(10, 22, i < 2 ? 7 : 6 + i),
            statuses[i]),
    ];
    if (preset == AdherenceDemoPreset.mixed ||
        preset == AdherenceDemoPreset.loading ||
        preset == AdherenceDemoPreset.networkError) {
      for (var d = 0; d < 5; d++) {
        final date = today.subtract(Duration(days: 3 + d * 2));
        for (var i = 0; i < 4; i++) {
          rows.add(_dose(
              3000 + d * 4 + i,
              7 + (d + i) % 7,
              DateTime.utc(date.year, date.month, date.day, i + 1),
              HistoryDoseStatus.values[(d + i) % 3]));
        }
      }
      rows.addAll([
        _dose(1100, 7, at(10, 21, 23, 30), HistoryDoseStatus.late,
            actual: at(10, 22, 0, 10)),
        _dose(1101, 8, at(10, 20, 8), HistoryDoseStatus.taken),
        _dose(1103, 13, at(10, 20, 9), HistoryDoseStatus.taken),
        _dose(1102, 13, at(9, 29, 9), HistoryDoseStatus.taken),
      ]);
    }
    return rows;
  }

  static Map<String, dynamic> _summary(List<Map<String, dynamic>> rows) {
    final counts = [
      for (final status in HistoryDoseStatus.values)
        rows.where((row) => row['status'] == status.wire).length
    ];
    final counted = counts[0] + counts[1] + counts[2];
    return {
      'total': rows.length,
      'taken': counts[0],
      'late': counts[1],
      'missed': counts[2],
      'pending': counts[3],
      'unverified': counts[4],
      'counted': counted,
      'adherence_rate': counted == 0
          ? null
          : double.parse(
              (100 * (counts[0] + counts[1]) / counted).toStringAsFixed(2)),
    };
  }

  static AdherenceHistory build(AdherenceDemoPreset preset,
      {required DateTime from,
      required DateTime to,
      required HistoryMode mode,
      DateTime? clock}) {
    clock ??= preset.clock;
    if (from.year < 1 ||
        from.isAfter(to) ||
        to.difference(from).inDays >= 90 ||
        to.isAfter(_day(clock))) {
      throw const HistoryFailure(HistoryFailureKind.validation);
    }
    final rows = _rows(preset, clock).where((row) {
      final at = DateTime.parse(row['scheduled_at'] as String);
      final day = _day(at);
      return !at.isAfter(clock!) && !day.isBefore(from) && !day.isAfter(to);
    }).toList()
      ..sort((a, b) {
        final order = DateTime.parse(a['scheduled_at'] as String)
            .compareTo(DateTime.parse(b['scheduled_at'] as String));
        return order != 0
            ? order
            : (a['schedule_id'] as int).compareTo(b['schedule_id'] as int);
      });
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final row in rows) {
      final key = mode == HistoryMode.date
          ? AdherenceHistoryApiMapper.dateString(
              _day(DateTime.parse(row['scheduled_at'] as String)))
          : '${row['medication_id']}';
      grouped.putIfAbsent(key, () => []).add(row);
    }
    return AdherenceHistoryApiMapper.parse({
      'patient_id': patientId,
      'from': AdherenceHistoryApiMapper.dateString(from),
      'to': AdherenceHistoryApiMapper.dateString(to),
      'group_by': mode.wire,
      'timezone': 'Asia/Ho_Chi_Minh',
      'as_of': _wireTime(clock),
      'summary': _summary(rows),
      'groups': [
        for (final entry in grouped.entries)
          {
            if (mode == HistoryMode.date) 'date': entry.key,
            if (mode == HistoryMode.medication) ...{
              'medication_id': entry.value.first['medication_id'],
              'medication_name': entry.value.first['medication_name'],
            },
            'summary': _summary(entry.value),
            'doses': entry.value,
          }
      ],
    });
  }
}
