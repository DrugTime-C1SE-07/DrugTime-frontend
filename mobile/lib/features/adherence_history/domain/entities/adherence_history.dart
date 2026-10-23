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
  pending('cho_xac_nhan', 'Đang chờ xác nhận');

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
    required this.counted,
    required this.rate,
  });

  final int total, taken, late, missed, pending, counted;
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
