import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/core/notification/reminder_benchmark_logger.dart';

void main() {
  group('ReminderBenchmarkRecord', () {
    test('calculates positive delta_ms when actual time is after target', () {
      final target = DateTime.utc(2026, 10, 29, 8, 0, 0);
      final actual = DateTime.utc(2026, 10, 29, 8, 0, 1, 250); // +1250ms

      final record = ReminderBenchmarkRecord(
        notificationId: 101,
        targetTime: target,
        actualTime: actual,
        deltaMs: actual.difference(target).inMilliseconds,
      );

      expect(record.deltaMs, 1250);
      expect(record.isCompliant, isTrue);
    });

    test('calculates negative delta_ms when actual time is before target', () {
      final target = DateTime.utc(2026, 10, 29, 8, 0, 0);
      final actual = DateTime.utc(2026, 10, 29, 7, 59, 59, 600); // -400ms

      final record = ReminderBenchmarkRecord(
        notificationId: 102,
        targetTime: target,
        actualTime: actual,
        deltaMs: actual.difference(target).inMilliseconds,
      );

      expect(record.deltaMs, -400);
      expect(record.isCompliant, isTrue);
    });

    test('isCompliant is false when delta exceeds 2000ms threshold', () {
      final target = DateTime.utc(2026, 10, 29, 8, 0, 0);
      final actual = DateTime.utc(2026, 10, 29, 8, 0, 2, 500); // +2500ms

      final record = ReminderBenchmarkRecord(
        notificationId: 103,
        targetTime: target,
        actualTime: actual,
        deltaMs: actual.difference(target).inMilliseconds,
      );

      expect(record.deltaMs, 2500);
      expect(record.isCompliant, isFalse);
    });

    test('serializes to JSON correctly', () {
      final target = DateTime.utc(2026, 10, 29, 8, 0, 0);
      final actual = DateTime.utc(2026, 10, 29, 8, 0, 0, 500);

      final record = ReminderBenchmarkRecord(
        notificationId: 104,
        targetTime: target,
        actualTime: actual,
        deltaMs: 500,
        deviceState: 'screen_off',
      );

      final json = record.toJson();
      expect(json['notification_id'], 104);
      expect(json['delta_ms'], 500);
      expect(json['is_compliant'], isTrue);
      expect(json['device_state'], 'screen_off');
    });
  });

  group('ReminderBenchmarkLogger Metrics & Statistics', () {
    late ReminderBenchmarkLogger logger;

    setUp(() {
      logger = ReminderBenchmarkLogger(
        maxAllowedDeltaMs: 2000,
        targetComplianceRate: 0.99,
      );
    });

    test('empty logger reports baseline values', () {
      expect(logger.totalSamples, 0);
      expect(logger.compliantSamples, 0);
      expect(logger.violatedSamples, 0);
      expect(logger.complianceRate, 1.0);
      expect(logger.meanDelayMs, 0.0);
      expect(logger.maxDelayMs, 0);
      expect(logger.minDelayMs, 0);
      expect(logger.meetsNfrRequirement, isFalse);
    });

    test('records entries and computes aggregations correctly', () {
      final base = DateTime.utc(2026, 10, 29, 9, 0, 0);

      logger.record(
        notificationId: 1,
        targetTime: base,
        actualTime: base.add(const Duration(milliseconds: 300)),
      );
      logger.record(
        notificationId: 2,
        targetTime: base.add(const Duration(hours: 1)),
        actualTime: base.add(const Duration(hours: 1, milliseconds: 700)),
      );
      logger.record(
        notificationId: 3,
        targetTime: base.add(const Duration(hours: 2)),
        actualTime: base.add(const Duration(hours: 2, milliseconds: 2500)), // Violated
      );

      expect(logger.totalSamples, 3);
      expect(logger.compliantSamples, 2);
      expect(logger.violatedSamples, 1);
      expect(logger.complianceRate, closeTo(2 / 3, 0.001));
      expect(logger.minDelayMs, 300);
      expect(logger.maxDelayMs, 2500);
      expect(logger.meanDelayMs, closeTo((300 + 700 + 2500) / 3, 0.01));
    });

    test('toCsv produces valid CSV string format', () {
      final base = DateTime.utc(2026, 10, 29, 9, 0, 0);
      logger.record(
        notificationId: 1,
        targetTime: base,
        actualTime: base.add(const Duration(milliseconds: 200)),
        deviceState: 'foreground',
      );

      final csv = logger.toCsv();
      expect(csv, contains('notification_id,target_time,actual_time,delta_ms,is_compliant,device_state'));
      expect(csv, contains('1,2026-10-29T09:00:00.000Z,2026-10-29T09:00:00.200Z,200,true,foreground'));
    });
  });

  group('NFR04/05 Notification Timing Accuracy Benchmark Simulation', () {
    test('300 samples with 99.0% compliance meets NFR requirement (<= 2000ms)', () {
      final logger = ReminderBenchmarkLogger(
        maxAllowedDeltaMs: 2000,
        targetComplianceRate: 0.99,
      );

      final startTime = DateTime.utc(2026, 10, 29, 6, 0, 0);

      // Simulate 297 notifications triggered within realistic jitter: 50ms - 450ms
      for (var i = 1; i <= 297; i++) {
        final target = startTime.add(Duration(minutes: i * 5));
        final jitterMs = (i % 9) * 50; // 0, 50, 100, ..., 400ms
        final actual = target.add(Duration(milliseconds: jitterMs));

        logger.record(
          notificationId: i,
          targetTime: target,
          actualTime: actual,
          deviceState: (i % 2 == 0) ? 'doze_mode' : 'active',
        );
      }

      // Simulate 3 edge cases exceeding 2000ms threshold (e.g. system low memory delay)
      for (var i = 298; i <= 300; i++) {
        final target = startTime.add(Duration(minutes: i * 5));
        final actual = target.add(const Duration(milliseconds: 2150));

        logger.record(
          notificationId: i,
          targetTime: target,
          actualTime: actual,
          deviceState: 'battery_saver',
        );
      }

      expect(logger.totalSamples, 300);
      expect(logger.compliantSamples, 297);
      expect(logger.violatedSamples, 3);
      expect(logger.complianceRate, 0.99);
      expect(logger.meetsNfrRequirement, isTrue);
      expect(logger.meanDelayMs, lessThan(300));
      expect(logger.maxDelayMs, 2150);
    });

    test('fails NFR requirement when compliance rate falls below 99%', () {
      final logger = ReminderBenchmarkLogger(
        maxAllowedDeltaMs: 2000,
        targetComplianceRate: 0.99,
      );

      final startTime = DateTime.utc(2026, 10, 29, 6, 0, 0);

      // 290 compliant, 10 non-compliant -> 290 / 300 = 96.67%
      for (var i = 1; i <= 290; i++) {
        final target = startTime.add(Duration(minutes: i * 5));
        final actual = target.add(Duration(milliseconds: (i % 5) * 100));
        logger.record(notificationId: i, targetTime: target, actualTime: actual);
      }
      for (var i = 291; i <= 300; i++) {
        final target = startTime.add(Duration(minutes: i * 5));
        final actual = target.add(const Duration(milliseconds: 3200));
        logger.record(notificationId: i, targetTime: target, actualTime: actual);
      }

      expect(logger.totalSamples, 300);
      expect(logger.compliantSamples, 290);
      expect(logger.violatedSamples, 10);
      expect(logger.complianceRate, closeTo(0.9667, 0.001));
      expect(logger.meetsNfrRequirement, isFalse);
    });
  });
}
