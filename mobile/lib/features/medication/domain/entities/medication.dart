/// Thực thể thuốc của người dùng và các kiểu giá trị đi kèm.
library;

import 'pill_appearance.dart';

export 'pill_appearance.dart';

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

/// Thông tin danh mục của một thuốc cho màn "Thông tin thuốc" (S07-M2i,
/// `GET /catalog/medications/{id}`). Trường `null` khi nguồn không có; không có công dụng,
/// liều tối đa hay cảnh báo.
class DrugCatalogDetail {
  const DrugCatalogDetail({
    required this.id,
    required this.name,
    this.activeIngredient,
    this.strength,
    this.dosageForm,
    this.manufacturerName,
    this.manufacturerCountry,
    this.packagingSpec,
    this.source,
  });

  final String id;
  final String name;
  final String? activeIngredient;

  /// Văn bản thô của danh mục, ví dụ "500mg" hay "0,04"; không quy đổi (QD-38).
  final String? strength;
  final String? dosageForm;
  final String? manufacturerName;
  final String? manufacturerCountry;
  final String? packagingSpec;

  /// Mã nguồn của contract: `dav_drugbank`, `qd_5948`, `duoc_thu_qg`.
  final String? source;
}

/// Các ngày trong tuần chuẩn ISO-8601 (`1` = Thứ Hai .. `7` = Chủ Nhật).
const List<int> allDaysOfWeek = [1, 2, 3, 4, 5, 6, 7];

/// Trạng thái tổng hợp của nhắc nhở trên các lịch đang mở của thuốc.
enum MedicationReminderState { allEnabled, allDisabled, partial, none }

/// Một dòng lịch uống đang mở của thuốc (`schedules[]` từ API).
class MedicationScheduleEntry {
  const MedicationScheduleEntry({
    required this.id,
    required this.intakeTime,
    this.daysOfWeek = allDaysOfWeek,
    this.reminderEnabled = true,
  });

  final int id;
  final DoseTime intakeTime;
  final List<int> daysOfWeek;
  final bool reminderEnabled;

  MedicationScheduleEntry copyWith({
    int? id,
    DoseTime? intakeTime,
    List<int>? daysOfWeek,
    bool? reminderEnabled,
  }) =>
      MedicationScheduleEntry(
        id: id ?? this.id,
        intakeTime: intakeTime ?? this.intakeTime,
        daysOfWeek: daysOfWeek ?? this.daysOfWeek,
        reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      );
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
    this.schedules = const [],
    this.daysOfWeek = allDaysOfWeek,
    this.status = MedicationStatus.active,
    this.stockRemaining,
    this.endedOn,
    this.dosageForm,
    this.maxDosesPerDay,
    this.reminderEnabled = true,
    this.pillShape,
    this.pillColor,
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
  final List<MedicationScheduleEntry> schedules;
  final List<int> daysOfWeek;
  final MedicationStatus status;
  final int? stockRemaining;
  final DateTime? endedOn;

  /// Dạng bào chế theo danh mục, ví dụ "Viên nén"; `null` khi danh mục không ghi.
  final String? dosageForm;

  /// Chỉ có với thuốc "Khi cần": số lần dùng tối đa mỗi ngày.
  final int? maxDosesPerDay;
  final bool reminderEnabled;

  /// Hình và màu người bệnh chọn (S07-M2b); `null` = chưa chọn, hiển thị icon theo dạng bào chế.
  final PillShape? pillShape;
  final PillColor? pillColor;

  bool get isActive => status == MedicationStatus.active;

  int get enabledScheduleCount =>
      schedules.where((s) => s.reminderEnabled).length;

  MedicationReminderState get reminderState {
    if (frequency.isAsNeeded) return MedicationReminderState.none;
    if (schedules.isEmpty) {
      return reminderEnabled
          ? MedicationReminderState.allEnabled
          : MedicationReminderState.allDisabled;
    }
    final enabled = enabledScheduleCount;
    if (enabled == 0) return MedicationReminderState.allDisabled;
    if (enabled == schedules.length) return MedicationReminderState.allEnabled;
    return MedicationReminderState.partial;
  }

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
    List<MedicationScheduleEntry>? schedules,
    List<int>? daysOfWeek,
    MedicationStatus? status,
    int? stockRemaining,
    bool clearStock = false,
    DateTime? endedOn,
    String? dosageForm,
    int? maxDosesPerDay,
    bool? reminderEnabled,
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
      schedules: schedules ?? this.schedules,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      status: status ?? this.status,
      stockRemaining:
          clearStock ? null : (stockRemaining ?? this.stockRemaining),
      endedOn: endedOn ?? this.endedOn,
      dosageForm: dosageForm ?? this.dosageForm,
      maxDosesPerDay: maxDosesPerDay ?? this.maxDosesPerDay,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      pillShape: pillShape,
      pillColor: pillColor,
    );
  }

  /// Bản sao với hình/màu đặt đúng giá trị truyền vào, kể cả `null` (xóa lựa chọn).
  Medication withAppearance(PillShape? shape, PillColor? color) => Medication(
        id: id,
        catalogId: catalogId,
        name: name,
        activeIngredient: activeIngredient,
        strength: strength,
        unit: unit,
        dosePerIntake: dosePerIntake,
        frequency: frequency,
        timing: timing,
        times: times,
        schedules: schedules,
        daysOfWeek: daysOfWeek,
        status: status,
        stockRemaining: stockRemaining,
        endedOn: endedOn,
        dosageForm: dosageForm,
        maxDosesPerDay: maxDosesPerDay,
        reminderEnabled: reminderEnabled,
        pillShape: shape,
        pillColor: color,
      );
}
