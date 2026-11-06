/// Tiện ích đo lường độ đúng giờ thông báo (Task 2.09 / NFR04/05).
/// Đo lường độ lệch thời gian: delta_ms = actual_time - target_time.
/// Tiêu chuẩn NFR: |delta_ms| <= 2000ms với tỷ lệ >= 99%.
class ReminderBenchmarkRecord {
  const ReminderBenchmarkRecord({
    required this.notificationId,
    required this.targetTime,
    required this.actualTime,
    required this.deltaMs,
    this.deviceState,
  });

  final int notificationId;
  final DateTime targetTime;
  final DateTime actualTime;
  final int deltaMs;
  final String? deviceState;

  bool get isCompliant => deltaMs.abs() <= 2000;

  Map<String, dynamic> toJson() => {
        'notification_id': notificationId,
        'target_time': targetTime.toUtc().toIso8601String(),
        'actual_time': actualTime.toUtc().toIso8601String(),
        'delta_ms': deltaMs,
        'is_compliant': isCompliant,
        if (deviceState != null) 'device_state': deviceState,
      };
}

class ReminderBenchmarkLogger {
  ReminderBenchmarkLogger({
    this.maxAllowedDeltaMs = 2000,
    this.targetComplianceRate = 0.99,
  });

  final int maxAllowedDeltaMs;
  final double targetComplianceRate;

  final List<ReminderBenchmarkRecord> _records = [];

  List<ReminderBenchmarkRecord> get records => List.unmodifiable(_records);

  ReminderBenchmarkRecord record({
    required int notificationId,
    required DateTime targetTime,
    required DateTime actualTime,
    String? deviceState,
  }) {
    final deltaMs = actualTime.difference(targetTime).inMilliseconds;
    final entry = ReminderBenchmarkRecord(
      notificationId: notificationId,
      targetTime: targetTime,
      actualTime: actualTime,
      deltaMs: deltaMs,
      deviceState: deviceState,
    );
    _records.add(entry);
    return entry;
  }

  int get totalSamples => _records.length;

  int get compliantSamples =>
      _records.where((r) => r.deltaMs.abs() <= maxAllowedDeltaMs).length;

  int get violatedSamples => totalSamples - compliantSamples;

  double get complianceRate =>
      totalSamples == 0 ? 1.0 : compliantSamples / totalSamples;

  double get meanDelayMs {
    if (_records.isEmpty) return 0.0;
    final sum = _records.fold<int>(0, (acc, r) => acc + r.deltaMs.abs());
    return sum / _records.length;
  }

  int get maxDelayMs {
    if (_records.isEmpty) return 0;
    return _records
        .map((r) => r.deltaMs.abs())
        .reduce((a, b) => a > b ? a : b);
  }

  int get minDelayMs {
    if (_records.isEmpty) return 0;
    return _records
        .map((r) => r.deltaMs.abs())
        .reduce((a, b) => a < b ? a : b);
  }

  bool get meetsNfrRequirement =>
      totalSamples > 0 && complianceRate >= targetComplianceRate;

  void clear() => _records.clear();

  String toCsv() {
    final buffer = StringBuffer(
      'notification_id,target_time,actual_time,delta_ms,is_compliant,device_state\n',
    );
    for (final r in _records) {
      buffer.writeln(
        '${r.notificationId},${r.targetTime.toIso8601String()},${r.actualTime.toIso8601String()},${r.deltaMs},${r.isCompliant},${r.deviceState ?? ""}',
      );
    }
    return buffer.toString();
  }
}
