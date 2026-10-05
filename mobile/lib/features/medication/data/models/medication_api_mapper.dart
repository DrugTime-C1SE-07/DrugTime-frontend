/// Ánh xạ giữa schema của `/medications`, `/catalog/medications` (api_contract/openapi.json)
/// và entity của app.
library;

import 'dart:convert';

import '../../../../core/api/api_exception.dart';
import '../../domain/entities/dose_unit.dart';
import '../../domain/entities/medication.dart';
import '../../domain/entities/medication_failure.dart';

abstract final class MedicationApiMapper {
  static const _timingToApi = {
    IntakeTiming.beforeMeal: 'before_meal',
    IntakeTiming.afterMeal: 'after_meal',
    IntakeTiming.anytime: 'any_time',
  };

  static final _timingFromApi = {for (final e in _timingToApi.entries) e.value: e.key};

  // ---------------------------------------------------------------- response → entity

  /// `UserMedication` → [Medication].
  static Medication medicationFromJson(Map<String, dynamic> json) {
    final drug = json['medication'] as Map<String, dynamic>;
    final dosageForm = drug['dosage_form'] as String?;
    final asNeeded = json['dosing_mode'] == 'as_needed';
    final dosesPerDay = json['doses_per_day'] as int;
    final schedules = (json['schedules'] as List).cast<Map<String, dynamic>>();
    final endedAt = json['ended_at'] as String?;
    final timing = json['intake_timing'] as String?;

    return Medication(
      id: '${json['id']}',
      catalogId: '${drug['id']}',
      name: drug['name'] as String,
      activeIngredient: drug['active_ingredient'] as String? ?? '',
      strength: drug['strength_text'] as String? ?? '',
      unit: doseUnitFor(dosageForm),
      dosePerIntake: (json['quantity_per_dose'] as num).toDouble(),
      // Thuốc đã ngừng không còn lịch mở: tần suất lấy theo doses_per_day.
      frequency: asNeeded ? DoseFrequency.asNeeded : DoseFrequency.forTimeCount(dosesPerDay),
      // Server cho phép xoá cách uống (null); app không có lựa chọn "chưa đặt" nên hiển thị
      // là "Không liên quan bữa ăn".
      timing: timing == null ? IntakeTiming.anytime : _timingFromApi[timing]!,
      times: [for (final s in schedules) _parseTime(s['intake_time'] as String)]..sort(),
      status: json['status'] == 'stopped' ? MedicationStatus.stopped : MedicationStatus.active,
      stockRemaining: json['stock_quantity'] as int?,
      endedOn: endedAt == null ? null : DateTime.parse(endedAt).toLocal(),
      dosageForm: dosageForm,
      maxDosesPerDay: asNeeded ? dosesPerDay : null,
    );
  }

  /// `UserMedicationList` → danh sách.
  static List<Medication> medicationListFromJson(Object? json) => [
        for (final item in ((json as Map<String, dynamic>)['items'] as List))
          medicationFromJson(item as Map<String, dynamic>),
      ];

  /// `CatalogMedicationSummary` → [DrugCatalogItem].
  static DrugCatalogItem catalogItemFromJson(Map<String, dynamic> json) {
    final dosageForm = json['dosage_form'] as String?;
    return DrugCatalogItem(
      id: '${json['id']}',
      name: json['name'] as String,
      activeIngredient: json['active_ingredient'] as String? ?? '',
      strength: json['strength_text'] as String? ?? '',
      dosageForm: dosageForm ?? '',
      unit: doseUnitFor(dosageForm),
    );
  }

  static List<DrugCatalogItem> catalogListFromJson(Object? json) => [
        for (final item in ((json as Map<String, dynamic>)['items'] as List))
          catalogItemFromJson(item as Map<String, dynamic>),
      ];

  // ---------------------------------------------------------------- entity → request

  /// Body của `POST /medications`.
  static Map<String, Object?> createBody(Medication draft, String clientUuid) {
    final asNeeded = draft.frequency.isAsNeeded;
    return {
      'client_uuid': clientUuid,
      'medication_id': int.parse(draft.catalogId),
      'quantity_per_dose': draft.dosePerIntake,
      'dosing_mode': asNeeded ? 'as_needed' : 'scheduled',
      if (asNeeded) 'max_doses_per_day': draft.maxDosesPerDay ?? defaultMaxDosesPerDay,
      if (!asNeeded) 'intake_times': _times(draft.times),
      'intake_timing': _timingToApi[draft.timing],
      if (draft.stockRemaining != null) 'stock_quantity': draft.stockRemaining,
    };
  }

  /// Body của `PATCH /medications/{id}`: chỉ field của [after] khác [before]. Đổi chế độ
  /// uống gửi kèm field bắt buộc của chế độ mới. Rỗng khi không có gì đổi.
  static Map<String, Object?> patchBody(Medication before, Medication after) {
    final body = <String, Object?>{};
    if (after.dosePerIntake != before.dosePerIntake) {
      body['quantity_per_dose'] = after.dosePerIntake;
    }
    if (after.timing != before.timing) body['intake_timing'] = _timingToApi[after.timing];
    if (after.stockRemaining != before.stockRemaining) {
      body['stock_quantity'] = after.stockRemaining;
    }

    final wasAsNeeded = before.frequency.isAsNeeded;
    final isAsNeeded = after.frequency.isAsNeeded;
    if (isAsNeeded) {
      final max = after.maxDosesPerDay ?? defaultMaxDosesPerDay;
      if (!wasAsNeeded) body['dosing_mode'] = 'as_needed';
      if (!wasAsNeeded || max != before.maxDosesPerDay) body['max_doses_per_day'] = max;
    } else {
      final times = _times(after.times);
      if (wasAsNeeded) body['dosing_mode'] = 'scheduled';
      if (wasAsNeeded || !_sameList(times, _times(before.times))) body['intake_times'] = times;
    }
    return body;
  }

  // ---------------------------------------------------------------- lỗi

  /// Dịch lỗi HTTP theo mã trạng thái và `detail` của contract.
  static MedicationFailure failureFrom(ApiException error) {
    final status = error.statusCode;
    if (status == null || error.isTransient) {
      return MedicationFailure(MedicationFailureKind.network, error.message);
    }
    final detail = _detail(error.message);
    final kind = switch ((status, detail)) {
      (401, _) => MedicationFailureKind.unauthorized,
      (403, 'consent_revoked') => MedicationFailureKind.consentRevoked,
      (403, _) => MedicationFailureKind.forbidden,
      (404, _) => MedicationFailureKind.notFound,
      (422, 'catalog_medication_not_found') => MedicationFailureKind.catalogNotFound,
      (422, 'medication_rule_violation') => MedicationFailureKind.ruleViolation,
      (422, 'medication_stopped') => MedicationFailureKind.stopped,
      (422, _) => MedicationFailureKind.validation,
      _ => MedicationFailureKind.unknown,
    };
    return MedicationFailure(kind, error.message);
  }

  /// `detail` dạng chuỗi mã; `null` khi body không phải JSON hoặc `detail` là mảng lỗi field.
  static String? _detail(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['detail'] is String) return decoded['detail'] as String;
    } on FormatException {
      return null;
    }
    return null;
  }

  static List<String> _times(List<DoseTime> times) =>
      ([...times]..sort()).map((t) => t.format()).toList();

  static bool _sameList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static DoseTime _parseTime(String hhmm) {
    final parts = hhmm.split(':');
    return DoseTime(int.parse(parts[0]), int.parse(parts[1]));
  }
}
