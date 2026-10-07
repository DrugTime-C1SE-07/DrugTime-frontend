import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/core/notification/reminder_occurrence_generator.dart';
import 'package:drugtime_mobile/core/storage/local_db/local_models.dart';

LocalMedicationSchedule _buildSchedule({
  int id = 1,
  String patientUserId = 'patient-1',
  int userMedicationId = 10,
  int medicationId = 100,
  String medicationName = 'Panadol Extra',
  String quantityPerDose = '1 vien',
  int dosesPerDay = 1,
  String intakeTime = '08:00:00',
  List<int> daysOfWeek = const [1, 2, 3, 4, 5, 6, 7],
  bool reminderEnabled = true,
  DateTime? effectiveFrom,
  DateTime? endedAt,
  DateTime? serverSyncedAt,
}) {
  return LocalMedicationSchedule(
    id: id,
    patientUserId: patientUserId,
    userMedicationId: userMedicationId,
    medicationId: medicationId,
    medicationName: medicationName,
    quantityPerDose: quantityPerDose,
    dosesPerDay: dosesPerDay,
    intakeTime: intakeTime,
    daysOfWeek: daysOfWeek,
    reminderEnabled: reminderEnabled,
    effectiveFrom: effectiveFrom ?? DateTime.utc(2026, 1, 1),
    endedAt: endedAt,
    serverSyncedAt: serverSyncedAt ?? DateTime.utc(2026, 1, 1),
  );
}

void main() {
  group('generateOccurrences (SCRUM-60 / Task 2.07)', () {
    test(
        'AC1: generates daily occurrences at 01:00Z for 08:00 VN schedule across 3 days',
        () {
      final schedule = _buildSchedule(
        id: 1,
        intakeTime: '08:00:00',
        daysOfWeek: const [1, 2, 3, 4, 5, 6, 7],
      );

      final from = DateTime.utc(2026, 10, 7, 0, 0, 0);
      final to = DateTime.utc(2026, 10, 10, 0, 0, 0);

      final result = generateOccurrences(
        schedules: [schedule],
        from: from,
        to: to,
      );

      expect(result.length, 3);
      expect(
        result,
        equals([
          ReminderOccurrence(
            medicationScheduleId: 1,
            scheduledAt: DateTime.utc(2026, 10, 7, 1, 0, 0),
          ),
          ReminderOccurrence(
            medicationScheduleId: 1,
            scheduledAt: DateTime.utc(2026, 10, 8, 1, 0, 0),
          ),
          ReminderOccurrence(
            medicationScheduleId: 1,
            scheduledAt: DateTime.utc(2026, 10, 9, 1, 0, 0),
          ),
        ]),
      );
    });

    test(
        'AC2: filters by selected days of week (1, 3, 5) evaluated in VN calendar dates',
        () {
      // 2026-10-05: Thu Hai (1)
      // 2026-10-06: Thu Ba (2)
      // 2026-10-07: Thu Tu (3)
      // 2026-10-08: Thu Nam (4)
      // 2026-10-09: Thu Sau (5)
      // 2026-10-10: Thu Bay (6)
      // 2026-10-11: Chu Nhat (7)
      final schedule = _buildSchedule(
        id: 2,
        intakeTime: '08:00:00',
        daysOfWeek: const [1, 3, 5],
      );

      final from = DateTime.utc(2026, 10, 5, 0, 0, 0);
      final to = DateTime.utc(2026, 10, 12, 0, 0, 0);

      final result = generateOccurrences(
        schedules: [schedule],
        from: from,
        to: to,
      );

      expect(result.length, 3);
      expect(
        result,
        equals([
          ReminderOccurrence(
            medicationScheduleId: 2,
            scheduledAt: DateTime.utc(2026, 10, 5, 1, 0, 0),
          ),
          ReminderOccurrence(
            medicationScheduleId: 2,
            scheduledAt: DateTime.utc(2026, 10, 7, 1, 0, 0),
          ),
          ReminderOccurrence(
            medicationScheduleId: 2,
            scheduledAt: DateTime.utc(2026, 10, 9, 1, 0, 0),
          ),
        ]),
      );
    });

    test(
        'AC3: handles midnight boundary and filters days_of_week in VN calendar date',
        () {
      // Ngay VN Thu Tu 07/10/2026:
      // 00:00:00 VN -> 2026-10-06T17:00:00Z (Thu Ba UTC)
      // 00:30:00 VN -> 2026-10-06T17:30:00Z (Thu Ba UTC)
      // 00:59:00 VN -> 2026-10-06T17:59:00Z (Thu Ba UTC)
      // 23:59:00 VN -> 2026-10-07T16:59:00Z (Thu Tu UTC)
      final schedules = [
        _buildSchedule(id: 101, intakeTime: '00:00:00', daysOfWeek: const [3]),
        _buildSchedule(id: 102, intakeTime: '00:30:00', daysOfWeek: const [3]),
        _buildSchedule(id: 103, intakeTime: '00:59:00', daysOfWeek: const [3]),
        _buildSchedule(id: 104, intakeTime: '23:59:00', daysOfWeek: const [3]),
      ];

      final from = DateTime.utc(2026, 10, 5, 0, 0, 0);
      final to = DateTime.utc(2026, 10, 9, 0, 0, 0);

      final result = generateOccurrences(
        schedules: schedules,
        from: from,
        to: to,
      );

      expect(result.length, 4);
      expect(
        result,
        equals([
          ReminderOccurrence(
            medicationScheduleId: 101,
            scheduledAt: DateTime.utc(2026, 10, 6, 17, 0, 0),
          ),
          ReminderOccurrence(
            medicationScheduleId: 102,
            scheduledAt: DateTime.utc(2026, 10, 6, 17, 30, 0),
          ),
          ReminderOccurrence(
            medicationScheduleId: 103,
            scheduledAt: DateTime.utc(2026, 10, 6, 17, 59, 0),
          ),
          ReminderOccurrence(
            medicationScheduleId: 104,
            scheduledAt: DateTime.utc(2026, 10, 7, 16, 59, 0),
          ),
        ]),
      );

      // Kiem tra xac minh: schedule chi co Thu Tu (3) khong duoc sinh luot cho ngay VN 06/10 (Thu Ba),
      // du 17:30:00Z cua ngay 06/10 la Thu Ba theo UTC.
      final windowTuesdayOnly = generateOccurrences(
        schedules: [
          _buildSchedule(id: 102, intakeTime: '00:30:00', daysOfWeek: const [3])
        ],
        from: DateTime.utc(2026, 10, 5, 0, 0, 0),
        to: DateTime.utc(2026, 10, 6, 17, 0, 0),
      );
      expect(windowTuesdayOnly, isEmpty);
    });

    test('AC4: respects window boundaries (inclusive from, exclusive to)', () {
      final schedule = _buildSchedule(
        id: 4,
        intakeTime: '08:00:00', // 01:00:00Z
      );

      // from dung bang luot ngay 07/10: phai CO
      // to dung bang luot ngay 08/10: phai BI LOAI
      final result = generateOccurrences(
        schedules: [schedule],
        from: DateTime.utc(2026, 10, 7, 1, 0, 0),
        to: DateTime.utc(2026, 10, 8, 1, 0, 0),
      );

      expect(result.length, 1);
      expect(
        result.first,
        equals(
          ReminderOccurrence(
            medicationScheduleId: 4,
            scheduledAt: DateTime.utc(2026, 10, 7, 1, 0, 0),
          ),
        ),
      );

      // from sau luot 01:00:00Z dung 1 giay: phai BI LOAI
      final emptyResult = generateOccurrences(
        schedules: [schedule],
        from: DateTime.utc(2026, 10, 7, 1, 0, 1),
        to: DateTime.utc(2026, 10, 8, 1, 0, 0),
      );
      expect(emptyResult, isEmpty);
    });

    test('AC5: enforces effective_from and ended_at instant validity (BQ-013)',
        () {
      // Luot xay ra luc 01:00:00Z ngay 07/10 va 08/10
      // Case A: effective_from dung bang scheduledAt -> GIU
      final scheduleEffectiveExact = _buildSchedule(
        id: 51,
        intakeTime: '08:00:00',
        effectiveFrom: DateTime.utc(2026, 10, 7, 1, 0, 0),
      );
      final resA = generateOccurrences(
        schedules: [scheduleEffectiveExact],
        from: DateTime.utc(2026, 10, 7, 0, 0, 0),
        to: DateTime.utc(2026, 10, 7, 12, 0, 0),
      );
      expect(resA.length, 1);

      // Case B: effective_from sau scheduledAt 1 giay -> LOAI
      final scheduleEffectiveAfter = _buildSchedule(
        id: 52,
        intakeTime: '08:00:00',
        effectiveFrom: DateTime.utc(2026, 10, 7, 1, 0, 1),
      );
      final resB = generateOccurrences(
        schedules: [scheduleEffectiveAfter],
        from: DateTime.utc(2026, 10, 7, 0, 0, 0),
        to: DateTime.utc(2026, 10, 7, 12, 0, 0),
      );
      expect(resB, isEmpty);

      // Case C: ended_at dung bang scheduledAt ngay 08/10 -> LOAI (ended_at loai tru)
      final scheduleEndedExact = _buildSchedule(
        id: 53,
        intakeTime: '08:00:00',
        endedAt: DateTime.utc(2026, 10, 8, 1, 0, 0),
      );
      final resC = generateOccurrences(
        schedules: [scheduleEndedExact],
        from: DateTime.utc(2026, 10, 7, 0, 0, 0),
        to: DateTime.utc(2026, 10, 9, 0, 0, 0),
      );
      expect(resC.length, 1);
      expect(resC.first.scheduledAt, DateTime.utc(2026, 10, 7, 1, 0, 0));

      // Case D: ended_at sau scheduledAt 1 giay -> GIU
      final scheduleEndedAfter = _buildSchedule(
        id: 54,
        intakeTime: '08:00:00',
        endedAt: DateTime.utc(2026, 10, 8, 1, 0, 1),
      );
      final resD = generateOccurrences(
        schedules: [scheduleEndedAfter],
        from: DateTime.utc(2026, 10, 7, 0, 0, 0),
        to: DateTime.utc(2026, 10, 9, 0, 0, 0),
      );
      expect(resD.length, 2);
    });

    test('AC6: handles open-ended schedule when ended_at is null', () {
      final schedule = _buildSchedule(
        id: 6,
        intakeTime: '08:00:00',
        endedAt: null,
      );

      final result = generateOccurrences(
        schedules: [schedule],
        from: DateTime.utc(2026, 10, 1, 0, 0, 0),
        to: DateTime.utc(2026, 10, 6, 0, 0, 0),
      );

      expect(result.length, 5);
      expect(result.first.scheduledAt, DateTime.utc(2026, 10, 1, 1, 0, 0));
      expect(result.last.scheduledAt, DateTime.utc(2026, 10, 5, 1, 0, 0));
    });

    test('AC7: sorts stably by medicationScheduleId when scheduled_at matches',
        () {
      final scheduleA = _buildSchedule(id: 20, intakeTime: '08:00:00');
      final scheduleB = _buildSchedule(id: 10, intakeTime: '08:00:00');

      // Truyen danh sach nguoc thu tu id
      final result = generateOccurrences(
        schedules: [scheduleA, scheduleB],
        from: DateTime.utc(2026, 10, 7, 0, 0, 0),
        to: DateTime.utc(2026, 10, 8, 0, 0, 0),
      );

      expect(result.length, 2);
      expect(result[0].medicationScheduleId, 10);
      expect(result[1].medicationScheduleId, 20);
      expect(result[0].scheduledAt, DateTime.utc(2026, 10, 7, 1, 0, 0));
      expect(result[1].scheduledAt, DateTime.utc(2026, 10, 7, 1, 0, 0));
    });

    test('AC8: sorts occurrences chronologically for multiple intake times',
        () {
      // 07:00 VN -> 00:00:00Z
      // 13:00 VN -> 06:00:00Z
      // 20:00 VN -> 13:00:00Z
      final s1 = _buildSchedule(id: 1, intakeTime: '20:00:00');
      final s2 = _buildSchedule(id: 2, intakeTime: '07:00:00');
      final s3 = _buildSchedule(id: 3, intakeTime: '13:00:00');

      final result = generateOccurrences(
        schedules: [s1, s2, s3],
        from: DateTime.utc(2026, 10, 7, 0, 0, 0),
        to: DateTime.utc(2026, 10, 8, 0, 0, 0),
      );

      expect(result.length, 3);
      expect(
        result.map((r) => r.scheduledAt).toList(),
        equals([
          DateTime.utc(2026, 10, 7, 0, 0, 0),
          DateTime.utc(2026, 10, 7, 6, 0, 0),
          DateTime.utc(2026, 10, 7, 13, 0, 0),
        ]),
      );
      expect(result.map((r) => r.medicationScheduleId).toList(),
          equals([2, 3, 1]));
    });

    test('AC9: excludes schedules with reminder_enabled false', () {
      final sOff = _buildSchedule(id: 91, reminderEnabled: false);
      final sOn = _buildSchedule(id: 92, reminderEnabled: true);

      final result = generateOccurrences(
        schedules: [sOff, sOn],
        from: DateTime.utc(2026, 10, 7, 0, 0, 0),
        to: DateTime.utc(2026, 10, 8, 0, 0, 0),
      );

      expect(result.length, 1);
      expect(result.first.medicationScheduleId, 92);
    });

    test(
        'AC10: verifies timezone independence (grep static check and behavior consistency)',
        () {
      // 1. Static check: File nguon khong duoc goi toLocal, DateTime.now, timeZoneOffset
      final sourceFile =
          File('lib/core/notification/reminder_occurrence_generator.dart');
      if (sourceFile.existsSync()) {
        final content = sourceFile.readAsStringSync();
        expect(content.contains('.toLocal()'), isFalse,
            reason: 'Must not call toLocal()');
        expect(content.contains('DateTime.now()'), isFalse,
            reason: 'Must not call DateTime.now()');
        expect(content.contains('timeZoneOffset'), isFalse,
            reason: 'Must not call timeZoneOffset');
      }

      // 2. Behavior consistency: Goi ham voi cung input luon ra output giong het
      final schedule = _buildSchedule(id: 10, intakeTime: '12:00:00');
      final res1 = generateOccurrences(
        schedules: [schedule],
        from: DateTime.utc(2026, 10, 7, 0, 0, 0),
        to: DateTime.utc(2026, 10, 8, 0, 0, 0),
      );
      final res2 = generateOccurrences(
        schedules: [schedule],
        from: DateTime.utc(2026, 10, 7, 0, 0, 0),
        to: DateTime.utc(2026, 10, 8, 0, 0, 0),
      );

      expect(res1, equals(res2));
    });

    test(
        'AC11: throws ArgumentError for non-UTC dates and returns empty for to <= from',
        () {
      final schedule = _buildSchedule();

      // Non-UTC from
      expect(
        () => generateOccurrences(
          schedules: [schedule],
          from: DateTime(2026, 10, 7, 0, 0, 0), // isUtc == false
          to: DateTime.utc(2026, 10, 8, 0, 0, 0),
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Non-UTC to
      expect(
        () => generateOccurrences(
          schedules: [schedule],
          from: DateTime.utc(2026, 10, 7, 0, 0, 0),
          to: DateTime(2026, 10, 8, 0, 0, 0), // isUtc == false
        ),
        throwsA(isA<ArgumentError>()),
      );

      // to == from -> empty
      final resEqual = generateOccurrences(
        schedules: [schedule],
        from: DateTime.utc(2026, 10, 7, 0, 0, 0),
        to: DateTime.utc(2026, 10, 7, 0, 0, 0),
      );
      expect(resEqual, isEmpty);

      // to < from -> empty
      final resBefore = generateOccurrences(
        schedules: [schedule],
        from: DateTime.utc(2026, 10, 8, 0, 0, 0),
        to: DateTime.utc(2026, 10, 7, 0, 0, 0),
      );
      expect(resBefore, isEmpty);
    });

    test('AC12: returns empty list when schedules is empty', () {
      final result = generateOccurrences(
        schedules: [],
        from: DateTime.utc(2026, 10, 7, 0, 0, 0),
        to: DateTime.utc(2026, 10, 10, 0, 0, 0),
      );
      expect(result, isEmpty);
    });
  });
}
