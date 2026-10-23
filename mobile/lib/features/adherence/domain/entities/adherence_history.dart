/// Read-only adherence history returned by GET /adherence.
enum AdherenceDoseStatus {
  taken('da_uong', 'Đã uống'),
  late('uong_tre', 'Uống trễ'),
  missed('bo_lo', 'Bỏ lỡ'),
  pending('cho_xac_nhan', 'Chờ xác nhận');

  const AdherenceDoseStatus(this.apiValue, this.label);
  final String apiValue;
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

  final int total;
  final int taken;
  final int late;
  final int missed;
  final int pending;
  final int counted;
  final double? rate;
}

class AdherenceDose {
  const AdherenceDose({
    required this.medicationId,
    required this.medicationName,
    required this.scheduleId,
    required this.scheduledAt,
    required this.takenAt,
    required this.status,
  });

  final int medicationId;
  final String medicationName;
  final int scheduleId;
  final DateTime scheduledAt;
  final DateTime? takenAt;
  final AdherenceDoseStatus status;
}

class AdherenceDateGroup {
  const AdherenceDateGroup({
    required this.date,
    required this.summary,
    required this.doses,
  });

  /// Calendar date in Asia/Ho_Chi_Minh, without a time component.
  final DateTime date;
  final AdherenceSummary summary;
  final List<AdherenceDose> doses;
}

class AdherenceHistory {
  const AdherenceHistory({
    required this.patientId,
    required this.from,
    required this.to,
    required this.asOf,
    required this.summary,
    required this.groups,
  });

  final String patientId;
  final DateTime from;
  final DateTime to;
  final DateTime asOf;
  final AdherenceSummary summary;
  final List<AdherenceDateGroup> groups;

  AdherenceDateGroup? groupFor(DateTime date) {
    for (final group in groups) {
      if (sameCalendarDate(group.date, date)) return group;
    }
    return null;
  }
}

bool sameCalendarDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

DateTime vietnamWallTime(DateTime value) =>
    value.toUtc().add(const Duration(hours: 7));

String adherenceDateQuery(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
