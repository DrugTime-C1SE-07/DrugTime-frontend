/// Thực thể thuốc của người dùng và các kiểu giá trị đi kèm.
library;

enum MedicationStatus { active, stopped }

enum IntakeTiming {
  beforeMeal('Trước ăn'),
  afterMeal('Sau ăn'),
  anytime('Không liên quan bữa ăn');

  const IntakeTiming(this.label);

  final String label;
}

enum DoseFrequency {
  once('1 lần/ngày', [DoseTime(8, 0)]),
  twice('2 lần/ngày', [DoseTime(8, 0), DoseTime(20, 0)]),
  thrice('3 lần/ngày', [DoseTime(7, 0), DoseTime(12, 0), DoseTime(19, 0)]),
  asNeeded('Khi cần', []);

  const DoseFrequency(this.label, this.defaultTimes);

  final String label;

  /// Giờ uống gợi ý khi chọn tần suất; người dùng chỉnh lại được.
  final List<DoseTime> defaultTimes;

  bool get isAsNeeded => this == DoseFrequency.asNeeded;
}

/// Giờ trong ngày, không phụ thuộc Flutter để domain thuần Dart.
class DoseTime implements Comparable<DoseTime> {
  const DoseTime(this.hour, this.minute);

  final int hour;
  final int minute;

  int get minutesOfDay => hour * 60 + minute;

  String format() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  @override
  int compareTo(DoseTime other) => minutesOfDay.compareTo(other.minutesOfDay);

  @override
  bool operator ==(Object other) =>
      other is DoseTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);

  @override
  String toString() => format();
}

/// Một mục trong danh mục thuốc (DAV / Dược thư) — nguồn để kiểm tra tương tác.
class DrugCatalogItem {
  const DrugCatalogItem({
    required this.id,
    required this.name,
    required this.activeIngredient,
    required this.strength,
    required this.dosageForm,
    this.unit = 'viên',
  });

  final String id;
  final String name;
  final String activeIngredient;
  final String strength;
  final String dosageForm;

  /// Đơn vị đếm liều: viên, gói, ml…
  final String unit;
}

class Medication {
  const Medication({
    required this.id,
    required this.catalogId,
    required this.name,
    required this.activeIngredient,
    required this.strength,
    required this.unit,
    required this.dosePerIntake,
    required this.frequency,
    required this.timing,
    this.times = const [],
    this.status = MedicationStatus.active,
    this.stockRemaining,
    this.endedOn,
  });

  /// Còn từ ngần này đơn vị trở xuống thì coi là sắp hết.
  static const lowStockThreshold = 5;

  final String id;
  final String catalogId;
  final String name;
  final String activeIngredient;
  final String strength;
  final String unit;
  final int dosePerIntake;
  final DoseFrequency frequency;
  final IntakeTiming timing;
  final List<DoseTime> times;
  final MedicationStatus status;
  final int? stockRemaining;
  final DateTime? endedOn;

  bool get isActive => status == MedicationStatus.active;

  bool get isLowStock {
    final stock = stockRemaining;
    return isActive && stock != null && stock <= lowStockThreshold;
  }
}
