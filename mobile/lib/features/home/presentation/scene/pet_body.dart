import 'dart:math' as math;
import 'dart:ui';

import 'scene_layout.dart';

enum PetMotion { standing, walking, climbing, falling, carried }

/// Thân pet trong banner: vị trí bàn chân, vận tốc, bề mặt đang đứng.
///
/// Thuần, không phụ thuộc widget. [PetBrain] ra lệnh ([goTo], [grab], [release]);
/// [step] tiến mô phỏng. Mọi vị trí đều được kẹp trong khung và ngoài vùng chữ.
class PetBody {
  PetBody(this._layout, {double? x}) {
    final sx = (x ?? _layout.width * .75)
        .clamp(_layout.grass.left, _layout.grass.right);
    feet = Offset(sx, _layout.grassY(sx));
    surface = _layout.grass;
  }

  static const height = 84.0;
  static const walkSpeed = 38.0;
  static const gravity = 1800.0;
  static const climbTime = 1.1;

  SceneLayout _layout;
  SceneLayout get layout => _layout;

  late Offset feet;
  Offset velocity = Offset.zero;
  late Surface surface;
  PetMotion motion = PetMotion.standing;

  /// 1 = nhìn phải, -1 = nhìn trái.
  double facing = 1;

  /// Kế hoạch di chuyển: các chặng (bề mặt đích, x đích) lần lượt.
  final List<(Surface, double)> _plan = [];
  double _climb = 0;
  Offset _climbFrom = Offset.zero, _climbTo = Offset.zero;
  Surface? _climbOnto;
  Offset _grabOffset = Offset.zero;

  bool get idle => motion == PetMotion.standing && _plan.isEmpty;
  bool get onChip => !surface.isGrass;

  /// Tiến độ leo (0..1) khi đang leo.
  double get climbProgress => _climb / climbTime;

  Rect get rect => _layout.petRect(feet, height);

  /// Pet đứng ở giữa bề mặt [s] có lọt khung và không che chữ không.
  bool fits(Surface s) {
    final x = (s.left + s.right) / 2;
    return _layout.allows(_layout.petRect(Offset(x, s.y(x)), height));
  }

  /// Cập nhật hình học (đổi kích thước, chip di chuyển). Pet đứng trên chip đã mất thì rơi.
  void updateLayout(SceneLayout l) {
    _layout = l;
    _plan.clear();
    if (motion == PetMotion.carried || motion == PetMotion.falling) return;
    final chip = surface.chip;
    if (chip != null && chip >= l.chips.length) {
      _startFall(Offset.zero);
      return;
    }
    surface = chip == null ? l.grass : l.surfaces[chip + 1];
    final x = feet.dx.clamp(surface.left, surface.right);
    feet = Offset(x, surface.y(x));
    if (motion == PetMotion.climbing) motion = PetMotion.standing;
  }

  /// Đi tới [x] trên bề mặt [target] (cỏ hoặc chip). Tự chèn chặng leo lên/nhảy xuống.
  void goTo(Surface target, double x) {
    if (motion == PetMotion.carried || motion == PetMotion.falling) return;
    _plan.clear();
    final tx = x.clamp(target.left, target.right);
    if (target.chip == surface.chip) {
      _plan.add((target, tx));
      return;
    }
    if (!surface.isGrass) {
      // xuống cỏ trước: tới mép chip gần đích rồi nhảy
      final rightEdge = tx > feet.dx;
      _plan.add((surface, rightEdge ? surface.right : surface.left));
      _plan.add((_layout.grass, double.nan)); // nhảy xuống
    }
    if (!target.isGrass) {
      final r = _layout.chips[target.chip!];
      final fromLeft = (surface.isGrass ? feet.dx : tx) < r.center.dx;
      final side = fromLeft
          ? r.left - _layout.petHalfWidth + 6
          : r.right + _layout.petHalfWidth - 6;
      _plan.add((_layout.grass, side));
      _plan.add((target, double.infinity)); // leo lên
    }
    _plan.add((target, tx));
  }

  /// Bắt đầu bị kéo tại [finger] (toạ độ banner).
  void grab(Offset finger) {
    _plan.clear();
    motion = PetMotion.carried;
    _grabOffset = feet - finger;
    velocity = Offset.zero;
  }

  void dragTo(Offset finger, double dt) {
    if (motion != PetMotion.carried) return;
    final target = _clamp(finger + _grabOffset);
    if (dt > 0) velocity = (target - feet) / dt;
    feet = target;
  }

  /// Thả ra với vận tốc [fling] (dp/s); pet rơi và đáp lên bề mặt gần nhất bên dưới.
  void release([Offset fling = Offset.zero]) {
    if (motion != PetMotion.carried) return;
    _startFall(Offset(fling.dx.clamp(-600, 600), fling.dy.clamp(-900, 600)));
  }

  /// Nhảy tại chỗ với vận tốc lên [vy] (dp/s, dương là lên).
  void hop(double vy) {
    if (motion != PetMotion.standing) return;
    _plan.clear();
    _startFall(Offset(0, -vy));
  }

  void _startFall(Offset v) {
    motion = PetMotion.falling;
    velocity = v;
  }

  Offset _clamp(Offset f) {
    final hw = _layout.petHalfWidth;
    var x = f.dx.clamp(hw, _layout.width - hw);
    var y = f.dy.clamp(_layout.top + height, _layout.height);
    var r = _layout.petRect(Offset(x, y), height);
    for (final z in _layout.forbidden) {
      if (r.overlaps(z)) {
        y = math.max(y, z.bottom + height + .5);
        r = _layout.petRect(Offset(x, y), height);
      }
    }
    return Offset(x, math.min(y, _layout.height));
  }

  void step(double dt) {
    switch (motion) {
      case PetMotion.carried:
        return;
      case PetMotion.falling:
        _fall(dt);
      case PetMotion.climbing:
        _climb += dt;
        final u = (_climb / climbTime).clamp(0.0, 1.0);
        // kéo người lên (nửa đầu), bước vào mép (nửa sau)
        final ease = u < .6 ? _easeOut(u / .6) : 1.0;
        final side = u < .6 ? 0.0 : _easeOut((u - .6) / .4);
        feet = Offset(_climbFrom.dx + (_climbTo.dx - _climbFrom.dx) * side,
            _climbFrom.dy + (_climbTo.dy - _climbFrom.dy) * ease);
        if (u >= 1) {
          surface = _climbOnto!;
          feet = _climbTo;
          motion = PetMotion.standing;
          _plan.removeAt(0);
        }
      case PetMotion.standing:
      case PetMotion.walking:
        _follow(dt);
    }
  }

  void _follow(double dt) {
    if (_plan.isEmpty) {
      motion = PetMotion.standing;
      return;
    }
    final (target, tx) = _plan.first;
    if (tx.isNaN) {
      // nhảy xuống khỏi chip, hướng ra ngoài
      _plan.removeAt(0);
      _startFall(Offset(facing * 110, -220));
      return;
    }
    if (tx.isInfinite) {
      final r = _layout.chips[target.chip!];
      final x = feet.dx < r.center.dx ? target.left : target.right;
      facing = feet.dx < r.center.dx ? 1 : -1;
      _climbFrom = feet;
      _climbTo = Offset(x, target.y(x));
      _climbOnto = target;
      _climb = 0;
      motion = PetMotion.climbing;
      return;
    }
    final dx = tx - feet.dx;
    if (dx.abs() < 1) {
      feet = Offset(tx, surface.y(tx));
      _plan.removeAt(0);
      if (_plan.isEmpty) motion = PetMotion.standing;
      return;
    }
    motion = PetMotion.walking;
    facing = dx.sign;
    final want = feet.dx + dx.sign * math.min(dx.abs(), walkSpeed * dt);
    final nx = want.clamp(surface.left, surface.right);
    feet = Offset(nx, surface.y(nx));
    // đích nằm ngoài bề mặt: dừng ở mép, bỏ chặng này
    if (nx != want) _plan.removeAt(0);
  }

  void _fall(double dt) {
    velocity = Offset(
        velocity.dx * math.pow(.6, dt).toDouble(), velocity.dy + gravity * dt);
    final prev = feet;
    var next = feet + velocity * dt;
    final hw = _layout.petHalfWidth;
    if (next.dx < hw || next.dx > _layout.width - hw) {
      next = Offset(next.dx.clamp(hw, _layout.width - hw), next.dy);
      velocity = Offset(-velocity.dx * .3, velocity.dy);
    }
    final kept = _clamp(next);
    if (kept.dy > next.dy) {
      // đụng trần banner hoặc vùng chữ: dừng đà bay lên
      next = Offset(next.dx, kept.dy);
      velocity = Offset(velocity.dx, math.max(0, velocity.dy));
    }
    final land = _layout.landingBelow(Offset(next.dx, prev.dy));
    final ground = land.y(next.dx);
    if (velocity.dy >= 0 && next.dy >= ground) {
      surface = land;
      final x = next.dx.clamp(land.left, land.right);
      feet = Offset(x, land.y(x));
      if (velocity.dy > 420) {
        velocity = Offset(velocity.dx * .5, -velocity.dy * .28);
        return;
      }
      velocity = Offset.zero;
      motion = PetMotion.standing;
      return;
    }
    feet = next;
  }
}

double _easeOut(double t) => 1 - math.pow(1 - t.clamp(0.0, 1.0), 3).toDouble();
