import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/features/adherence_history/data/models/adherence_history_api_mapper.dart';
import 'package:drugtime_mobile/features/adherence_history/domain/entities/adherence_history.dart';
import 'adherence_history_test_helpers.dart';

void main() {
  test('same-name medications stay separate by ID with every scheduled dose',
      () {
    final j = copyFixture(historyFixture(mode: HistoryMode.medication));
    final second = copyFixture(j)['groups'][0] as Map<String, dynamic>;
    second['medication_id'] = 8;
    for (final dose in second['doses'] as List) {
      dose['medication_id'] = 8;
      dose['schedule_id'] = (dose['schedule_id'] as int) + 10;
    }
    j['groups'].add(second);
    for (final key in [
      'total',
      'taken',
      'late',
      'missed',
      'pending',
      'counted'
    ]) {
      j['summary'][key] = (j['summary'][key] as int) * 2;
    }
    final result = AdherenceHistoryApiMapper.parse(j);
    expect(result.medications.map((m) => m.medicationId), [7, 8]);
    expect(result.medications.map((m) => m.name).toSet().length, 1);
    expect(result.medications.expand((m) => m.doses).length, 8);
  });
  for (final mode in HistoryMode.values) {
    test('parses ${mode.wire}, counts and four statuses without dropping doses',
        () {
      final result =
          AdherenceHistoryApiMapper.parse(historyFixture(mode: mode));
      final doses = mode == HistoryMode.date
          ? result.dates.single.doses
          : result.medications.single.doses;
      expect(result.summary.rate, 66.67);
      expect(result.summary.pending, 1);
      expect(doses.map((d) => d.status), HistoryDoseStatus.values);
      expect(doses.last.takenAt, isNull);
      expect(doses.first.scheduleId, 1);
      expect(() => doses.clear(), throwsUnsupportedError);
    });
  }
  test('empty and pending-only retain null rate', () {
    for (final statuses in [
      <String>[],
      ['cho_xac_nhan']
    ]) {
      final result =
          AdherenceHistoryApiMapper.parse(historyFixture(statuses: statuses));
      expect(result.summary.rate, isNull);
      expect(result.summary.total, statuses.length);
    }
  });
  test(
      'rejects unknown status, missing timezone, invalid counts and duplicates',
      () {
    final changes = <void Function(Map<String, dynamic>)>[
      (j) => j['groups'][0]['doses'][0]['status'] = 'unknown',
      (j) => j['groups'][0]['doses'][0]['scheduled_at'] = '2026-10-19T08:00:00',
      (j) => j['summary']['taken'] = -1,
      (j) => j['summary']['adherence_rate'] = 101,
      (j) => j['groups'][0]['doses'][1]['schedule_id'] = 1,
      (j) => j['groups'][0]['doses'][0]['taken_at'] = null,
      (j) => j['from'] = '2026-02-30',
      (j) => j['timezone'] = 'UTC',
    ];
    for (final change in changes) {
      final j = copyFixture(historyFixture());
      change(j);
      expect(() => AdherenceHistoryApiMapper.parse(j), throwsFormatException);
    }
  });
}
