import 'package:drugtime_mobile/core/api/api_exception.dart';
import 'package:drugtime_mobile/features/medication/data/models/medication_api_mapper.dart';
import 'package:drugtime_mobile/features/medication/domain/entities/medication.dart';
import 'package:drugtime_mobile/features/medication/domain/entities/medication_failure.dart';
import 'package:flutter_test/flutter_test.dart';

/// `UserMedication` theo example của api_contract/openapi.json.
Map<String, dynamic> userMedicationJson({
  String mode = 'scheduled',
  List<String> times = const ['20:00', '08:00'],
  int dosesPerDay = 2,
  String status = 'active',
  String? endedAt,
  String? timing = 'after_meal',
  int? stock = 30,
  num quantity = 1,
  String? activeIngredient = 'Amlodipin besilat',
  String? dosageForm = 'Viên nén',
}) =>
    {
      'id': 42,
      'medication': {
        'id': 1007,
        'name': 'Amlodipin 5mg',
        'active_ingredient': activeIngredient,
        'strength_text': '5 mg',
        'dosage_form': dosageForm,
      },
      'dosing_mode': mode,
      'quantity_per_dose': quantity,
      'doses_per_day': dosesPerDay,
      'intake_timing': timing,
      'stock_quantity': stock,
      'has_interaction_data': true,
      'status': status,
      'ended_at': endedAt,
      'schedules': [
        for (final (i, t) in times.indexed)
          {
            'id': 300 + i,
            'intake_time': t,
            'days_of_week': [1, 2, 3, 4, 5, 6, 7],
            'reminder_enabled': true,
            'effective_from': '2026-10-01T09:15:02+07:00',
          },
      ],
    };

Medication base({
  DoseFrequency frequency = DoseFrequency.twice,
  List<DoseTime> times = const [DoseTime(8, 0), DoseTime(20, 0)],
  int? maxDoses,
  int? stock = 30,
}) =>
    Medication(
      id: '42',
      catalogId: '1007',
      name: 'Amlodipin 5mg',
      activeIngredient: 'Amlodipin besilat',
      strength: '5 mg',
      unit: 'viên',
      dosePerIntake: 1,
      frequency: frequency,
      timing: IntakeTiming.afterMeal,
      times: times,
      stockRemaining: stock,
      maxDosesPerDay: maxDoses,
    );

void main() {
  group('response → entity (AC7)', () {
    test('thuốc theo giờ 08:00/20:00, sau ăn, tồn 30', () {
      final m = MedicationApiMapper.medicationFromJson(userMedicationJson());
      expect(m.id, '42');
      expect(m.catalogId, '1007');
      expect(m.frequency, DoseFrequency.twice);
      expect(m.times, const [DoseTime(8, 0), DoseTime(20, 0)]);
      expect(m.timing, IntakeTiming.afterMeal);
      expect(m.stockRemaining, 30);
      expect(m.isActive, isTrue);
      expect(m.activeIngredient, 'Amlodipin besilat');
      expect(m.dosageForm, 'Viên nén');
      expect(m.unit, 'viên');
      expect(m.maxDosesPerDay, isNull);
    });

    test('1 và 3 giờ → once/thrice; 5 giờ → custom', () {
      expect(
        MedicationApiMapper.medicationFromJson(userMedicationJson(times: ['07:00'], dosesPerDay: 1))
            .frequency,
        DoseFrequency.once,
      );
      expect(
        MedicationApiMapper.medicationFromJson(
          userMedicationJson(times: ['07:00', '12:00', '19:00'], dosesPerDay: 3),
        ).frequency,
        DoseFrequency.thrice,
      );
      final five = MedicationApiMapper.medicationFromJson(
        userMedicationJson(
          times: ['06:00', '09:00', '12:00', '15:00', '18:00'],
          dosesPerDay: 5,
        ),
      );
      expect(five.frequency, DoseFrequency.custom);
      expect(five.times, hasLength(5));
    });

    test('as_needed → asNeeded, maxDosesPerDay = doses_per_day, không có giờ', () {
      final m = MedicationApiMapper.medicationFromJson(
        userMedicationJson(mode: 'as_needed', times: [], dosesPerDay: 3, stock: null),
      );
      expect(m.frequency, DoseFrequency.asNeeded);
      expect(m.maxDosesPerDay, 3);
      expect(m.times, isEmpty);
      expect(m.stockRemaining, isNull);
    });

    test('đã ngừng: status, endedOn; tần suất lấy theo doses_per_day vì không còn lịch mở', () {
      final m = MedicationApiMapper.medicationFromJson(
        userMedicationJson(status: 'stopped', endedAt: '2026-10-05T07:30:00+07:00', times: []),
      );
      expect(m.isActive, isFalse);
      expect(m.endedOn, DateTime.utc(2026, 10, 5, 0, 30).toLocal());
      expect(m.frequency, DoseFrequency.twice);
    });

    test('active_ingredient/dosage_form null, liều 0.5, cách uống null', () {
      final m = MedicationApiMapper.medicationFromJson(
        userMedicationJson(activeIngredient: null, dosageForm: null, quantity: 0.5, timing: null),
      );
      expect(m.activeIngredient, '');
      expect(m.dosageForm, isNull);
      expect(m.unit, 'liều');
      expect(m.dosePerIntake, 0.5);
      expect(m.timing, IntakeTiming.anytime);
    });

    test('danh sách đọc items; danh mục map đơn vị theo dạng bào chế', () {
      final list = MedicationApiMapper.medicationListFromJson({
        'items': [userMedicationJson(), userMedicationJson()],
      });
      expect(list, hasLength(2));

      final items = MedicationApiMapper.catalogListFromJson({
        'items': [
          {
            'id': 5003,
            'name': 'Thuốc ho Bảo Thanh',
            'active_ingredient': null,
            'strength_text': null,
            'dosage_form': 'Siro',
          },
        ],
      });
      expect(items.single.id, '5003');
      expect(items.single.activeIngredient, '');
      expect(items.single.strength, '');
      expect(items.single.unit, 'ml');
    });
  });

  group('entity → POST body', () {
    test('theo giờ: intake_times đã sắp xếp, không có max_doses_per_day', () {
      final body = MedicationApiMapper.createBody(
        base(times: const [DoseTime(20, 0), DoseTime(8, 0)]),
        'uuid-1',
      );
      expect(body, {
        'client_uuid': 'uuid-1',
        'medication_id': 1007,
        'quantity_per_dose': 1.0,
        'dosing_mode': 'scheduled',
        'intake_times': ['08:00', '20:00'],
        'intake_timing': 'after_meal',
        'stock_quantity': 30,
      });
    });

    test('khi cần: max_doses_per_day, không có intake_times; không có tồn kho thì bỏ field', () {
      final body = MedicationApiMapper.createBody(
        base(frequency: DoseFrequency.asNeeded, times: const [], maxDoses: 4, stock: null),
        'uuid-2',
      );
      expect(body['dosing_mode'], 'as_needed');
      expect(body['max_doses_per_day'], 4);
      expect(body.containsKey('intake_times'), isFalse);
      expect(body.containsKey('stock_quantity'), isFalse);
    });
  });

  group('entity → PATCH body (AC13)', () {
    test('chỉ đổi liều thì chỉ gửi quantity_per_dose', () {
      final before = base();
      expect(MedicationApiMapper.patchBody(before, before.copyWith(dosePerIntake: 2)), {
        'quantity_per_dose': 2.0,
      });
    });

    test('không đổi gì → rỗng', () {
      expect(MedicationApiMapper.patchBody(base(), base()), isEmpty);
    });

    test('đổi giờ → intake_times; đổi cách uống → intake_timing', () {
      final after = base().copyWith(
        times: const [DoseTime(7, 0), DoseTime(12, 0), DoseTime(19, 0)],
        frequency: DoseFrequency.thrice,
        timing: IntakeTiming.beforeMeal,
      );
      expect(MedicationApiMapper.patchBody(base(), after), {
        'intake_timing': 'before_meal',
        'intake_times': ['07:00', '12:00', '19:00'],
      });
    });

    test('chuyển sang khi cần gửi dosing_mode + max_doses_per_day', () {
      final after = base().copyWith(frequency: DoseFrequency.asNeeded, times: const []);
      expect(MedicationApiMapper.patchBody(base(), after), {
        'dosing_mode': 'as_needed',
        'max_doses_per_day': 3,
      });
    });

    test('chuyển sang theo giờ gửi dosing_mode + intake_times', () {
      final before = base(frequency: DoseFrequency.asNeeded, times: const [], maxDoses: 3);
      final after = before.copyWith(frequency: DoseFrequency.once, times: const [DoseTime(8, 0)]);
      expect(MedicationApiMapper.patchBody(before, after), {
        'dosing_mode': 'scheduled',
        'intake_times': ['08:00'],
      });
    });

    test('khi cần đổi số lần tối đa → chỉ max_doses_per_day', () {
      final before = base(frequency: DoseFrequency.asNeeded, times: const [], maxDoses: 3);
      expect(MedicationApiMapper.patchBody(before, before.copyWith(maxDosesPerDay: 5)), {
        'max_doses_per_day': 5,
      });
    });
  });

  group('lỗi HTTP → MedicationFailure (AC10, AC11)', () {
    MedicationFailureKind kindOf(int? status, String body, {bool transient = false}) =>
        MedicationApiMapper.failureFrom(
          ApiException(body, statusCode: status, isTransient: transient),
        ).kind;

    test('mạng và 5xx', () {
      expect(kindOf(null, 'Connection refused', transient: true), MedicationFailureKind.network);
      expect(kindOf(503, '', transient: true), MedicationFailureKind.network);
    });

    test('401, 403, 404', () {
      expect(kindOf(401, '{"detail": "Token expired"}'), MedicationFailureKind.unauthorized);
      expect(kindOf(403, '{"detail": "khong_co_quyen"}'), MedicationFailureKind.forbidden);
      expect(kindOf(403, '{"detail": "consent_revoked"}'), MedicationFailureKind.consentRevoked);
      expect(
        kindOf(404, '{"detail": "user_medication_not_found"}'),
        MedicationFailureKind.notFound,
      );
    });

    test('422 theo mã nghiệp vụ và mảng lỗi field', () {
      expect(
        kindOf(422, '{"detail": "catalog_medication_not_found"}'),
        MedicationFailureKind.catalogNotFound,
      );
      expect(
        kindOf(422, '{"detail": "medication_rule_violation"}'),
        MedicationFailureKind.ruleViolation,
      );
      expect(kindOf(422, '{"detail": "medication_stopped"}'), MedicationFailureKind.stopped);
      expect(
        kindOf(422, '{"detail": [{"loc": ["body", "x"], "msg": "m", "type": "t"}]}'),
        MedicationFailureKind.validation,
      );
      expect(kindOf(422, 'not json'), MedicationFailureKind.validation);
    });

    test('mã khác → unknown', () {
      expect(kindOf(409, '{"detail": "x"}'), MedicationFailureKind.unknown);
    });
  });
}
