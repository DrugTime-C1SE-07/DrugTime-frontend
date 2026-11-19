import 'dart:math' as math;

/// Vị trí quan sát trên mặt đất (độ).
class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);
  final double latitude, longitude;
}

/// Vị trí một thiên thể trên bầu trời của người quan sát (độ).
///
/// [altitude]: 0 là đường chân trời, 90 là thiên đỉnh. [azimuth]: 0 là Bắc, 90 là Đông, 180 là Nam.
class SkyPosition {
  const SkyPosition(this.altitude, this.azimuth);
  final double altitude, azimuth;
}

/// Trạng thái mặt trăng: vị trí, phần được chiếu sáng (0..1) và đang tròn dần hay khuyết dần.
class MoonState {
  const MoonState(this.position, this.illumination, this.waxing);
  final SkyPosition position;
  final double illumination;
  final bool waxing;
}

const _rad = math.pi / 180;
double _sin(double deg) => math.sin(deg * _rad);
double _cos(double deg) => math.cos(deg * _rad);
double _norm(double deg) => (deg % 360 + 360) % 360;

/// Thiên văn tối giản cho bầu trời trang chủ.
///
/// Mặt trời theo thuật toán NOAA; mặt trăng theo Meeus (chương 47) rút gọn các số hạng chính.
/// Chỉ dùng thời điểm tuyệt đối nên không phụ thuộc múi giờ của thiết bị.
class Astronomy {
  Astronomy._();

  /// Tọa độ tham chiếu cố định: Đà Nẵng. Không xin quyền vị trí của người dùng.
  static const daNang = GeoPoint(16.05, 108.20);

  /// Độ cao tâm mặt trời khi mọc/lặn (gồm khúc xạ và bán kính đĩa).
  static const sunHorizon = -0.833;

  static double _julian(DateTime t) =>
      t.toUtc().millisecondsSinceEpoch / 86400000 + 2440587.5;

  static SkyPosition _horizontal(
      double ra, double dec, double jd, GeoPoint at) {
    final d = jd - 2451545;
    final T = d / 36525;
    final gmst = 280.46061837 +
        360.98564736629 * d +
        0.000387933 * T * T -
        T * T * T / 38710000;
    final h = _norm(gmst + at.longitude - ra);
    final lat = at.latitude;
    final alt =
        math.asin(_sin(lat) * _sin(dec) + _cos(lat) * _cos(dec) * _cos(h)) /
            _rad;
    final az = math.atan2(_sin(h),
                _cos(h) * _sin(lat) - math.tan(dec * _rad) * _cos(lat)) /
            _rad +
        180;
    return SkyPosition(alt, _norm(az));
  }

  /// (kinh độ hoàng đạo biểu kiến, độ nghiêng hoàng đạo) của mặt trời, theo độ.
  static (double, double) _sunEcliptic(double jd) {
    final T = (jd - 2451545) / 36525;
    final l0 = _norm(280.46646 + T * (36000.76983 + T * 0.0003032));
    final m = 357.52911 + T * (35999.05029 - 0.0001537 * T);
    final c = _sin(m) * (1.914602 - T * (0.004817 + 0.000014 * T)) +
        _sin(2 * m) * (0.019993 - 0.000101 * T) +
        _sin(3 * m) * 0.000289;
    final omega = 125.04 - 1934.136 * T;
    final lambda = l0 + c - 0.00569 - 0.00478 * _sin(omega);
    final eps0 = 23 +
        (26 + (21.448 - T * (46.815 + T * (0.00059 - T * 0.001813))) / 60) / 60;
    return (lambda, eps0 + 0.00256 * _cos(omega));
  }

  static SkyPosition sun(DateTime t, {GeoPoint at = daNang}) {
    final jd = _julian(t);
    final (lambda, eps) = _sunEcliptic(jd);
    final ra = math.atan2(_cos(eps) * _sin(lambda), _cos(lambda)) / _rad;
    final dec = math.asin(_sin(eps) * _sin(lambda)) / _rad;
    return _horizontal(ra, dec, jd, at);
  }

  /// (kinh độ, vĩ độ hoàng đạo theo độ, khoảng cách km) của mặt trăng.
  static (double, double, double) _moonEcliptic(double jd) {
    final T = (jd - 2451545) / 36525;
    final lp = 218.3164477 + 481267.88123421 * T;
    final d = 297.8501921 + 445267.1114034 * T;
    final m = 357.5291092 + 35999.0502909 * T;
    final mp = 134.9633964 + 477198.8675055 * T;
    final f = 93.2720950 + 483202.0175233 * T;
    final e = 1 - 0.002516 * T;
    final l = 6.288774 * _sin(mp) +
        1.274027 * _sin(2 * d - mp) +
        0.658314 * _sin(2 * d) +
        0.213618 * _sin(2 * mp) -
        0.185116 * e * _sin(m) -
        0.114332 * _sin(2 * f) +
        0.058793 * _sin(2 * d - 2 * mp) +
        0.057066 * e * _sin(2 * d - m - mp) +
        0.053322 * _sin(2 * d + mp) +
        0.045758 * e * _sin(2 * d - m) -
        0.040923 * e * _sin(m - mp) -
        0.034720 * _sin(d) -
        0.030383 * e * _sin(m + mp) +
        0.015327 * _sin(2 * d - 2 * f) -
        0.012528 * _sin(mp + 2 * f) +
        0.010980 * _sin(mp - 2 * f) +
        0.010675 * _sin(4 * d - mp) +
        0.010034 * _sin(3 * mp) +
        0.008548 * _sin(4 * d - 2 * mp) -
        0.007888 * e * _sin(2 * d + m - mp) -
        0.006766 * e * _sin(2 * d + m) -
        0.005163 * _sin(d - mp) +
        0.004987 * e * _sin(d + m) +
        0.004036 * e * _sin(2 * d - m + mp);
    final b = 5.128122 * _sin(f) +
        0.280602 * _sin(mp + f) +
        0.277693 * _sin(mp - f) +
        0.173237 * _sin(2 * d - f) +
        0.055413 * _sin(2 * d - mp + f) +
        0.046271 * _sin(2 * d - mp - f) +
        0.032573 * _sin(2 * d + f) +
        0.017198 * _sin(2 * mp + f) +
        0.009266 * _sin(2 * d + mp - f) +
        0.008822 * _sin(2 * mp - f);
    final r = 385000.56 -
        20905.355 * _cos(mp) -
        3699.111 * _cos(2 * d - mp) -
        2955.968 * _cos(2 * d) -
        569.925 * _cos(2 * mp) +
        48.888 * e * _cos(m) -
        3.149 * _cos(2 * f) +
        246.158 * _cos(2 * d - 2 * mp) -
        152.138 * e * _cos(2 * d - m - mp) -
        170.733 * _cos(2 * d + mp) -
        204.586 * e * _cos(2 * d - m) -
        129.620 * e * _cos(m - mp) +
        108.743 * _cos(d) +
        104.755 * e * _cos(m + mp);
    final omega = 125.04452 - 1934.136261 * T;
    return (_norm(lp + l - 0.00478 * _sin(omega)), b, r);
  }

  static MoonState moon(DateTime t, {GeoPoint at = daNang}) {
    final jd = _julian(t);
    final (lambda, beta, dist) = _moonEcliptic(jd);
    final (sunLambda, eps) = _sunEcliptic(jd);
    final ra = math.atan2(
            _sin(lambda) * _cos(eps) - math.tan(beta * _rad) * _sin(eps),
            _cos(lambda)) /
        _rad;
    final dec = math.asin(
            _sin(beta) * _cos(eps) + _cos(beta) * _sin(eps) * _sin(lambda)) /
        _rad;
    final geo = _horizontal(ra, dec, jd, at);
    // Thị sai: mặt trăng gần nên người quan sát thấy thấp hơn tâm Trái Đất.
    final parallax = math.asin(6378.14 / dist) / _rad;
    final alt = geo.altitude - parallax * _cos(geo.altitude);

    const sunDist = 149597870.7;
    final psi = math.acos(_cos(beta) * _cos(lambda - sunLambda)) / _rad;
    final i =
        math.atan2(sunDist * _sin(psi), dist - sunDist * _cos(psi)) / _rad;
    final k = (1 + _cos(i)) / 2;
    return MoonState(
        SkyPosition(alt, geo.azimuth), k, _norm(lambda - sunLambda) < 180);
  }

  /// Lần đầu tiên sau [from] (trong [window]) mà [altitude] cắt [horizon] theo chiều
  /// [rising]. Quét bước 10 phút rồi chia đôi tới độ chính xác khoảng 1 giây.
  static DateTime? _crossing(double Function(DateTime) altitude, DateTime from,
      {required double horizon,
      required bool rising,
      Duration window = const Duration(hours: 30)}) {
    const step = Duration(minutes: 10);
    var a = from.toUtc();
    var fa = altitude(a) - horizon;
    final end = a.add(window);
    while (a.isBefore(end)) {
      final b = a.add(step);
      final fb = altitude(b) - horizon;
      if ((rising && fa < 0 && fb >= 0) || (!rising && fa >= 0 && fb < 0)) {
        var lo = a, hi = b;
        while (hi.difference(lo).inMilliseconds > 1000) {
          final mid = lo.add(hi.difference(lo) ~/ 2);
          final fm = altitude(mid) - horizon;
          if ((fm >= 0) == rising) {
            hi = mid;
          } else {
            lo = mid;
          }
        }
        return hi;
      }
      a = b;
      fa = fb;
    }
    return null;
  }

  static DateTime? sunrise(DateTime from, {GeoPoint at = daNang}) =>
      _crossing((t) => sun(t, at: at).altitude, from,
          horizon: sunHorizon, rising: true);

  static DateTime? sunset(DateTime from, {GeoPoint at = daNang}) =>
      _crossing((t) => sun(t, at: at).altitude, from,
          horizon: sunHorizon, rising: false);

  /// Mọc/lặn của mặt trăng tính theo tâm đĩa (đã trừ thị sai) cắt 0°.
  static DateTime? moonrise(DateTime from, {GeoPoint at = daNang}) =>
      _crossing((t) => moon(t, at: at).position.altitude, from,
          horizon: 0, rising: true);

  static DateTime? moonset(DateTime from, {GeoPoint at = daNang}) =>
      _crossing((t) => moon(t, at: at).position.altitude, from,
          horizon: 0, rising: false);

  /// Tiến độ của thiên thể trên cung trời hôm nay: 0 lúc mọc, 1 lúc lặn; `null` khi đang lặn.
  static double? _arc(DateTime now, double altitude, double horizon,
      DateTime? Function(DateTime) rise, DateTime? Function(DateTime) set) {
    if (altitude < horizon) return null;
    DateTime? last;
    var r = rise(now.subtract(const Duration(hours: 30)));
    while (r != null && !r.isAfter(now)) {
      last = r;
      r = rise(r.add(const Duration(minutes: 1)));
    }
    final next = set(now);
    if (last == null || next == null) return .5;
    final span = next.difference(last).inSeconds;
    return span <= 0 ? .5 : now.difference(last).inSeconds / span;
  }
}

/// Bầu trời tại một thời điểm, đủ để vẽ cảnh. Tính một lần mỗi phút.
class SkyNow {
  SkyNow._(this.at, this.sun, this.sunArc, this.moon, this.moonArc);

  factory SkyNow.at(DateTime now, {GeoPoint place = Astronomy.daNang}) {
    final sun = Astronomy.sun(now, at: place);
    final moon = Astronomy.moon(now, at: place);
    return SkyNow._(
      now,
      sun,
      Astronomy._arc(
          now,
          sun.altitude,
          Astronomy.sunHorizon,
          (t) => Astronomy.sunrise(t, at: place),
          (t) => Astronomy.sunset(t, at: place)),
      moon,
      Astronomy._arc(
          now,
          moon.position.altitude,
          0,
          (t) => Astronomy.moonrise(t, at: place),
          (t) => Astronomy.moonset(t, at: place)),
    );
  }

  final DateTime at;
  final SkyPosition sun;
  final MoonState moon;

  /// 0..1 từ lúc mọc tới lúc lặn; `null` khi dưới chân trời.
  final double? sunArc, moonArc;

  /// Độ sáng của trăng lên cảnh: độ rọi khi trăng đã mọc, 0 khi chưa.
  double get moonLight => moon.position.altitude > 0 ? moon.illumination : 0;
}
