import 'package:drugtime_mobile/features/adherence/domain/entities/adherence_history.dart';
import 'package:drugtime_mobile/features/patient_monitor/domain/monitor_digest.dart';
import 'package:flutter_test/flutter_test.dart';

/// Giờ VN → UTC (VN = UTC+7).
DateTime vn(int day, int h, [int m = 0]) =>
    DateTime.utc(2026, 11, day, h, m).subtract(const Duration(hours: 7));

AdherenceDose dose(int schedule, String name, DateTime at,
        {AdherenceDoseStatus status = AdherenceDoseStatus.pending,
        DateTime? takenAt}) =>
    AdherenceDose(
        medicationId: schedule,
        medicationName: name,
        scheduleId: schedule,
        scheduledAt: at,
        takenAt: takenAt,
        status: status);

const _summary = AdherenceSummary(
    total: 0, taken: 0, late: 0, missed: 0, pending: 0, counted: 0, rate: null);

AdherenceHistory history(Map<int, List<AdherenceDose>> days,
        {required DateTime asOf, int fromDay = 13, int toDay = 19}) =>
    AdherenceHistory(
        patientId: 'mother',
        from: DateTime.utc(2026, 11, fromDay),
        to: DateTime.utc(2026, 11, toDay),
        asOf: asOf,
        summary: _summary,
        groups: [
          for (final e in days.entries)
            AdherenceDateGroup(
                date: DateTime.utc(2026, 11, e.key),
                summary: _summary,
                doses: e.value)
        ]);

void main() {
  // 09:00 sáng 19/11 giờ VN
  final asOf = vn(19, 9);
  final losartan =
      dose(1, 'Losartan', vn(19, 6, 30), status: AdherenceDoseStatus.missed);
  final vitamin = dose(2, 'Vitamin D3', vn(19, 7),
      status: AdherenceDoseStatus.taken, takenAt: vn(19, 7, 2));
  final metformin = dose(3, 'Metformin', vn(19, 12));
  final warfarin = dose(4, 'Warfarin', vn(19, 20));
  final today = [losartan, vitamin, metformin, warfarin];

  group('segmentOf / doseSegments (AC3)', () {
    test('đoạn tiến độ theo trạng thái từng liều', () {
      expect(doseSegments(today, asOf), [
        DoseSegment.missed,
        DoseSegment.taken,
        DoseSegment.upcoming,
        DoseSegment.upcoming,
      ]);
    });

    test('quá giờ chưa xác nhận là overdue, không bị coi là bỏ lỡ (QD-24/25)',
        () {
      final pending = dose(1, 'A', vn(19, 6, 30));
      final unverified =
          dose(1, 'A', vn(19, 6, 30), status: AdherenceDoseStatus.unverified);
      expect(segmentOf(pending, asOf), DoseSegment.overdue);
      expect(segmentOf(unverified, asOf), DoseSegment.overdue);
    });

    test('uống trễ có takenAt là late (QD-03)', () {
      final late = dose(1, 'A', vn(19, 6, 30),
          status: AdherenceDoseStatus.late, takenAt: vn(19, 8, 20));
      expect(segmentOf(late, asOf), DoseSegment.late);
    });

    test('liều đúng bằng asOf đã tới giờ', () {
      expect(segmentOf(dose(1, 'A', asOf), asOf), DoseSegment.overdue);
    });
  });

  group('hubSummary (AC3, AC4)', () {
    test('có liều bỏ lỡ: dòng đỏ nêu thuốc và giờ VN, có liều tới', () {
      final s = hubSummary(today, asOf);
      expect(s.line, '1/4 liều · Bỏ lỡ Losartan 06:30');
      expect(s.tone, SummaryTone.alert);
      expect(s.next, metformin);
    });

    test('quá giờ chưa xác nhận: báo chưa xác nhận', () {
      final s = hubSummary([dose(1, 'Losartan', vn(19, 6, 30)), vitamin], asOf);
      expect(s.line, '1/2 liều · Chưa xác nhận Losartan 06:30');
      expect(s.tone, SummaryTone.alert);
    });

    test('uống đủ: dòng xanh', () {
      final s = hubSummary([vitamin], asOf);
      expect(s.line, '1/1 liều · Đã uống đủ hôm nay');
      expect(s.tone, SummaryTone.good);
      expect(s.next, isNull);
    });

    test('không có lịch: trung tính', () {
      final s = hubSummary(const [], asOf);
      expect(s.line, 'Hôm nay không có lịch uống');
      expect(s.total, 0);
    });

    test('toàn liều tương lai: chưa tới giờ', () {
      final s = hubSummary([metformin, warfarin], asOf);
      expect(s.line, '0/2 liều · Chưa tới giờ');
      expect(s.tone, SummaryTone.neutral);
    });
  });

  group('careMood (AC4, AC5, AC6)', () {
    test('bỏ lỡ chưa nhắc → missed; đã nhắc → nudged', () {
      expect(careMood(today, asOf, nudged: (_) => false), CareMood.missed);
      expect(
          careMood(today, asOf, nudged: (d) => d == losartan), CareMood.nudged);
    });

    test('nhắc cho liều khác không làm thành nudged', () {
      expect(careMood(today, asOf, nudged: (d) => d == metformin),
          CareMood.missed);
    });

    test(
        'chỉ quá giờ chưa xác nhận (chưa nhắc) → overdue, không phải missed (review M5)',
        () {
      final pending = dose(1, 'Losartan', vn(19, 6, 30));
      final unverified = dose(1, 'Losartan', vn(19, 6, 30),
          status: AdherenceDoseStatus.unverified);
      expect(careMood([pending, vitamin], asOf, nudged: (_) => false),
          CareMood.overdue);
      expect(careMood([unverified, vitamin], asOf, nudged: (_) => false),
          CareMood.overdue);
      // có cả bỏ lỡ lẫn quá giờ: ưu tiên bỏ lỡ; đã nhắc thì nudged
      expect(careMood([pending, losartan], asOf, nudged: (_) => false),
          CareMood.missed);
      expect(careMood([pending], asOf, nudged: (_) => true), CareMood.nudged);
    });

    test('đã uống bù, không còn liều cần chú ý → recovered', () {
      final late = dose(1, 'Losartan', vn(19, 6, 30),
          status: AdherenceDoseStatus.late, takenAt: vn(19, 8, 20));
      expect(careMood([late, vitamin, metformin], asOf, nudged: (_) => true),
          CareMood.recovered);
    });

    test('mọi liều đúng giờ → ok', () {
      expect(careMood([vitamin, metformin], asOf, nudged: (_) => false),
          CareMood.ok);
    });
  });

  group('streakDays', () {
    AdherenceDose ok(int day) => dose(2, 'B', vn(day, 7),
        status: AdherenceDoseStatus.taken, takenAt: vn(day, 7, 5));

    test('5 ngày liên tục, hôm nay chưa tới giờ không làm đứt chuỗi', () {
      final h = history({
        14: [ok(14)],
        15: [ok(15)],
        16: [ok(16)],
        17: [ok(17)],
        18: [ok(18)],
        19: [metformin],
      }, asOf: asOf);
      expect(streakDays(h, asOf), 5);
    });

    test('một ngày bỏ lỡ làm đứt chuỗi', () {
      final h = history({
        16: [ok(16)],
        17: [dose(2, 'B', vn(17, 7), status: AdherenceDoseStatus.missed)],
        18: [ok(18)],
        19: [vitamin],
      }, asOf: asOf);
      expect(streakDays(h, asOf), 2);
    });

    test('hôm nay có liều bỏ lỡ → 0', () {
      final h = history({
        18: [ok(18)],
        19: [losartan, vitamin],
      }, asOf: asOf);
      expect(streakDays(h, asOf), 0);
    });

    test('không có dữ liệu → 0; không vượt quá khoảng from', () {
      expect(streakDays(history({}, asOf: asOf), asOf), 0);
      final h = history({
        18: [ok(18)],
        19: [vitamin],
      }, asOf: asOf, fromDay: 18);
      expect(streakDays(h, asOf), 2);
    });

    test('ranh giới nửa đêm VN: 23:59 ngày 18 thuộc ngày 18', () {
      final late = vn(18, 23, 59);
      final h = history({
        18: [
          dose(2, 'B', vn(18, 23, 30),
              status: AdherenceDoseStatus.taken, takenAt: vn(18, 23, 31))
        ],
      }, asOf: late, toDay: 18);
      expect(streakDays(h, late), 1);
    });
  });

  group('scheduleStrip (AC8)', () {
    test('7 ô theo ngày, đúng màu trạng thái, ngày không có liều là none', () {
      final h = history({
        13: [
          dose(1, 'L', vn(13, 6, 30),
              status: AdherenceDoseStatus.taken, takenAt: vn(13, 6, 31))
        ],
        14: [
          dose(1, 'L', vn(14, 6, 30),
              status: AdherenceDoseStatus.late, takenAt: vn(14, 8))
        ],
        15: [dose(1, 'L', vn(15, 6, 30), status: AdherenceDoseStatus.missed)],
        17: [dose(9, 'X', vn(17, 6, 30), status: AdherenceDoseStatus.taken)],
        19: [losartan],
      }, asOf: asOf);
      final strip = scheduleStrip(h, 1, asOf);
      expect(strip.length, 7);
      expect(strip.first.day, DateTime.utc(2026, 11, 13));
      expect(strip.last.day, DateTime.utc(2026, 11, 19));
      expect(strip.map((d) => d.mark), [
        StripMark.onTime,
        StripMark.late,
        StripMark.missed,
        StripMark.none,
        StripMark.none,
        StripMark.none,
        StripMark.missed,
      ]);
    });
  });

  group('formatDelay', () {
    test('giờ và phút', () {
      expect(formatDelay(const Duration(minutes: 105)), '1 giờ 45 phút');
      expect(formatDelay(const Duration(minutes: 45)), '45 phút');
      expect(formatDelay(const Duration(hours: 2)), '2 giờ');
      expect(formatDelay(const Duration(seconds: 20)), 'dưới 1 phút');
      expect(formatDelayShort(const Duration(minutes: 110)), '1g50');
      expect(formatDelayShort(const Duration(minutes: 9)), '9p');
    });
  });
}
