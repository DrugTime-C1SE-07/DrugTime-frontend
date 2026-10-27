enum HistoryMode {
  date('date'),
  medication('medication');

  const HistoryMode(this.wire);
  final String wire;
}

enum HistoryDoseStatus {
  taken('da_uong', 'Đã uống'),
  late('uong_tre', 'Uống trễ'),
  missed('bo_lo', 'Bỏ lỡ'),
  pending('cho_xac_nhan', 'Đang chờ xác nhận'),

  /// Quá hạn chót nhưng điện thoại chưa đồng bộ lại (task 3.19). Đặt cuối để giữ chỉ số cũ.
  unverified('chua_xac_minh', 'Chưa xác minh');

  const HistoryDoseStatus(this.wire, this.label);
  final String wire;
  final String label;
}

class AdherenceSummary {
  const AdherenceSummary({
    required this.total,
    required this.taken,
    required this.late,
    required this.missed,
    required this.pending,
    this.unverified = 0,
    required this.counted,
    required this.rate,
  });

  /// unverified: liều `chua_xac_minh`, không vào tỷ lệ; total = counted + pending + unverified.
  final int total, taken, late, missed, pending, unverified, counted;
  final double? rate;
}

class HistoryDose {
  const HistoryDose({
    required this.medicationId,
    required this.medicationName,
    required this.scheduleId,
    required this.scheduledAt,
    required this.takenAt,
    required this.status,
    required this.statusSource,
  });

  final int medicationId, scheduleId;
  final String medicationName, statusSource;
  final DateTime scheduledAt;
  final DateTime? takenAt;
  final HistoryDoseStatus status;
}

class DateHistoryGroup {
  DateHistoryGroup(this.date, this.summary, Iterable<HistoryDose> doses)
      : doses = List.unmodifiable(doses);
  final DateTime date;
  final AdherenceSummary summary;
  final List<HistoryDose> doses;
}

class MedicationHistoryGroup {
  MedicationHistoryGroup(
      this.medicationId, this.name, this.summary, Iterable<HistoryDose> doses)
      : doses = List.unmodifiable(doses);
  final int medicationId;
  final String name;
  final AdherenceSummary summary;
  final List<HistoryDose> doses;
}

class AdherenceHistory {
  AdherenceHistory({
    required this.patientId,
    required this.from,
    required this.to,
    required this.asOf,
    required this.mode,
    required this.summary,
    Iterable<DateHistoryGroup> dates = const [],
    Iterable<MedicationHistoryGroup> medications = const [],
  })  : dates = List.unmodifiable(dates),
        medications = List.unmodifiable(medications);

  final String patientId;
  final DateTime from, to, asOf;
  final HistoryMode mode;
  final AdherenceSummary summary;
  final List<DateHistoryGroup> dates;
  final List<MedicationHistoryGroup> medications;
}
