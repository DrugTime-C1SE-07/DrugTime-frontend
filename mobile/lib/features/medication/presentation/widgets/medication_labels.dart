import '../../domain/entities/medication.dart';

/// Chuỗi hiển thị cho thuốc — gom một chỗ để các màn dùng cùng cách nói.
extension MedicationLabels on Medication {
  String get doseLabel => '${formatQuantity(dosePerIntake)} $unit';

  /// Nhãn tần suất; thuốc 4–6 lần/ngày hiện đúng số lần.
  String get frequencyLabel {
    if (frequency == DoseFrequency.custom) {
      final count = times.isEmpty ? null : times.length;
      return count == null ? frequency.label : '$count lần/ngày';
    }
    return frequency.label;
  }

  /// "Tối đa 3 lần/ngày" với thuốc "Khi cần"; `null` với thuốc theo giờ.
  String? get maxDosesLabel {
    final max = maxDosesPerDay;
    return frequency.isAsNeeded && max != null ? 'Tối đa $max lần/ngày' : null;
  }

  String get scheduleSummary => frequency.isAsNeeded
      ? '$doseLabel · Khi cần'
      : '$doseLabel · $frequencyLabel · ${timing.label}';

  String get timesLabel => times.map((t) => t.format()).join('  ·  ');

  String? get stockLabel {
    final stock = stockRemaining;
    return stock == null ? null : 'Còn $stock $unit';
  }
}

String formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/${date.year}';

/// Số lượng kiểu Việt Nam: bỏ phần thập phân `.0`, dấu phẩy thập phân (1 → "1", 0.5 → "0,5").
String formatQuantity(num value) {
  if (value == value.roundToDouble()) return value.round().toString();
  var text = value.toStringAsFixed(2);
  text = text.replaceFirst(RegExp(r'0+$'), '');
  return text.replaceAll('.', ',');
}

/// Dòng phụ dưới tên thuốc: "Hoạt chất · Dạng bào chế", bỏ phần trống.
String drugSubtitle(String activeIngredient, String? dosageForm) {
  final parts = [
    activeIngredient.isEmpty ? 'Chưa có thông tin hoạt chất' : activeIngredient,
    if (dosageForm != null && dosageForm.isNotEmpty) dosageForm,
  ];
  return parts.join(' · ');
}
