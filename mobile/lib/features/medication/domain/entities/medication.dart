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
  asNeeded('Khi cần', []),

  /// Thuốc theo giờ có 4–6 lần/ngày (server cho tối đa 6). Không có trong danh sách để
  /// người dùng chọn; nhãn hiển thị lấy theo số giờ (`frequencyLabel`).
  custom('Nhiều lần/ngày', []);

  const DoseFrequency(this.label, this.defaultTimes);

  final String label;

  /// Giờ uống gợi ý khi chọn tần suất; người dùng chỉnh lại được.
  final List<DoseTime> defaultTimes;

  bool get isAsNeeded => this == DoseFrequency.asNeeded;

  /// Các tần suất hiện trên form thêm/sửa.
  static const selectable = [once, twice, thrice, asNeeded];

  /// Tần suất của thuốc theo giờ có [count] giờ uống.
  static DoseFrequency forTimeCount(int count) => switch (count) {
        1 => once,
        2 => twice,
        3 => thrice,
        _ => custom,
      };
}

/// Số lần dùng tối đa mỗi ngày của thuốc "Khi cần" (khớp contract: 1–6).
const minMaxDosesPerDay = 1;
const maxMaxDosesPerDay = 6;
const defaultMaxDosesPerDay = 3;

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

  /// Rỗng khi danh mục chưa có thông tin hoạt chất.
  final String activeIngredient;
  final String strength;
  final String dosageForm;

  /// Đơn vị đếm liều: viên, gói, ml… suy ra từ [dosageForm] (xem `doseUnitFor`).
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
    this.dosageForm,
    this.maxDosesPerDay,
  });

  /// Còn từ ngần này đơn vị trở xuống thì coi là sắp hết.
  static const lowStockThreshold = 5;

  final String id;
  final String catalogId;
  final String name;

  /// Rỗng khi danh mục chưa có thông tin hoạt chất.
  final String activeIngredient;
  final String strength;
  final String unit;

  /// Số đơn vị mỗi lần dùng; server cho phép số lẻ (0 < liều ≤ 10), ví dụ 0.5 viên.
  final double dosePerIntake;
  final DoseFrequency frequency;
  final IntakeTiming timing;
  final List<DoseTime> times;
  final MedicationStatus status;
  final int? stockRemaining;
  final DateTime? endedOn;

  /// Dạng bào chế theo danh mục, ví dụ "Viên nén"; `null` khi danh mục không ghi.
  final String? dosageForm;

  /// Chỉ có với thuốc "Khi cần": số lần dùng tối đa mỗi ngày.
  final int? maxDosesPerDay;

  bool get isActive => status == MedicationStatus.active;

  bool get isLowStock {
    final stock = stockRemaining;
    return isActive && stock != null && stock <= lowStockThreshold;
  }

  Medication copyWith({
    String? id,
    String? catalogId,
    String? name,
    String? activeIngredient,
    String? strength,
    String? unit,
    double? dosePerIntake,
    DoseFrequency? frequency,
    IntakeTiming? timing,
    List<DoseTime>? times,
    MedicationStatus? status,
    int? stockRemaining,
    DateTime? endedOn,
    String? dosageForm,
    int? maxDosesPerDay,
  }) {
    return Medication(
      id: id ?? this.id,
      catalogId: catalogId ?? this.catalogId,
      name: name ?? this.name,
      activeIngredient: activeIngredient ?? this.activeIngredient,
      strength: strength ?? this.strength,
      unit: unit ?? this.unit,
      dosePerIntake: dosePerIntake ?? this.dosePerIntake,
      frequency: frequency ?? this.frequency,
      timing: timing ?? this.timing,
      times: times ?? this.times,
      status: status ?? this.status,
      stockRemaining: stockRemaining ?? this.stockRemaining,
      endedOn: endedOn ?? this.endedOn,
      dosageForm: dosageForm ?? this.dosageForm,
      maxDosesPerDay: maxDosesPerDay ?? this.maxDosesPerDay,
    );
  }
}
