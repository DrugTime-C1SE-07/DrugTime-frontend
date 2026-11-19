import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'mascot_controller.dart';

/// Lò xo một chiều; giảm chấn thấp thì nảy nhiều (follow-through).
class _Spring {
  _Spring(this.x, this.k, this.c) : target = x;
  double x, v = 0, target;
  final double k, c;

  void step(double dt) {
    final a = -k * (x - target) - c * v;
    v += a * dt;
    x += v * dt;
  }
}

/// (giá trị gốc, độ cứng, giảm chấn) cho từng tham số của linh vật.
const _specs = <String, (double, double, double)>{
  'pop': (0, 260, 13),
  'y': (40, 340, 21),
  'sq': (0, 430, 13),
  'tilt': (0, 170, 12),
  'hlx': (73, 230, 16),
  'hly': (213, 230, 16),
  'hrx': (227, 230, 16),
  'hry': (213, 230, 16),
  'lx': (0, 900, 55),
  'ly': (0, 900, 55),
  'open': (1, 520, 42),
  'smile': (.7, 220, 26),
  'mopen': (.42, 220, 24),
  'mw': (15, 220, 26),
  'brow': (0, 200, 26),
  'browT': (0, 200, 26),
  'browY': (0, 200, 26),
  'browRY': (0, 200, 26),
  'burst': (0, 210, 15),
  'zzz': (0, 120, 20),
  'sweat': (0, 150, 22),
  'think': (0, 150, 22),
  'cheek': (.9, 150, 22),
  'shield': (0, 220, 17),
  'eyeS': (1, 280, 16),
  'pd': (1, 260, 20),
  'star': (0, 200, 18),
  'hw': (0, 400, 40),
  'shadowA': (1, 200, 26),
  // Phụ kiện đầu bếp: lò xo phụ bị "đá" theo gia tốc của thân/tay → trễ và nảy (follow-through).
  'hatY': (0, 260, 11),
  'hatT': (0, 150, 7),
  'bowlT': (0, 170, 9),
  'toss': (0, 320, 16),
  'spark': (0, 150, 20),
};

/// Thời lượng (giây) của các trạng thái tự kết thúc.
const _durations = <MascotMood, double>{
  MascotMood.climb: 3.05,
  MascotMood.wave: 2.6,
  MascotMood.celebrate: 2.55,
  MascotMood.poke: 1.0,
};

double _easeInOut(double u) =>
    u < .5 ? 2 * u * u : 1 - math.pow(-2 * u + 2, 2) / 2;

/// Bộ khung chuyển động của linh vật: lò xo, tư thế theo trạng thái, chớp mắt, liếc mắt.
///
/// Không phụ thuộc widget; [MascotView] gọi [tick] mỗi khung hình. [random] tiêm vào để test
/// xác định được.
class MascotRig extends ChangeNotifier {
  MascotRig({math.Random? random}) : _rnd = random ?? math.Random();

  final math.Random _rnd;
  final Map<String, _Spring> _s = {
    for (final e in _specs.entries)
      e.key: _Spring(e.value.$1, e.value.$2, e.value.$3),
  };

  MascotMood _mood = MascotMood.hidden;
  MascotMood _return = MascotMood.idle;
  double _t = 0, _time = 0, _lookAt = -99;
  int _gazeStamp = 0;
  double _blink = 1, _nextBlink = 1.5, _blinkT = -1;
  bool _dbl = false;
  double _sacX = 0, _sacY = 0, _nextSac = .8, _nextFidget = 7;
  bool _peek = false;
  double _prevYV = 0, _prevTiltV = 0, _prevHandV = 0;

  /// Trang phục hiện tại; [MascotView] gán mỗi lần build.
  MascotOutfit outfit = MascotOutfit.plain;

  MascotMood get mood => _mood;

  /// Đồng hồ chuyển động nền (giây), đứng yên khi giảm chuyển động.
  double get time => _time;

  /// Hệ số chớp mắt 0..1 (1 = mở).
  double get blink => _blink;

  bool get peek => _peek;

  /// Đã về tư thế nghỉ (không trong hiệu ứng chuyển tiếp có thời lượng và đã qua khung hình khởi tạo).
  bool get isSettled => !_durations.containsKey(_mood) && _t >= 0.8;

  double value(String key) => _s[key]!.x;

  /// Vào trạng thái [mood]. Với [still] (giảm chuyển động), các trạng thái tự kết thúc
  /// được hiển thị bằng trạng thái sẽ quay về, để không kẹt ở một tư thế chuyển tiếp.
  void setMood(MascotMood mood, {required double ledge, bool still = false}) {
    if (still && _durations.containsKey(mood)) {
      mood = mood == MascotMood.poke || mood == MascotMood.celebrate
          ? _return
          : MascotMood.idle;
    }
    // `hidden` không phải trạng thái để quay về: nếu không, wave/poke từ lúc mới hiện sẽ làm linh vật biến mất.
    if (!_durations.containsKey(mood) && mood != MascotMood.hidden) {
      _return = mood;
    }
    if (mood == MascotMood.climb) _return = MascotMood.idle;
    _mood = mood;
    _t = 0;
    if (mood == MascotMood.poke) {
      final side = _rnd.nextBool() ? 1.0 : -1.0;
      _kick('sq', 3.4);
      _kick('tilt', 2.6 * side);
      _kick('y', -140);
    }
    if (mood == MascotMood.climb) {
      // bắt đầu ẩn sau form, tay ở dưới mép
      _snap({
        'pop': 1,
        'y': ledge - 56,
        'hw': 1,
        'shadowA': 0,
        'hlx': 100,
        'hly': ledge + 70,
        'hrx': 200,
        'hry': ledge + 70,
      });
    }
  }

  /// Tiến thêm [dt] giây. [still] = giảm chuyển động: snap về tư thế đích, không chớp mắt.
  void tick(double dt, {required MascotController ctl, required bool still}) {
    _peek = ctl.peek;
    if (ctl.gazeStamp != _gazeStamp) {
      _gazeStamp = ctl.gazeStamp;
      _lookAt = _time;
    }
    if (!still) _time += dt;
    _t += dt;
    final d = _durations[_mood];
    if (!still && d != null && _t > d) {
      final next = _mood == MascotMood.climb ? MascotMood.wave : _return;
      setMood(next, ledge: ctl.ledge);
      if (next == MascotMood.wave) _return = MascotMood.idle;
    }

    final pose = _pose(_mood, _t, _time, ctl);
    if (outfit == MascotOutfit.chef) _chefPose(pose);
    if (!still) _wander(pose, ctl);

    for (final e in _s.entries) {
      e.value.target = pose[e.key] ?? _specs[e.key]!.$1;
    }
    if (still) {
      for (final sp in _s.values) {
        sp
          ..x = sp.target
          ..v = 0;
      }
      _blink = 1;
    } else {
      var rem = dt;
      while (rem > 0) {
        final h = math.min(rem, 1 / 240);
        for (final sp in _s.values) {
          sp.step(h);
        }
        if (outfit == MascotOutfit.chef) _followThrough();
        rem -= h;
      }
      _blink = _blinkStep(dt);
    }
    notifyListeners();
  }

  void _kick(String key, double dv) => _s[key]!.v += dv;

  /// Mũ và bát "đi sau" thân: đổi vận tốc của thân/tay thành cú đá ngược chiều cho lò xo phụ.
  void _followThrough() {
    final yv = _s['y']!.v, tv = _s['tilt']!.v, hv = _s['hry']!.v;
    _s['hatY']!.v += (_prevYV - yv) * .32;
    _s['hatT']!.v += (_prevTiltV - tv) * .9 + (_prevYV - yv) * .0008;
    _s['bowlT']!.v += (_prevHandV - hv) * .0035;
    _prevYV = yv;
    _prevTiltV = tv;
    _prevHandV = hv;
  }

  /// Đầu bếp: tay phải luôn bưng bát (trừ khi đang nấu / ăn mừng), vẫy bằng tay trái.
  void _chefPose(Map<String, double> pose) {
    pose['spark'] = _mood == MascotMood.hidden ? 0 : 1;
    if (_mood == MascotMood.cooking || _mood == MascotMood.celebrate) return;
    if (_mood == MascotMood.wave || _mood == MascotMood.protect) {
      pose['hlx'] = 300 - (pose['hrx'] ?? 227);
      pose['hly'] = pose['hry'] ?? 213;
    }
    final breathe = math.sin(_time * 2.2);
    pose['hrx'] = 238;
    pose['hry'] = 198 + breathe * 1.5;
  }

  void _snap(Map<String, double> values) {
    values.forEach((k, v) => _s[k]!
      ..x = v
      ..v = 0);
  }

  /// Liếc mắt ngẫu nhiên và cử động lặt vặt khi đứng chờ lâu.
  void _wander(Map<String, double> pose, MascotController ctl) {
    if (_time > _nextSac) {
      final looking = ctl.gaze != null && _time - _lookAt < 3;
      final roam = _mood == MascotMood.idle && !looking;
      final amp = roam ? .8 : (looking ? .1 : .28);
      _sacX = (_rnd.nextDouble() * 2 - 1) * amp;
      _sacY = (_rnd.nextDouble() * 2 - 1) * amp * .6;
      if (roam && _rnd.nextDouble() < .3) _sacX = _sacY = 0;
      _nextSac = _time +
          (roam ? .7 + _rnd.nextDouble() * 1.6 : 1.1 + _rnd.nextDouble() * 2);
    }
    const fixedEyes = {
      MascotMood.sleepy,
      MascotMood.cover,
      MascotMood.hidden,
      MascotMood.climb
    };
    if (!fixedEyes.contains(_mood)) {
      pose['lx'] = ((pose['lx'] ?? 0) + _sacX).clamp(-1.0, 1.0);
      pose['ly'] = ((pose['ly'] ?? 0) + _sacY).clamp(-1.0, 1.0);
    }
    if (_mood == MascotMood.idle && _time > _nextFidget) {
      switch (_rnd.nextInt(3)) {
        case 0:
          _kick('y', -150);
          _kick('sq', -2.2);
        case 1:
          _kick('tilt', (_rnd.nextBool() ? 1 : -1) * 1.4);
        default:
          _kick('hry', -260);
      }
      _nextFidget = _time + 6 + _rnd.nextDouble() * 5;
    }
  }

  double _blinkStep(double dt) {
    if (_time > _nextBlink && _blinkT < 0) _blinkT = 0;
    if (_blinkT < 0) return 1;
    _blinkT += dt;
    final m = _blinkT < .06
        ? 1 - _blinkT / .06
        : (_blinkT < .14 ? (_blinkT - .06) / .08 : 1.0);
    if (_blinkT >= .14) {
      _blinkT = -1;
      if (!_dbl && _rnd.nextDouble() < .25) {
        _dbl = true;
        _nextBlink = _time + .1;
      } else {
        _dbl = false;
        _nextBlink = _time + 2.4 + _rnd.nextDouble() * 3.2;
      }
    }
    return m;
  }

  Map<String, double> _pose(
      MascotMood mood, double t, double time, MascotController ctl) {
    final breathe = math.sin(time * 2.2);
    final g = ctl.gaze ?? Offset.zero;
    switch (mood) {
      case MascotMood.hidden:
        return {'pop': 0, 'y': 40, 'open': 0};
      case MascotMood.climb:
        return _climb(t, ctl.ledge);
      case MascotMood.idle:
        return {
          'pop': 1,
          'y': breathe * 1.6,
          'sq': breathe * .012,
          'tilt': -.02 + math.sin(time * .7) * .012,
          'lx': g.dx,
          'ly': g.dy,
          'hly': 213 + breathe * 1.5,
          'hry': 213 + math.sin(time * 2.2 + .4) * 1.5,
          'mopen': .32 + breathe * .04,
        };
      case MascotMood.wave:
        return {
          'pop': 1,
          'y': breathe * 2,
          'tilt': -.06 + math.sin(t * 2.4) * .03,
          'hrx': 240 + math.sin(t * 11) * 6,
          'hry': 144 + math.cos(t * 11) * 2,
          'eyeS': 1.06,
          'pd': 1.1,
          'smile': 1,
          'mopen': .75,
          'burst': .9,
          'lx': g.dx * .5,
          'ly': .1,
        };
      case MascotMood.celebrate:
        return _celebrate(t);
      case MascotMood.protect:
        return {
          'pop': 1,
          'y': breathe * 2,
          'tilt': .04,
          'shield': 1,
          'hlx': 94,
          'hly': 204,
          'hrx': 244,
          'hry': 148 + math.sin(time * 3) * 2,
          'eyeS': 1.04,
          'pd': 1.05,
          'smile': .9,
          'mopen': .6,
          'burst': .6,
        };
      case MascotMood.concerned:
        return {
          'pop': 1,
          'y': math.sin(time * 1.5) * 1.5,
          'sq': -.012,
          'tilt': math.sin(time * 1.2) * .03,
          'ly': -.7,
          'brow': 1,
          'browT': 20,
          'browY': -2,
          'pd': 1.25,
          'smile': -.35,
          'mopen': .12,
          'mw': 10,
          'sweat': 1,
          'hlx': 134,
          'hly': 204,
          'hrx': 166,
          'hry': 204,
          'cheek': .4,
        };
      case MascotMood.sleepy:
        return {
          'pop': 1,
          'y': math.sin(time * 1.1) * 3,
          'sq': math.sin(time * 1.1) * .02,
          'tilt': .1,
          'open': .05,
          'smile': .1,
          'mopen': .35 + math.sin(time * 1.1) * .12,
          'mw': 7,
          'zzz': 1,
          'hlx': 84,
          'hly': 216,
          'hrx': 216,
          'hry': 216,
          'cheek': .8,
        };
      case MascotMood.thinking:
        return {
          'pop': 1,
          'y': math.sin(time * 2) * 1.5,
          'tilt': -.06 + math.sin(time * 1.3) * .02,
          'lx': .8,
          'ly': -.8,
          'brow': 1,
          'browRY': -6,
          'smile': .1,
          'mopen': .1,
          'mw': 9,
          'think': 1,
          'hrx': 170,
          'hry': 168 + math.sin(t * 8) * 1.5,
          'cheek': .6,
          'pd': .95,
        };
      case MascotMood.cover:
        final pk = ctl.peek ? 1.0 : 0.0;
        return {
          'pop': 1,
          'y': math.sin(time * 2) * 1.5,
          'open': 0,
          'smile': .9,
          'mopen': .45,
          'cheek': 1,
          'hlx': 122,
          'hly': 118,
          'hrx': 178 + pk * 20,
          'hry': 118 + pk * 20,
          'lx': -.8 * pk,
        };
      case MascotMood.cooking:
        // nhún theo nhịp 2,5 nhịp/giây, lắc bát, tay trái cổ vũ; rau trong bát bật lên mỗi nhịp
        final beat = time * 5.2;
        final hop = math.max(0.0, math.sin(beat));
        return {
          'pop': 1,
          'y': -hop * 7,
          'sq': (math.sin(beat) < 0 ? -math.sin(beat) : 0) * .06 - hop * .03,
          'tilt': math.sin(beat * .5) * .05,
          'hrx': 222 + math.sin(beat * 2) * 5,
          'hry': 182 + math.cos(beat * 2) * 3,
          'hlx': 66 + math.sin(beat) * 4,
          'hly': 166 - hop * 16,
          'lx': .55,
          'ly': .35,
          'eyeS': 1.05,
          'smile': .95,
          'mopen': .6,
          'cheek': 1,
          'toss': hop,
          'star': hop * .6,
        };
      case MascotMood.poke:
        return {
          'pop': 1,
          'eyeS': 1.2,
          'pd': .7,
          'ly': -.3,
          'smile': .6,
          'mopen': .8,
          'mw': 11,
          'hlx': 70,
          'hly': 176,
          'hrx': 230,
          'hry': 176,
          'burst': .8,
        };
    }
  }

  /// Leo lên: bám mép form ([ledge]) → ngó lên → lấy sức → đu lên → nhảy lên mây → tiếp đất.
  Map<String, double> _climb(double t, double ledge) {
    const effort = <String, double>{
      'open': .5,
      'brow': 1,
      'browT': -12,
      'smile': .1,
      'mopen': .2,
      'mw': 12
    };
    Map<String, double> grip(double y,
            {double hx = 0, Map<String, double> extra = const {}}) =>
        {
          'pop': 1,
          'y': y,
          'hw': 1,
          'shadowA': 0,
          'hlx': 112 - hx,
          'hly': ledge - 10,
          'hrx': 188 + hx,
          'hry': ledge - 10,
          ...extra,
        };
    if (t < .55) {
      // hai tay lần lượt "chộp" lên mép (trái trước, phải sau)
      return {
        'pop': 1,
        'y': ledge - 56,
        'hw': 1,
        'shadowA': 0,
        'hlx': 100,
        'hly': t < .22 ? ledge + 70 : ledge - 10,
        'hrx': 200,
        'hry': t < .38 ? ledge + 70 : ledge - 10,
      };
    }
    if (t < 1.55) {
      // ngó lên: liếc trái, liếc phải, rồi nhìn người dùng
      final look = t < .95 ? -.85 : (t < 1.3 ? .85 : 0.0);
      return grip(ledge - 128, hx: 26, extra: {
        'lx': look,
        'ly': -.15,
        'smile': .45,
        'mopen': .15,
        'eyeS': 1.08
      });
    }
    if (t < 1.72) {
      return grip(ledge - 116,
          hx: 26, extra: {'sq': .08, ...effort}); // lấy sức
    }
    if (t < 2.05) {
      return grip(ledge - 272,
          hx: -6, extra: {'sq': -.08, ...effort}); // đu người lên
    }
    if (t < 2.28) {
      // đứng trên mép form, buông tay, nhún lấy đà
      return {
        'pop': 1,
        'y': ledge - 268,
        'sq': t > 2.14 ? .14 : 0,
        'hw': 0,
        'shadowA': 0,
        'smile': .8,
        'mopen': .45
      };
    }
    if (t < 2.52) {
      return {
        'pop': 1,
        'y': -24,
        'sq': -.1,
        'hw': 0,
        'shadowA': .4,
        'hlx': 60,
        'hly': 150,
        'hrx': 240,
        'hry': 150,
        'smile': 1,
        'mopen': .7,
        'eyeS': 1.1,
      };
    }
    if (t < 2.75) {
      // tiếp đất
      return {
        'pop': 1,
        'y': 0,
        'sq': .15,
        'shadowA': 1,
        'smile': 1,
        'mopen': .6
      };
    }
    return {
      'pop': 1,
      'y': 0,
      'shadowA': 1,
      'smile': 1,
      'mopen': .55,
      'eyeS': 1.06,
      'burst': .7
    };
  }

  /// Ăn mừng: lấy đà → bật lên (giãn) → tiếp đất (co), lặp mỗi 0,85 s.
  Map<String, double> _celebrate(double t) {
    final ph = (t % .85) / .85;
    double y = 0, sq = 0, up = .4;
    if (ph < .2) {
      final u = _easeInOut(ph / .2);
      y = 5 * u;
      sq = .13 * u;
      up = .2;
    } else if (ph < .62) {
      final u = (ph - .2) / .42;
      y = -36 * math.sin(math.pi * u);
      sq = -.09 * math.cos(math.pi * u).abs();
      up = 1;
    } else if (ph < .8) {
      final u = (ph - .62) / .18;
      y = 3 * math.sin(math.pi * u);
      sq = .15 * math.sin(math.pi * u);
    }
    return {
      'pop': 1,
      'y': y,
      'sq': sq,
      'tilt': math.sin(ph * math.pi * 2) * .04,
      'hlx': 56 + (1 - up) * 16,
      'hly': 134 + (1 - up) * 50,
      'hrx': 244 - (1 - up) * 16,
      'hry': 134 + (1 - up) * 50,
      'eyeS': 1.15,
      'pd': 1.25,
      'star': 1,
      'ly': -.2,
      'smile': 1,
      'mopen': 1,
      'burst': 1,
    };
  }
}
