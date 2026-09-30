import '../../domain/entities/medication.dart';

/// Chuỗi hiển thị cho thuốc — gom một chỗ để các màn dùng cùng cách nói.
extension MedicationLabels on Medication {
  String get doseLabel => '$dosePerIntake $unit';

  String get scheduleSummary => frequency.isAsNeeded
      ? '$doseLabel · Khi cần'
      : '$doseLabel · ${frequency.label} · ${timing.label}';

  String get timesLabel => times.map((t) => t.format()).join('  ·  ');

  String? get stockLabel {
    final stock = stockRemaining;
    return stock == null ? null : 'Còn $stock $unit';
  }
}

String formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/${date.year}';
