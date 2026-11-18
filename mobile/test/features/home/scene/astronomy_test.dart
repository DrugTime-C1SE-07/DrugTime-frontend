import 'package:drugtime_mobile/features/home/presentation/scene/astronomy.dart';
import 'package:flutter_test/flutter_test.dart';

/// Số liệu tham chiếu sinh bằng PyEphem 4.2.1 cho Đà Nẵng (16.05°N, 108.20°E),
/// xem work/adhoc-20261117-home-living-banner/scratch/astro_reference.py.
DateTime _u(String iso) => DateTime.parse(iso);

/// Nửa đêm giờ Việt Nam của ngày [y]-[m]-[d], dưới dạng UTC.
DateTime _ictMidnight(int y, int m, int d) =>
    DateTime.utc(y, m, d).subtract(const Duration(hours: 7));

void _near(DateTime? actual, DateTime expected, Duration tolerance) {
  expect(actual, isNotNull);
  final diff = actual!.difference(expected).abs();
  expect(diff <= tolerance, isTrue,
      reason: 'got $actual, expected $expected (lệch $diff)');
}

void main() {
  group('Mặt trời (AC1)', () {
    const sun = [
      // ngày ICT, mọc UTC, lặn UTC, độ cao 12:00 ICT, phương vị 12:00 ICT
      (
        2026,
        3,
        20,
        '2026-03-19T22:51:38Z',
        '2026-03-20T10:58:02Z',
        73.736,
        184.716
      ),
      (
        2026,
        6,
        21,
        '2026-06-20T22:16:25Z',
        '2026-06-21T11:21:28Z',
        82.169,
        341.068
      ),
      (
        2026,
        9,
        23,
        '2026-09-22T22:36:16Z',
        '2026-09-23T10:42:51Z',
        73.108,
        197.748
      ),
      (
        2026,
        12,
        21,
        '2026-12-20T23:09:51Z',
        '2026-12-21T10:20:22Z',
        50.346,
        185.352
      ),
    ];
    for (final (y, m, d, rise, set, alt, az) in sun) {
      test('$y-$m-$d: mọc/lặn lệch ≤ 2 phút, độ cao trưa lệch ≤ 1°', () {
        final midnight = _ictMidnight(y, m, d);
        _near(
            Astronomy.sunrise(midnight), _u(rise), const Duration(minutes: 2));
        _near(Astronomy.sunset(midnight), _u(set), const Duration(minutes: 2));
        final noon = midnight.add(const Duration(hours: 12));
        final p = Astronomy.sun(noon);
        expect(p.altitude, closeTo(alt, 1));
        // Gần thiên đỉnh phương vị biến thiên nhanh; chỉ kiểm khi độ cao < 80°.
        if (alt < 80) expect(p.azimuth, closeTo(az, 3));
      });
    }

    test('2:00 sáng mặt trời dưới chân trời, 12:00 trên chân trời', () {
      final midnight = _ictMidnight(2026, 11, 17);
      expect(Astronomy.sun(midnight.add(const Duration(hours: 2))).altitude,
          lessThan(-30));
      expect(Astronomy.sun(midnight.add(const Duration(hours: 12))).altitude,
          greaterThan(45));
    });
  });

  group('Mặt trăng (AC2)', () {
    test('trăng tròn ≥ 0.97, trăng mới ≤ 0.03', () {
      for (final iso in ['2026-01-03T10:02:50Z', '2026-02-01T22:09:10Z']) {
        expect(Astronomy.moon(_u(iso)).illumination, greaterThanOrEqualTo(.97),
            reason: iso);
      }
      for (final iso in ['2026-01-18T19:51:54Z', '2026-02-17T12:01:04Z']) {
        expect(Astronomy.moon(_u(iso)).illumination, lessThanOrEqualTo(.03),
            reason: iso);
      }
    });

    test('tròn dần sau trăng mới, khuyết dần sau trăng tròn', () {
      expect(Astronomy.moon(_u('2026-01-22T12:00:00Z')).waxing, isTrue);
      expect(Astronomy.moon(_u('2026-01-07T12:00:00Z')).waxing, isFalse);
    });

    const moon = [
      // ngày ICT, mọc UTC, lặn UTC, độ cao 21:00 ICT, phương vị 21:00 ICT, độ rọi
      (
        2026,
        3,
        20,
        '2026-03-19T23:30:38Z',
        '2026-03-20T12:07:49Z',
        -24.861,
        290.235,
        .0314
      ),
      (
        2026,
        6,
        21,
        '2026-06-21T04:15:41Z',
        '2026-06-21T16:30:17Z',
        35.139,
        257.374,
        .4669
      ),
      (
        2026,
        9,
        23,
        '2026-09-23T08:31:57Z',
        '2026-09-22T19:19:24Z',
        58.653,
        170.793,
        .8965
      ),
      (
        2026,
        12,
        21,
        '2026-12-21T07:32:01Z',
        '2026-12-20T19:48:54Z',
        81.587,
        17.579,
        .9087
      ),
    ];
    for (final (y, m, d, rise, set, alt, az, k) in moon) {
      test('$y-$m-$d: mọc/lặn lệch ≤ 10 phút, vị trí lệch ≤ 1°', () {
        final midnight = _ictMidnight(y, m, d);
        _near(Astronomy.moonrise(midnight), _u(rise),
            const Duration(minutes: 10));
        _near(
            Astronomy.moonset(midnight), _u(set), const Duration(minutes: 10));
        final s = Astronomy.moon(midnight.add(const Duration(hours: 21)));
        expect(s.position.altitude, closeTo(alt, 1));
        if (alt < 80) expect(s.position.azimuth, closeTo(az, 2));
        expect(s.illumination, closeTo(k, .02));
      });
    }
  });

  test('kết quả chỉ phụ thuộc thời điểm tuyệt đối, không theo múi giờ (AC12)',
      () {
    final utc = DateTime.utc(2026, 11, 17, 15, 30);
    final local = utc.toLocal();
    expect(Astronomy.sun(local).altitude, Astronomy.sun(utc).altitude);
    expect(
        Astronomy.moon(local).illumination, Astronomy.moon(utc).illumination);
  });
}
