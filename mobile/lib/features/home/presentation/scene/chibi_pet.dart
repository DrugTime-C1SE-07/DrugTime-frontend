import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Trạng thái của pet chibi ở banner trang chủ. Tất cả là trạng thái giữ;
/// [PetBrain] tự quyết thời lượng.
enum PetMood {
  hidden,
  idle,
  walk,
  sit,

  /// Nằm ngửa thư giãn trên cỏ (xong mọi liều trong ngày).
  lie,
  sleepBlanket,

  /// Đang ngủ, bị gõ: hé mắt, lẩm bẩm.
  sleepPeek,

  /// Đang ngủ, bị gõ liên tục: cáu, trùm chăn kín đầu.
  grumpy,

  /// Đang ngủ mà mất chăn: co ro, run.
  shiver,
  yawn,
  stretch,
  carried,
  fall,
  flip,
  hug,
  tickle,

  /// Chỉ tay về phía trước, mắt nhìn xuống.
  point,

  /// Hai tay ôm trước ngực.
  hold,
  wave,
  poke,
  celebrate,
  concerned,
  thinking,

  /// Sốt ruột dễ thương: giậm chân, phồng má (còn liều chưa uống).
  stomp,
}

/// Bên điều khiển pet: đổi trạng thái, hướng nhìn, hướng mặt, chăn và gối.
class PetController extends ChangeNotifier {
  PetMood _mood = PetMood.hidden;
  int _seq = 0;
  Offset? _gaze;

  PetMood get mood => _mood;

  /// Tăng mỗi lần [play].
  int get seq => _seq;
  Offset? get gaze => _gaze;

  /// 1 = nhìn phải, -1 = nhìn trái. Rig đọc mỗi khung hình.
  double facing = 1;

  /// Độ phủ chăn do người dùng kéo (0..1); `null` thì theo tư thế.
  double? blanketOverride;

  /// Gối bị kéo lệch bao nhiêu (đơn vị khung 100).
  double pillowShift = 0;

  void play(PetMood mood) {
    _mood = mood;
    _seq++;
    notifyListeners();
  }

  void lookAt(Offset gaze) {
    _gaze = Offset(gaze.dx.clamp(-1.0, 1.0), gaze.dy.clamp(-1.0, 1.0));
  }

  void clearLook() => _gaze = null;
}

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

/// (giá trị gốc, độ cứng, giảm chấn).
const _specs = <String, (double, double, double)>{
  'pop': (0, 260, 15),
  'y': (0, 420, 24),
  'sq': (0, 480, 16),
  'tilt': (0, 200, 16),
  'face': (1, 260, 26),
  'lie': (0, 110, 20),
  'blanket': (0, 200, 24),
  'pillow': (0, 260, 26),
  'eye': (1, 600, 45),
  'eyeS': (1, 300, 20),
  'lx': (0, 700, 50),
  'ly': (0, 700, 50),
  'smile': (.6, 240, 28),
  'mouth': (.15, 260, 26),
  'cheek': (.8, 160, 24),
  'brow': (0, 220, 26),
  'puff': (0, 260, 22),
  'armL': (.25, 320, 22),
  'armR': (.25, 320, 22),
  'footL': (0, 900, 45),
  'footR': (0, 900, 45),
  'heart': (0, 160, 20),
  'zzz': (0, 120, 20),
  'stars': (0, 200, 18),
  'sweat': (0, 150, 22),
};

/// Bộ khung chuyển động của pet chibi: lò xo theo tham số, chớp mắt, thở.
///
/// Đơn vị khung 100×100, bàn chân ở (50, 96). [random] tiêm vào để test xác định được.
class ChibiRig extends ChangeNotifier {
  ChibiRig({math.Random? random}) : _rnd = random ?? math.Random();

  final math.Random _rnd;
  final Map<String, _Spring> _s = {
    for (final e in _specs.entries)
      e.key: _Spring(e.value.$1, e.value.$2, e.value.$3),
  };

  PetMood _mood = PetMood.hidden;
  double _t = 0, _time = 0;
  double _blink = 1, _nextBlink = 2, _blinkT = -1;

  PetMood get mood => _mood;

  /// Giây trôi qua (cho hiệu ứng nền như zzz, sao).
  double get time => _time;

  /// Hệ số chớp mắt 0..1 (1 = mở).
  double get blink => _blink;

  double value(String key) => _s[key]!.x;

  void setMood(PetMood mood) {
    if (mood == _mood) return;
    _mood = mood;
    _t = 0;
    if (mood == PetMood.poke) {
      _s['sq']!.v += 3;
      _s['y']!.v -= 60;
    }
  }

  /// Tiến thêm [dt] giây. [still]: snap về tư thế đích (khung tĩnh trong test).
  void tick(double dt, {required PetController ctl, bool still = false}) {
    _time += dt;
    _t += dt;
    final pose = _pose(_mood, _t, _time, ctl);
    pose['face'] ??= ctl.facing;
    if (ctl.blanketOverride != null && (pose['lie'] ?? 0) > .5) {
      pose['blanket'] = ctl.blanketOverride!;
    }
    pose['pillow'] = ctl.pillowShift;
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
        rem -= h;
      }
      _blink = _blinkStep(dt);
    }
    notifyListeners();
  }

  double _blinkStep(double dt) {
    if (_time > _nextBlink && _blinkT < 0) _blinkT = 0;
    if (_blinkT < 0) return 1;
    _blinkT += dt;
    final m = _blinkT < .06
        ? 1 - _blinkT / .06
        : (_blinkT < .15 ? (_blinkT - .06) / .09 : 1.0);
    if (_blinkT >= .15) {
      _blinkT = -1;
      _nextBlink = _time + 2.5 + _rnd.nextDouble() * 2.5;
    }
    return m;
  }

  /// Một nhịp nảy: 0 lúc chạm đất, 1 ở đỉnh.
  static double _hop(double t, double period) =>
      math.sin(math.pi * (t % period) / period).abs();

  Map<String, double> _pose(
      PetMood mood, double t, double time, PetController ctl) {
    final breathe = math.sin(time * 2 * math.pi * .25);
    final g = ctl.gaze ?? Offset.zero;
    final base = <String, double>{
      'pop': 1,
      'y': breathe * .8,
      'sq': breathe * .015,
      'lx': g.dx,
      'ly': g.dy,
    };
    switch (mood) {
      case PetMood.hidden:
        return {'pop': 0};
      case PetMood.idle:
        return {...base, 'tilt': g.dx * .06};
      case PetMood.walk:
        final h = _hop(time, .36);
        return {
          ...base,
          'y': -h * 7,
          'sq': h < .25 ? .1 : -.05 * h,
          'tilt': .06,
          'armL': .9 + h * .5,
          'armR': .9 + h * .5,
          'lx': .6,
          'smile': .8,
          'mouth': .25,
        };
      case PetMood.sit:
        return {
          ...base,
          'y': 6,
          'sq': .08,
          'armL': .4,
          'armR': .4,
          'smile': .7
        };
      case PetMood.lie:
        return {
          ...base,
          'lie': 1,
          'eye': .6,
          'smile': 1,
          'cheek': 1.1,
          'armL': 2.7,
          'armR': 2.7,
          'ly': -.5,
          'footL': math.max(0.0, math.sin(time * 1.6)) * 4,
        };
      case PetMood.sleepBlanket:
        return {
          ...base,
          'lie': 1,
          'blanket': 1,
          'eye': 0,
          'smile': .35,
          'mouth': .15 + math.max(0.0, breathe) * .12,
          'zzz': 1,
          'cheek': 1,
        };
      case PetMood.sleepPeek:
        return {
          ...base,
          'lie': 1,
          'blanket': 1,
          'eye': .35,
          'brow': -.3,
          'smile': 0,
          'mouth': .1 + math.max(0.0, math.sin(t * 14)) * .2,
          'lx': -.5,
        };
      case PetMood.grumpy:
        return {
          ...base,
          'lie': 1,
          'blanket': 1.3,
          'tilt': math.sin(t * 30) * .03 * math.max(0.0, 1 - t),
          'eye': .2,
          'brow': 1,
          'smile': -.6,
          'puff': .6,
        };
      case PetMood.shiver:
        return {
          ...base,
          'lie': 1,
          'tilt': math.sin(time * 45) * .03,
          'eye': .15,
          'brow': -.8,
          'smile': -.4,
          'armL': 1.5,
          'armR': 1.5,
          'cheek': .3,
        };
      case PetMood.yawn:
        final u = (math.sin(t * 1.4) + 1) / 2;
        return {
          ...base,
          'tilt': -.05,
          'eye': .1 + (1 - u) * .4,
          'smile': .1,
          'mouth': .3 + u * .7,
          'armL': .4 + u * 2.2,
        };
      case PetMood.stretch:
        return {
          ...base,
          'y': -4,
          'sq': -.08,
          'eye': .05,
          'smile': .7,
          'mouth': .5,
          'armL': 3,
          'armR': 3,
          'cheek': 1,
        };
      case PetMood.carried:
        return {
          ...base,
          'eyeS': 1.2,
          'smile': .5,
          'mouth': .6,
          'armL': 2.6 + math.sin(time * 9) * .25,
          'armR': 2.6 - math.sin(time * 9) * .25,
          'footL': -4 + math.sin(time * 6) * 2,
          'footR': -4 - math.sin(time * 6) * 2,
        };
      case PetMood.fall:
        return {
          ...base,
          'eyeS': 1.25,
          'smile': .2,
          'mouth': 1,
          'armL': 2.9 + math.sin(time * 18) * .3,
          'armR': 2.9 - math.sin(time * 18) * .3,
          'footL': -4,
          'footR': -4,
        };
      case PetMood.flip:
        return {
          ...base,
          'sq': -.06,
          'smile': 1,
          'mouth': .8,
          'armL': 2.8,
          'armR': 2.8,
          'stars': 1
        };
      case PetMood.hug:
        return {
          ...base,
          'tilt': math.sin(time * 2) * .05,
          'eye': .05,
          'smile': 1,
          'mouth': .35,
          'cheek': 1.4,
          'armL': 1.35,
          'armR': 1.35,
          'heart': 1,
        };
      case PetMood.tickle:
        return {
          ...base,
          'y': -_hop(time, .14) * 3,
          'tilt': math.sin(time * 18) * .08,
          'eye': .05,
          'smile': 1,
          'mouth': 1,
          'cheek': 1.4,
          'armL': 1.2,
          'armR': 1.2,
          'stars': .5,
        };
      case PetMood.point:
        return {
          ...base,
          'tilt': .05,
          'lx': .5,
          'ly': .9,
          'smile': .5,
          'mouth': .35,
          'armR': 1.65 + math.sin(time * 6) * .08,
        };
      case PetMood.hold:
        return {...base, 'armL': 1.3, 'armR': 1.3, 'smile': .8, 'mouth': .2};
      case PetMood.wave:
        return {
          ...base,
          'smile': 1,
          'mouth': .5,
          'armR': 2.7 + math.sin(t * 11) * .35,
          'eyeS': 1.05,
          'tilt': -.04,
        };
      case PetMood.poke:
        return {
          ...base,
          'eyeS': 1.25,
          'smile': .5,
          'mouth': .7,
          'armL': 1.6,
          'armR': 1.6
        };
      case PetMood.celebrate:
        final h = _hop(t, .42);
        return {
          ...base,
          'y': -h * 16,
          'sq': h < .2 ? .14 : -.08 * h,
          'eyeS': 1.12,
          'eye': .1,
          'smile': 1,
          'mouth': 1,
          'cheek': 1.3,
          'armL': 2.9,
          'armR': 2.9,
          'stars': 1,
        };
      case PetMood.concerned:
        return {
          ...base,
          'tilt': math.sin(time * 1.2) * .03,
          'ly': .7,
          'brow': -1,
          'smile': -.4,
          'mouth': .1,
          'sweat': 1,
          'cheek': .4,
          'armL': .15,
          'armR': .15,
        };
      case PetMood.thinking:
        return {
          ...base,
          'tilt': -.06,
          'lx': .8,
          'ly': -.8,
          'brow': -.4,
          'smile': 0,
          'mouth': .1,
          'armR': 1.25,
        };
      case PetMood.stomp:
        final s = math.sin(t * 13);
        return {
          ...base,
          'y': -math.max(0.0, s).abs() * 2,
          'tilt': s * .05,
          'ly': .7,
          'brow': .7,
          'smile': -.2,
          'mouth': .05,
          'puff': 1,
          'cheek': 1.3,
          'armL': .9,
          'armR': .9,
          'footL': math.max(0.0, s) * 6,
          'footR': math.max(0.0, -s) * 6,
        };
    }
  }
}
