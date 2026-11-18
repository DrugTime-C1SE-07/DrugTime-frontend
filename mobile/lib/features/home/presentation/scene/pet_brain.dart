import 'dart:math' as math;
import 'dart:ui';

import 'chibi_pet.dart';
import 'home_pet_signals.dart';
import 'pet_body.dart';

/// Vật pet cầm hoặc hiệu ứng đi kèm, do [PetPropsPainter] vẽ.
enum PetProp { none, clock, cloud, magnifier, flag, pillBox, confetti }

/// Tầng hành vi đang chi phối pet (để test và debug).
enum PetLayer {
  gesture,
  event,
  remind,
  sleep,
  failed,
  pending,
  missed,

  /// Còn liều chưa uống: thỉnh thoảng lên chip số liều, chỉ trỏ và giậm chân.
  remaining,
  allDone,
  onboarding,
  idle,
}

enum _Idle { stroll, climbChip, sitChip, watchSky, lookAround }

enum _Event { celebrate, flag, confused }

/// Nhận biết cử chỉ "xoa": ≥ 3 lần đổi hướng ngang trong 0,8 s.
class RubDetector {
  final _turns = <double>[];
  double _lastDx = 0;

  /// Trả `true` khi vừa đủ điều kiện xoa. [t]: giây, [dx]: dịch chuyển ngang của lần này.
  bool add(double t, double dx) {
    if (dx.abs() < 1.5) return false;
    if (_lastDx != 0 && dx.sign != _lastDx.sign) _turns.add(t);
    _lastDx = dx;
    _turns.removeWhere((x) => t - x > .8);
    if (_turns.length >= 3) {
      _turns.clear();
      return true;
    }
    return false;
  }

  void reset() {
    _turns.clear();
    _lastDx = 0;
  }
}

/// Bộ não của pet: chọn hành vi theo tầng ưu tiên, ra lệnh cho [PetBody] và [PetController].
///
/// Thuần (không widget); [random] tiêm vào để test xác định được.
class PetBrain {
  PetBrain(this.body, {math.Random? random}) : _rnd = random ?? math.Random();

  final PetBody body;
  final math.Random _rnd;
  final PetController ctl = PetController();

  /// Lần đầu trong phiên app pet đã dẫn người dùng mới tới "Thêm thuốc" chưa.
  static bool onboardingShown = false;

  double _now = 0;
  bool _started = false;
  int _seenConfirmed = 0, _seenFailed = 0;

  PetLayer layer = PetLayer.idle;
  PetProp prop = PetProp.none;

  /// Hiện tim nhỏ trên đầu.
  bool hearts = false;

  /// Lời thoại trong bong bóng (chỉ dùng khi giới thiệu nút chính), `null` thì không có.
  String? speech;

  /// Góc xoay thêm của cả pet (nhào lộn, đung đưa khi bị kéo), radian.
  double spin = 0;

  /// Điểm trên trời pet có thể ngắm (mặt trời hoặc mặt trăng), do banner cập nhật.
  Offset? skyPoint;

  /// Nhật ký các trạng thái đã phát, phục vụ test.
  final List<PetMood> played = [];

  // phản ứng ngắn do cử chỉ
  PetMood? _reaction;
  double _reactionUntil = 0;
  bool _holding = false;
  PetMood? _lastTapReaction;
  final _sleepTaps = <double>[];

  // chăn và gối
  double? _blanketPull;
  double _blanketFrom = 1, _blanketBackAt = -1, _blanketBackDur = .8;
  double _pillowPull = 0;
  double _pillowFrom = 0, _pillowBackAt = -1;

  // sự kiện
  _Event? _event;
  double _eventUntil = 0;
  final _queue = <_Event>[];
  double _spinFrom = -1;

  // ngủ / thức
  NightPhase? _phase;
  double _stretchUntil = 0, _nextYawn = 0;

  // rảnh
  _Idle? _idle;
  double _idleUntil = 0;
  bool _onboarding = false;
  double _onboardUntil = 0;

  PetMood get mood => ctl.mood;
  double get now => _now;

  /// Đang nằm ngủ ở chỗ ngủ (cử chỉ khi ngủ chỉ có tác dụng lúc này).
  bool get asleep => _sleeping;
  bool _sleepSpotReached = false;

  void _play(PetMood m) {
    if (ctl.mood == m) return;
    ctl.play(m);
    played.add(m);
    if (played.length > 400) played.removeAt(0);
  }

  // ---------------------------------------------------------------- cử chỉ

  void tapPet() {
    if (layer == PetLayer.sleep && _sleepSpotReached) {
      _sleepTaps
        ..add(_now)
        ..removeWhere((t) => _now - t > 2);
      if (_sleepTaps.length >= 3) {
        _sleepTaps.clear();
        _react(PetMood.grumpy, 3);
      } else {
        _react(PetMood.sleepPeek, 1.6);
      }
      return;
    }
    final options = [PetMood.wave, PetMood.poke, PetMood.hug]
      ..remove(_lastTapReaction);
    final m = options[_rnd.nextInt(options.length)];
    _lastTapReaction = m;
    _react(m, m == PetMood.poke ? 1 : 1.6);
    if (m == PetMood.hug) {
      hearts = true;
    }
  }

  void doubleTapPet() {
    if (_sleeping) return tapPet();
    _lastTapReaction = PetMood.flip;
    body.hop(520);
    _spinFrom = _now;
    _react(PetMood.flip, .9);
  }

  void longPressStart() {
    if (_sleeping) {
      _rubWhileAsleep();
      return;
    }
    _holding = true;
    hearts = true;
    _react(PetMood.hug, double.infinity);
  }

  void longPressEnd() {
    if (!_holding) return;
    _holding = false;
    _reactionUntil = _now + .6;
  }

  void rubPet() {
    if (_sleeping) return _rubWhileAsleep();
    _react(PetMood.tickle, 1.4);
  }

  void _rubWhileAsleep() {
    hearts = true;
    _react(PetMood.sleepBlanket, 2.2);
  }

  bool get _sleeping => layer == PetLayer.sleep && _sleepSpotReached;

  /// Bắt đầu kéo pet. Đang ngủ thì coi như gõ (không nhấc pet đang ngủ lên).
  bool grabPet(Offset finger) {
    if (_sleeping) {
      tapPet();
      return false;
    }
    body.grab(finger);
    _reaction = null;
    return true;
  }

  void dragPet(Offset finger, double dt) {
    body.dragTo(finger, dt);
    spin = (body.velocity.dx / 900).clamp(-.5, .5);
  }

  void releasePet(Offset fling) {
    body.release(fling);
  }

  /// Kéo chăn ra một phần [fraction] (0..1) chiều rộng pet.
  void dragBlanket(double fraction) {
    if (!_sleeping) return;
    _blanketPull = fraction.clamp(0.0, 1.0);
    _blanketBackAt = -1;
    ctl.blanketOverride = 1 - _blanketPull!;
    if (_blanketPull! > .45) _react(PetMood.shiver, double.infinity);
  }

  void releaseBlanket() {
    final pull = _blanketPull;
    if (pull == null) return;
    _blanketPull = null;
    _blanketFrom = 1 - pull;
    _blanketBackAt = _now;
    if (pull > .45) {
      // co ro một lúc rồi tự kéo chăn lại
      _blanketBackDur = 1.4;
      _react(PetMood.shiver, 1.1);
    } else {
      _blanketBackDur = .25;
      if (_reaction == PetMood.shiver) _reaction = null;
    }
  }

  void dragPillow(double shift) {
    if (!_sleeping) return;
    _pillowPull = shift.clamp(0.0, 60.0);
    _pillowBackAt = -1;
    ctl.pillowShift = _pillowPull;
    if (_pillowPull > 20) _react(PetMood.sleepPeek, double.infinity);
  }

  void releasePillow() {
    if (_pillowPull <= 0) return;
    _pillowFrom = _pillowPull;
    _pillowPull = 0;
    _pillowBackAt = _now;
    // giật gối lại, càu nhàu một chút rồi ngủ tiếp
    _react(PetMood.grumpy, 1.2);
  }

  void tapSky() {
    if (_sleeping) return;
    final p = skyPoint;
    if (p != null) {
      body.facing =
          (p.dx - body.feet.dx).sign == 0 ? 1 : (p.dx - body.feet.dx).sign;
    }
    ctl.lookAt(const Offset(0, -1));
    _react(PetMood.wave, 2);
  }

  /// Mốc chuỗi ngày vừa đạt (đã kiểm "chưa phát" ở bên ngoài).
  void celebrateMilestone(int days) => _queue.add(_Event.flag);

  void _react(PetMood m, double seconds) {
    _reaction = m;
    _reactionUntil = _now + seconds;
  }

  // ---------------------------------------------------------------- vòng lặp

  void tick(double dt, HomePetSignals s) {
    _now += dt;
    if (!_started) {
      _started = true;
      _seenConfirmed = s.confirmedSeq;
      _seenFailed = s.confirmFailedSeq;
      _phase = s.phase;
    }
    if (s.confirmedSeq != _seenConfirmed) {
      _seenConfirmed = s.confirmedSeq;
      _queue.add(_Event.celebrate);
    }
    if (s.confirmFailedSeq != _seenFailed) {
      _seenFailed = s.confirmFailedSeq;
      _queue.add(_Event.confused);
    }
    _trackPhase(s);
    if (!s.remaining) _nagging = false;
    _animateBedding();
    body.step(dt);

    spin = _spinFrom >= 0 && _now - _spinFrom < .6
        ? (_now - _spinFrom) / .6 * 2 * math.pi * body.facing
        : (body.motion == PetMotion.carried ? spin : 0);
    if (_spinFrom >= 0 && _now - _spinFrom >= .6) _spinFrom = -1;
    if (_reaction != null && _now > _reactionUntil) {
      if (_reaction == PetMood.hug) hearts = false;
      _reaction = null;
    }
    if (_reaction == null) hearts = false;

    _decide(s);
    ctl.facing = layer == PetLayer.sleep && _sleepSpotReached ? 1 : body.facing;
  }

  void _trackPhase(HomePetSignals s) {
    final p = s.phase;
    if (_phase == NightPhase.asleep && p != NightPhase.asleep) {
      _stretchUntil = _now + 2.6; // thức dậy, vươn vai
    }
    _phase = p;
  }

  void _animateBedding() {
    if (_blanketBackAt >= 0) {
      final u = ((_now - _blanketBackAt) / _blanketBackDur).clamp(0.0, 1.0);
      ctl.blanketOverride = _blanketFrom + (1 - _blanketFrom) * u;
      if (u >= 1) {
        _blanketBackAt = -1;
        ctl.blanketOverride = null;
      }
    }
    if (_pillowBackAt >= 0) {
      final u = ((_now - _pillowBackAt) / .5).clamp(0.0, 1.0);
      ctl.pillowShift = _pillowFrom * (1 - u);
      if (u >= 1) _pillowBackAt = -1;
    }
  }

  void _decide(HomePetSignals s) {
    speech = null;
    // 1. cử chỉ
    if (body.motion == PetMotion.carried) {
      layer = PetLayer.gesture;
      prop = PetProp.none;
      return _play(PetMood.carried);
    }
    if (body.motion == PetMotion.falling && _reaction != PetMood.flip) {
      layer = PetLayer.gesture;
      return _play(PetMood.fall);
    }
    final wantsSleep = s.phase == NightPhase.asleep && !s.inDoseWindow;
    if (_reaction != null) {
      // phản ứng khi ngủ giữ tầng ngủ để chăn/gối vẫn tương tác được
      layer =
          wantsSleep && _sleepSpotReached ? PetLayer.sleep : PetLayer.gesture;
      prop = PetProp.none;
      return _play(_reaction!);
    }

    // 2. sự kiện một lần
    if (_event != null && _now > _eventUntil) {
      if (_event == _Event.celebrate) _afterCelebrate();
      _event = null;
    }
    if (_event == null && _queue.isNotEmpty) {
      _event = _queue.removeAt(0);
      _eventUntil = _now + (_event == _Event.celebrate ? 2.6 : 2.4);
      if (!body.idle && body.motion != PetMotion.falling) {
        body.goTo(body.surface, body.feet.dx);
      }
    }
    if (_event != null) {
      layer = PetLayer.event;
      switch (_event!) {
        case _Event.celebrate:
          prop = PetProp.confetti;
          return _play(PetMood.celebrate);
        case _Event.flag:
          prop = PetProp.flag;
          return _play(PetMood.wave);
        case _Event.confused:
          prop = PetProp.none;
          return _play(PetMood.thinking);
      }
    }

    // 3. liều trong cửa sổ xác nhận: thức (kể cả giờ ngủ) và nhắc
    if (s.inDoseWindow) {
      _leaveSleep();
      layer = PetLayer.remind;
      _goGrass(.8);
      if (!body.idle) {
        prop = PetProp.clock;
        return _play(PetMood.walk);
      }
      ctl.lookAt(const Offset(.5, 1));
      final pointing = (_now % 4) < 2;
      prop = PetProp.clock;
      return _play(pointing ? PetMood.point : PetMood.hold);
    }

    // 4. giờ ngủ
    if (wantsSleep) {
      layer = PetLayer.sleep;
      prop = PetProp.none;
      if (!_sleepSpotReached) {
        if (body.idle &&
            (body.feet.dx - _sleepX).abs() < 2 &&
            body.surface.isGrass) {
          _sleepSpotReached = true;
        } else {
          if (body.idle) body.goTo(body.layout.grass, _sleepX);
          return _play(body.motion == PetMotion.climbing
              ? PetMood.carried
              : PetMood.walk);
        }
      }
      return _play(PetMood.sleepBlanket);
    }
    _leaveSleep();
    if (_now < _stretchUntil) {
      layer = PetLayer.idle;
      return _play(PetMood.stretch);
    }

    // 5–9: trạng thái của ngày
    if (s.failed && !s.loading) {
      layer = PetLayer.failed;
      return _stationed(
          .5, PetProp.magnifier, PetMood.hold, const Offset(0, 1));
    }
    if (s.pending) {
      layer = PetLayer.pending;
      return _stationed(
          .72, PetProp.cloud, PetMood.hold, const Offset(-.3, .3));
    }
    if (s.missedToday) {
      layer = PetLayer.missed;
      prop = PetProp.none;
      ctl.lookAt(const Offset(-.4, 1));
      return _idleLoop(s, calm: true);
    }
    if (s.remaining) {
      layer = PetLayer.remaining;
      prop = PetProp.none;
      return _remainingLoop(s);
    }
    if (s.allDone) {
      layer = PetLayer.allDone;
      return _stationed(.66, PetProp.none, PetMood.lie, null);
    }
    if (s.empty) {
      // Chưa có thuốc: pet "giới thiệu" nút chính — đứng sát đầu phải của nút, quay về
      // phía nút, nói qua bong bóng lời thoại, chỉ tay vào nút theo nhịp nảy của nút.
      layer = PetLayer.onboarding;
      prop = PetProp.none;
      final spot = besideChipsX();
      if (!onboardingShown && !_onboarding) {
        _onboarding = true;
        onboardingShown = true;
        _onboardUntil = double.infinity;
      }
      if (body.idle && (body.feet.dx - spot).abs() > 2) {
        body.goTo(body.layout.grass, spot);
      }
      if (!body.idle) {
        speech = null;
        return _play(PetMood.walk);
      }
      body.facing = -1;
      ctl.lookAt(const Offset(-.9, .4));
      if (_onboarding) {
        // lần đầu trong phiên: chỉ hẳn vào nút 3,5 s với lời mời rõ ràng
        if (_onboardUntil == double.infinity) _onboardUntil = _now + 3.5;
        speech = 'Bấm vào đây để bắt đầu nhé!';
        if (_now < _onboardUntil) return _play(PetMood.point);
        _onboarding = false;
      }
      speech = 'Cùng bắt đầu nhé!';
      // nhịp 3,2 s trùng chu kỳ nảy của nút: đầu chu kỳ vẫy tay về phía nút, còn lại
      // đứng cười. Không chỉ tay lặp lại (AC21: chỉ vào nút một lần mỗi phiên).
      final beat = (_now % 3.2) / 3.2;
      return _play(beat < .35 ? PetMood.wave : PetMood.idle);
    }
    // 10. rảnh
    layer = PetLayer.idle;
    prop = PetProp.none;
    _idleLoop(s, calm: false);
  }

  /// Chỗ ngủ: phía phải, cách chip cuối đủ xa để chăn (lấn sang trái khoảng 50 dp) không đè chip.
  double get _sleepX {
    final l = body.layout;
    final chipsRight =
        l.chips.isEmpty ? 0.0 : l.chips.map((r) => r.right).reduce(math.max);
    return math
        .max(l.width * .74, chipsRight + 56)
        .clamp(l.grass.left, l.width - 64);
  }

  // ------------------------------------------------------------ còn liều

  double _nextNag = -1;
  double? _nagArrive;
  bool _nagging = false;

  /// Thời điểm (giây) mỗi lần pet bắt đầu đi lên chip số liều; phục vụ test.
  final List<double> nagStarts = [];

  /// Chu kỳ 20–30 giây: lên chip số liều, chỉ vào con số 1,6 s, giậm chân 1,6 s.
  void _remainingLoop(HomePetSignals s) {
    if (_nextNag < 0) _nextNag = _now + 4;
    final chip = body.layout.chips.isEmpty ? null : body.layout.surfaces[1];
    if (!_nagging &&
        _now >= _nextNag &&
        chip != null &&
        body.fits(chip) &&
        body.motion != PetMotion.falling) {
      _nagging = true;
      _nagArrive = null;
      nagStarts.add(_now);
      _nextNag = _now + 20 + _rnd.nextDouble() * 10;
      body.goTo(chip, (chip.left + chip.right) / 2);
    }
    if (_nagging) {
      if (!body.idle) {
        return _play(
            body.motion == PetMotion.climbing ? PetMood.carried : PetMood.walk);
      }
      if (body.surface.chip == 0) {
        _nagArrive ??= _now;
        final u = _now - _nagArrive!;
        ctl.lookAt(const Offset(0, 1));
        if (u < 1.6) return _play(PetMood.point);
        if (u < 3.2) return _play(PetMood.stomp);
      }
      _nagging = false;
      _idle = null;
    }
    _idleLoop(s, calm: false);
  }

  void _leaveSleep() {
    _sleepSpotReached = false;
    ctl.blanketOverride = null;
    ctl.pillowShift = 0;
    _blanketPull = null;
    _blanketBackAt = _pillowBackAt = -1;
  }

  /// Chỗ đứng trên cỏ không nằm trước chip/nút (để không che chữ): nếu trùng thì lùi sang
  /// bên phải chip, hết chỗ thì sang bên trái.
  double clearOfChips(double x) => _clearOfChips(x);

  /// Chỗ đứng sát đầu phải của chip/nút cuối cùng (để pet "giới thiệu" nút).
  double besideChipsX() {
    final l = body.layout;
    if (l.chips.isEmpty) return _clearOfChips(l.width * .3);
    final right = l.chips.map((c) => c.right).reduce(math.max);
    return (right + l.petHalfWidth - 2).clamp(l.grass.left, l.grass.right);
  }

  double _clearOfChips(double x) {
    final l = body.layout;
    final hw = l.petHalfWidth;
    final grass = l.grass;
    var out = x.clamp(grass.left, grass.right);
    final chips = [...l.chips]..sort((a, b) => a.left.compareTo(b.left));
    for (var pass = 0; pass < 2; pass++) {
      for (final c in chips) {
        if (out > c.left - hw - 4 && out < c.right + hw + 4) {
          out = c.right + hw + 6;
        }
      }
    }
    if (out <= grass.right) return out;
    final first = chips.isEmpty ? null : chips.first;
    final left = first == null ? grass.right : first.left - hw - 6;
    return left >= grass.left ? left : grass.right;
  }

  void _goGrass(double fx) {
    final x = _clearOfChips(body.layout.width * fx);
    if (body.idle && (!body.surface.isGrass || (body.feet.dx - x).abs() > 2)) {
      body.goTo(body.layout.grass, x);
    }
  }

  void _stationed(double fx, PetProp p, PetMood m, Offset? gaze) {
    prop = p;
    _goGrass(fx);
    if (!body.idle) {
      return _play(
          body.motion == PetMotion.climbing ? PetMood.carried : PetMood.walk);
    }
    if (gaze != null) ctl.lookAt(gaze);
    _play(m);
  }

  void _afterCelebrate() {
    // nhảy lên chip số liều để "khoe"
    if (body.layout.chips.isEmpty) return;
    final s = body.layout.surfaces[1];
    if (!body.fits(s)) return;
    body.goTo(s, (s.left + s.right) / 2);
    _idle = _Idle.climbChip;
    _idleUntil = _now + 14;
  }

  void _idleLoop(HomePetSignals s, {required bool calm}) {
    if (s.phase == NightPhase.yawning && _now > _nextYawn && body.idle) {
      _nextYawn = _now + 9 + _rnd.nextDouble() * 4;
      _react(PetMood.yawn, 2.6);
      return _play(PetMood.yawn);
    }
    if (_idle == null || _now > _idleUntil) _pickIdle(calm);
    if (!body.idle) {
      return _play(
          body.motion == PetMotion.climbing ? PetMood.carried : PetMood.walk);
    }
    switch (_idle!) {
      case _Idle.climbChip:
        // tới nơi thì ngồi
        _idle = _Idle.sitChip;
        _idleUntil = _now + 4 + _rnd.nextDouble() * 3;
        return _play(PetMood.sit);
      case _Idle.sitChip:
        return _play(body.onChip
            ? PetMood.sit
            : (calm ? PetMood.concerned : PetMood.idle));
      case _Idle.watchSky:
        final p = skyPoint;
        if (p != null) {
          final d = p.dx - body.feet.dx;
          if (d.abs() > 4) body.facing = d.sign;
          ctl.lookAt(Offset((d / 120).clamp(-1, 1), -1));
        }
        return _play(calm ? PetMood.concerned : PetMood.idle);
      case _Idle.stroll:
      case _Idle.lookAround:
        return _play(calm ? PetMood.concerned : PetMood.idle);
    }
  }

  void _pickIdle(bool calm) {
    final chips = [
      for (var i = 0; i < body.layout.chips.length; i++)
        if (body.fits(body.layout.surfaces[i + 1])) i
    ];
    final roll = _rnd.nextDouble();
    final grass = body.layout.grass;
    if (!calm && chips.isNotEmpty && roll < .35) {
      final i = chips[_rnd.nextInt(chips.length)];
      final s = body.layout.surfaces[i + 1];
      _idle = _Idle.climbChip;
      body.goTo(s, s.left + _rnd.nextDouble() * (s.right - s.left));
      _idleUntil = _now + 18;
    } else if (roll < .7) {
      _idle = _Idle.stroll;
      final x = _clearOfChips(
          grass.left + _rnd.nextDouble() * (grass.right - grass.left));
      body.goTo(grass, x);
      _idleUntil = _now +
          2 +
          _rnd.nextDouble() * 3 +
          (x - body.feet.dx).abs() / PetBody.walkSpeed;
    } else if (!calm && roll < .85 && skyPoint != null) {
      _idle = _Idle.watchSky;
      _idleUntil = _now + 3 + _rnd.nextDouble() * 2;
    } else {
      _idle = _Idle.lookAround;
      _idleUntil = _now + 3 + _rnd.nextDouble() * 2;
      if (!calm) ctl.clearLook();
    }
  }
}
