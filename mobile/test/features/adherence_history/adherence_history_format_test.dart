import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/features/adherence_history/data/models/adherence_history_api_mapper.dart';
import 'package:drugtime_mobile/features/adherence_history/presentation/utils/adherence_history_format.dart';
import 'adherence_history_test_helpers.dart';

void main() {
  test('Vietnam date and periods do not depend on device timezone', () {
    final now = DateTime.parse('2026-10-20T18:05:00Z');
    expect(HistoryFormat.today(now), DateTime.utc(2026, 10, 21));
    expect(HistoryFormat.period(DateTime.utc(2026, 10), now).to,
        DateTime.utc(2026, 10, 21));
    expect(HistoryFormat.period(DateTime.utc(2024, 2), now).to,
        DateTime.utc(2024, 2, 29));
    expect(HistoryFormat.period(DateTime.utc(2025, 12), now).to,
        DateTime.utc(2025, 12, 31));
  });
  test('formats rates without multiplying and marks missing/pending correctly',
      () {
    expect([
      HistoryFormat.rate(0),
      HistoryFormat.rate(66.67),
      HistoryFormat.rate(100),
      HistoryFormat.rate(null)
    ], [
      '0%',
      '66,67%',
      '100%',
      'Chưa tính'
    ]);
    expect(HistoryFormat.marker(null), isNull);
    for (final entry in {
      'da_uong': HistoryDayMarker.complete,
      'uong_tre': HistoryDayMarker.complete,
      'bo_lo': HistoryDayMarker.missed,
    }.entries) {
      final result = AdherenceHistoryApiMapper.parse(
          historyFixture(statuses: [entry.key]));
      expect(HistoryFormat.marker(result.summary), entry.value);
    }
    final partial = AdherenceHistoryApiMapper.parse(
        historyFixture(statuses: ['da_uong', 'bo_lo']));
    expect(HistoryFormat.marker(partial.summary), HistoryDayMarker.missed);
    final pending = AdherenceHistoryApiMapper.parse(
        historyFixture(statuses: ['cho_xac_nhan']));
    expect(HistoryFormat.marker(pending.summary), HistoryDayMarker.pending);
  });
  test('Monday weeks cross month and year without losing any day', () {
    expect(HistoryFormat.week(DateTime.utc(2026, 10, 22)), [
      for (var n = 19; n <= 25; n++) DateTime.utc(2026, 10, n),
    ]);
    final week = HistoryFormat.week(DateTime.utc(2027, 1, 1));
    expect(week.first, DateTime.utc(2026, 12, 28));
    expect(week.last, DateTime.utc(2027, 1, 3));
    expect(HistoryFormat.week(DateTime.utc(2024, 3, 1))[3],
        DateTime.utc(2024, 2, 29));
    expect(
        HistoryFormat.dayHeading(DateTime.utc(2026, 10, 22),
            today: DateTime.utc(2026, 10, 22)),
        'Thứ 5, 22/10/2026 · Hôm nay');
  });
  test('actual intake crossing midnight includes actual date', () {
    final j = historyFixture(statuses: ['uong_tre']);
    j['groups'][0]['doses'][0]['scheduled_at'] = '2026-10-19T23:30:00+07:00';
    j['groups'][0]['doses'][0]['taken_at'] = '2026-10-20T00:10:00+07:00';
    final result = AdherenceHistoryApiMapper.parse(j);
    expect(HistoryFormat.actual(result.dates.single.doses.single),
        'Đã uống lúc 00:10 · 20/10/2026');
  });
}
