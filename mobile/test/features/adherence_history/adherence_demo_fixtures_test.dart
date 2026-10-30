import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/features/adherence_history/data/models/adherence_demo_fixtures.dart';
import 'package:drugtime_mobile/features/adherence_history/domain/entities/adherence_demo_preset.dart';
import 'package:drugtime_mobile/features/adherence_history/domain/entities/adherence_history.dart';

void main() {
  test(
      'launch-date mixed fixture covers 24+ doses and seven days across month/year boundaries',
      () {
    for (final clock in [
      DateTime.utc(2026, 10, 22, 7),
      DateTime.utc(2027, 1, 1, 7),
      DateTime.utc(2026, 2, 2, 7)
    ]) {
      final today = DateTime.utc(clock.year, clock.month, clock.day);
      final from = DateTime.utc(today.year, today.month - 1);
      final dates = AdherenceDemoFixtures.build(AdherenceDemoPreset.mixed,
          from: from, to: today, mode: HistoryMode.date, clock: clock);
      final medications = AdherenceDemoFixtures.build(AdherenceDemoPreset.mixed,
          from: from, to: today, mode: HistoryMode.medication, clock: clock);
      expect(dates.dates.length, greaterThanOrEqualTo(7));
      expect(dates.summary.total, greaterThanOrEqualTo(24));
      expect(dates.dates.any((g) => g.date.month != today.month), true);
      final day = dates.dates.singleWhere((g) => g.date == today).summary;
      expect((day.taken, day.late, day.missed, day.pending, day.rate),
          (3, 1, 1, 1, 80));
      final a = dates.dates
          .expand((g) => g.doses)
          .map((d) => (d.scheduleId, d.scheduledAt))
          .toSet();
      final b = medications.medications
          .expand((g) => g.doses)
          .map((d) => (d.scheduleId, d.scheduledAt))
          .toSet();
      expect(a, b);
      expect(dates.summary.total, medications.summary.total);
      expect(dates.summary.rate, medications.summary.rate);
      for (final dose in dates.dates.expand((g) => g.doses)) {
        expect(dose.scheduledAt.isAfter(clock), false);
        if (dose.status == HistoryDoseStatus.pending) {
          expect(clock.difference(dose.scheduledAt).inMinutes,
              inInclusiveRange(0, 120));
        }
      }
    }
  });
  AdherenceHistory read(AdherenceDemoPreset preset, HistoryMode mode,
          {int month = 10, int end = 22}) =>
      AdherenceDemoFixtures.build(preset,
          from: DateTime.utc(2026, month),
          to: DateTime.utc(2026, month, end),
          mode: mode);

  test('exact preset day counts/rates/null, both groupings agree', () {
    final cases = <AdherenceDemoPreset, (int, double?)>{
      AdherenceDemoPreset.mixed: (6, 80),
      AdherenceDemoPreset.allTaken: (4, 100),
      AdherenceDemoPreset.allLate: (4, 100),
      AdherenceDemoPreset.someMissed: (4, 75),
      AdherenceDemoPreset.allMissed: (3, 0),
      AdherenceDemoPreset.pendingOnly: (3, null),
      AdherenceDemoPreset.empty: (0, null),
      AdherenceDemoPreset.longList: (24, 66.67),
    };
    for (final entry in cases.entries) {
      final dates = read(entry.key, HistoryMode.date);
      final medication = read(entry.key, HistoryMode.medication);
      final day =
          dates.dates.where((g) => g.date == DateTime.utc(2026, 10, 22));
      expect(day.isEmpty ? 0 : day.single.summary.total, entry.value.$1);
      expect(day.isEmpty ? null : day.single.summary.rate, entry.value.$2);
      expect(dates.summary.total, medication.summary.total);
      expect(dates.summary.rate, medication.summary.rate);
      final doses = dates.dates.expand((g) => g.doses).toList();
      expect(
          doses.map((d) => '${d.scheduleId}/${d.scheduledAt}').toSet().length,
          doses.length);
      for (final dose in doses) {
        expect(dose.scheduledAt.isAfter(entry.key.clock), isFalse);
        if (dose.status == HistoryDoseStatus.pending) {
          expect(entry.key.clock.difference(dose.scheduledAt).inMinutes,
              inInclusiveRange(0, 120));
          expect(dose.statusSource, 'inferred');
          expect(dose.takenAt, isNull);
        }
      }
    }
  });

  test(
      'mixed has distinct names/IDs, same-time occurrences, midnight and prior month',
      () {
    final data = read(AdherenceDemoPreset.mixed, HistoryMode.date);
    expect(data.dates.length, greaterThanOrEqualTo(3));
    final doses = data.dates.expand((g) => g.doses).toList();
    expect(doses.map((d) => d.medicationName).toSet().length,
        greaterThanOrEqualTo(6));
    final today = data.dates.last.doses;
    expect(today[0].scheduledAt, today[1].scheduledAt);
    expect(today[0].scheduleId, isNot(today[1].scheduleId));
    final midnight =
        data.dates.firstWhere((g) => g.date.day == 21).doses.single;
    expect(midnight.scheduledAt.add(const Duration(hours: 7)).day, 21);
    expect(midnight.takenAt!.add(const Duration(hours: 7)).day, 22);
    final old = read(AdherenceDemoPreset.mixed, HistoryMode.medication,
        month: 9, end: 30);
    final current = read(AdherenceDemoPreset.mixed, HistoryMode.medication);
    final first = current.medications.firstWhere((g) => g.medicationId == 7);
    final duplicate =
        current.medications.firstWhere((g) => g.medicationId == 13);
    expect(first.medicationId, isNot(duplicate.medicationId));
    expect(first.name, duplicate.name);
    expect(old.medications.single.name, first.name);
  });
}
