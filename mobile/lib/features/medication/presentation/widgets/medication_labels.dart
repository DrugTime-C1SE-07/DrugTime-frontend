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

  String get daysLabel => daysOfWeekLabel(daysOfWeek);

  String get reminderLabel => reminderStateLabel(this);

  String get appearanceDisplayLabel => appearanceLabel(pillShape, pillColor);
}

const _weekdayLabels = {
  1: 'T2',
  2: 'T3',
  3: 'T4',
  4: 'T5',
  5: 'T6',
  6: 'T7',
  7: 'CN',
};

/// Hiển thị các ngày uống trong tuần chuẩn ISO 1..7 (`Hằng ngày` hoặc `T2, T4, T6`).
String daysOfWeekLabel(List<int> days) {
  final clean = days.where((d) => d >= 1 && d <= 7).toSet().toList()..sort();
  if (clean.isEmpty || clean.length == 7) return 'Hằng ngày';
  return [for (final d in clean) _weekdayLabels[d]!].join(', ');
}

/// Nhãn trạng thái nhắc nhở tổng hợp từ danh sách lịch mở.
String reminderStateLabel(Medication med) => switch (med.reminderState) {
      MedicationReminderState.allEnabled => 'Đang bật',
      MedicationReminderState.allDisabled => 'Đang tắt',
      MedicationReminderState.partial =>
        'Bật một phần (${med.enabledScheduleCount}/${med.schedules.length} giờ)',
      MedicationReminderState.none => 'Không áp dụng',
    };

/// Nhãn mô tả dạng & màu hiển thị của viên thuốc.
String appearanceLabel(PillShape? shape, PillColor? color) {
  final parts = [
    if (shape != null) shape.label,
    if (color != null) 'Màu ${color.label}',
  ];
  return parts.isEmpty ? 'Theo dạng bào chế (mặc định)' : parts.join(' · ');
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

final _numberThenUnit = RegExp(r'(\d)([a-zA-Zµμ%])');

/// Hàm lượng dễ đọc: chỉ chèn khoảng trắng giữa số và đơn vị ("500mg" → "500 mg",
/// "5mg/80mg" → "5 mg/80 mg"). Không đổi giá trị hay quy đổi đơn vị (QD-38): "0,04" giữ nguyên.
String formatStrength(String raw) =>
    raw.trim().replaceAllMapped(_numberThenUnit, (m) => '${m[1]} ${m[2]}');

/// Nhãn của mã nguồn danh mục (`CatalogMedicationDetail.source`); `null` khi không rõ nguồn.
String? sourceLabel(String? source) => switch (source) {
      'dav_drugbank' => 'Cơ sở dữ liệu dược – Cục Quản lý Dược',
      'qd_5948' => 'Danh mục theo Quyết định 5948',
      'duoc_thu_qg' => 'Dược thư Quốc gia Việt Nam',
      _ => null,
    };

/// Dòng phụ của thẻ thuốc ở các bước thêm thuốc: "500 mg · Viên nén", bỏ phần trống.
String strengthAndForm(String strength, String? dosageForm) => [
      if (strength.trim().isNotEmpty) formatStrength(strength),
      if (dosageForm != null && dosageForm.trim().isNotEmpty) dosageForm.trim(),
    ].join(' · ');
