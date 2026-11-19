import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/core/notification/notification_id.dart';
import 'package:drugtime_mobile/core/notification/reminder_occurrence_generator.dart';

void main() {
  group('notificationIdFor (AC1..AC4)', () {
    test('AC1: returns deterministic IDs matching Python test vectors', () {
      final v1 = notificationIdFor(
        1,
        DateTime.utc(2026, 10, 7, 1, 0, 0),
      );
      expect(v1, 277106154);

      final v2 = notificationIdFor(
        2,
        DateTime.utc(2026, 10, 7, 1, 0, 0),
      );
      expect(v2, 280090069);

      final v3 = notificationIdFor(
        1,
        DateTime.utc(2026, 10, 7, 1, 0, 1),
      );
      expect(v3, 293883773);

      final v4 = notificationIdFor(
        102,
        DateTime.utc(2026, 10, 6, 17, 30, 0),
      );
      expect(v4, 259718614);

      // Deterministic: multiple calls return the identical ID
      for (var i = 0; i < 10; i++) {
        expect(
          notificationIdFor(1, DateTime.utc(2026, 10, 7, 1, 0, 0)),
          277106154,
        );
      }
    });

    test('AC2: produces distinct IDs for different schedules or times', () {
      final dt = DateTime.utc(2026, 10, 7, 1, 0, 0);
      final idA = notificationIdFor(1, dt);
      final idB = notificationIdFor(2, dt);
      final idC = notificationIdFor(1, dt.add(const Duration(seconds: 1)));
      final idD = notificationIdFor(1, dt.add(const Duration(minutes: 1)));

      expect(idA, isNot(equals(idB)));
      expect(idA, isNot(equals(idC)));
      expect(idA, isNot(equals(idD)));
      expect(idB, isNot(equals(idC)));
    });

    test(
        'AC3: produces IDs strictly in [0, 2^31 - 1] across 10000 random inputs',
        () {
      final random = Random(42);
      const max31Bit = 0x7FFFFFFF; // 2147483647

      for (var i = 0; i < 10000; i++) {
        final scheduleId = random.nextInt(100000) + 1;
        final epochSeconds = 1700000000 + random.nextInt(100000000);
        final scheduledAt = DateTime.fromMillisecondsSinceEpoch(
          epochSeconds * 1000,
          isUtc: true,
        );

        final id = notificationIdFor(scheduleId, scheduledAt);
        expect(id >= 0, isTrue, reason: 'ID must be non-negative: $id');
        expect(id <= max31Bit, isTrue, reason: 'ID must fit 31-bit: $id');
      }
    });

    test('AC4: throws ArgumentError for non-UTC scheduledAt', () {
      final nonUtc = DateTime(2026, 10, 7, 8, 0, 0);
      expect(
        () => notificationIdFor(1, nonUtc),
        throwsArgumentError,
      );
    });
  });

  group('NotificationPayload (AC5)', () {
    test('round-trips valid data correctly', () {
      final scheduledAt = DateTime.utc(2026, 10, 7, 1, 0, 0);
      final payload = NotificationPayload(
        medicationScheduleId: 42,
        scheduledAt: scheduledAt,
      );

      final jsonString = payload.serialize();
      final parsed = NotificationPayload.tryParse(jsonString);

      expect(parsed, isNotNull);
      expect(parsed!.medicationScheduleId, 42);
      expect(parsed.scheduledAt, scheduledAt);
      expect(parsed.scheduledAt.isUtc, isTrue);
      expect(parsed, equals(payload));
    });

    test('throws ArgumentError if constructed with non-UTC scheduledAt', () {
      final nonUtc = DateTime(2026, 10, 7, 8, 0, 0);
      expect(
        () => NotificationPayload(
          medicationScheduleId: 1,
          scheduledAt: nonUtc,
        ),
        throwsArgumentError,
      );
    });

    test('returns null for corrupt, empty, or invalid input safely', () {
      expect(NotificationPayload.tryParse(null), isNull);
      expect(NotificationPayload.tryParse(''), isNull);
      expect(NotificationPayload.tryParse('   '), isNull);
      expect(NotificationPayload.tryParse('invalid-json'), isNull);
      expect(NotificationPayload.tryParse('{}'), isNull);
      expect(NotificationPayload.tryParse('[]'), isNull);
      expect(
        NotificationPayload.tryParse(
          '{"schedule_id": "not-an-int", "scheduled_at": "2026-10-07T01:00:00.000Z"}',
        ),
        isNull,
      );
      expect(
        NotificationPayload.tryParse(
          '{"schedule_id": 1, "scheduled_at": 12345}',
        ),
        isNull,
      );
      expect(
        NotificationPayload.tryParse(
          '{"schedule_id": 1, "scheduled_at": "not-a-date"}',
        ),
        isNull,
      );
      expect(
        NotificationPayload.tryParse(
          '{"schedule_id": 1, "scheduled_at": "2026-10-07T08:00:00"}', // non-UTC
        ),
        isNull,
      );
      expect(
        NotificationPayload.tryParse(
          '{"schedule_id": 1}', // missing scheduled_at
        ),
        isNull,
      );
      expect(
        NotificationPayload.tryParse(
          '{"scheduled_at": "2026-10-07T01:00:00.000Z"}', // missing schedule_id
        ),
        isNull,
      );
    });
  });

  group('detectIdCollisions (AC6)', () {
    test('returns occurrences unchanged when no ID collisions', () {
      final occurrences = [
        ReminderOccurrence(
          medicationScheduleId: 1,
          scheduledAt: DateTime.utc(2026, 10, 7, 1, 0, 0),
        ),
        ReminderOccurrence(
          medicationScheduleId: 2,
          scheduledAt: DateTime.utc(2026, 10, 7, 1, 0, 0),
        ),
        ReminderOccurrence(
          medicationScheduleId: 1,
          scheduledAt: DateTime.utc(2026, 10, 7, 1, 0, 1),
        ),
      ];

      final warnings = <String>[];
      final result = detectIdCollisions(
        occurrences,
        onCollision: warnings.add,
      );

      expect(result.length, 3);
      expect(result, equals(occurrences));
      expect(warnings, isEmpty);
    });

    test(
        'detects duplicate ID, logs warning, skips duplicate, keeps original scheduledAt',
        () {
      final dt = DateTime.utc(2026, 10, 7, 1, 0, 0);
      final occ1 = ReminderOccurrence(
        medicationScheduleId: 1,
        scheduledAt: dt,
      );
      final occ2Duplicate = ReminderOccurrence(
        medicationScheduleId: 1,
        scheduledAt: dt,
      );
      final occ3Other = ReminderOccurrence(
        medicationScheduleId: 2,
        scheduledAt: dt,
      );

      final warnings = <String>[];
      final result = detectIdCollisions(
        [occ1, occ2Duplicate, occ3Other],
        onCollision: warnings.add,
      );

      expect(result.length, 2);
      expect(result[0], equals(occ1));
      expect(result[0].scheduledAt, equals(dt),
          reason: 'scheduledAt must NOT be shifted');
      expect(result[1], equals(occ3Other));

      expect(warnings.length, 1);
      expect(warnings.first, contains('Va chạm ID thông báo'));
      expect(warnings.first, contains('277106154'));
    });
  });
}
