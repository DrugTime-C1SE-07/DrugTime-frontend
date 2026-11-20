import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'chibi_pet.dart';
import 'astronomy.dart';
import 'home_pet_signals.dart';
import 'pet_body.dart';
import 'pet_brain.dart';
import 'pet_props_painter.dart';
import 'scene_debug_panel.dart';
import 'scene_layout.dart';
import 'scene_painter.dart';
import 'sky_palette.dart';
import 'streak_milestone_store.dart';

/// Banner trang chủ "sống": bầu trời theo giờ thật và pet Dumi hoạt họa.
///
/// [title], [trailing], [chips] là widget của trang chủ, đặt lên trên cảnh; banner đo vị trí
/// của chúng để pet tránh chữ và leo lên chip.
class LivingBanner extends StatefulWidget {
  const LivingBanner({
    super.key,
    this.now,
    required this.signals,
    required this.title,
    this.trailing,
    this.chips = const [],
    this.showPet = true,
    this.active = true,
    this.height = 236,
    this.shrink = 0,
    this.milestones,
    this.sheetColor,
    this.debugOnBrain,
  });

  /// Tắt trong test (`test/flutter_test_config.dart`): banner vẽ một khung tĩnh đúng giờ,
  /// không có ticker, để `pumpAndSettle` không chờ mãi.
  static bool autoplay = true;

  /// Đồng hồ khi banner tự lấy giờ ([now] = `null`). Chỉ thay trong test.
  @visibleForTesting
  static DateTime Function() clock = DateTime.now;

  /// Thời điểm hiện tại do trang chủ cấp (cập nhật mỗi phút); `null` thì banner tự lấy giờ thật.
  final DateTime? now;
  final HomePetSignals signals;

  /// Lời chào và tên; [ink] là màu chữ đọc rõ trên nền trời hiện tại.
  /// [now]: giờ đang hiển thị (giờ thật, hoặc giờ tua ở bảng debug).
  final Widget Function(BuildContext context, Color ink, DateTime now) title;
  final Widget? trailing;
  final List<Widget> chips;
  final bool showPet;

  /// Tab trang chủ đang hiển thị; `false` thì dừng ticker.
  final bool active;

  /// Chiều cao khi mở hết, chưa tính safe area phía trên.
  final double height;

  /// Đã thu gọn bao nhiêu dp (do header cuộn).
  final double shrink;
  final StreakMilestoneStore? milestones;

  /// Màu nền phần nội dung bên dưới; banner vẽ mép bo tròn của nó đè lên chân đồi.
  final Color? sheetColor;

  /// Chỉ cho test: nhận bộ não pet khi được tạo.
  @visibleForTesting
  final void Function(PetBrain brain)? debugOnBrain;

  @override
  State<LivingBanner> createState() => _LivingBannerState();
}

class _LivingBannerState extends State<LivingBanner>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  final _frame = _Frame();
  final _stackKey = GlobalKey(),
      _titleKey = GlobalKey(),
      _trailingKey = GlobalKey();
  final List<GlobalKey> _chipKeys = [];
  late final StreakMilestoneStore _milestones =
      widget.milestones ?? SecureStreakMilestoneStore();

  SceneLayout? _layout;
  PetBrain? _brain;
  ChibiRig? _rig;
  int _rigSeq = -1;
  late SkyNow _sky;
  late SkyPalette _palette;
  DateTime? _skyMinute;
  double _time = 0;
  Duration _last = Duration.zero;
  PetProp _prop = PetProp.none;
  double _propSince = 0;
  int? _claimed, _pendingMilestone;
  final _debug = SceneDebugOverrides();

  DateTime get _now => _debug.now ?? widget.now ?? LivingBanner.clock();

  /// Khi banner tự lấy giờ ([LivingBanner.now] = `null`, ví dụ màn chưa có thuốc), giờ VN
  /// của pet tính lại theo đồng hồ mỗi khung, để pet tự ngủ lúc 22:00 dù màn không dựng lại.
  HomePetSignals get _signals {
    final base = widget.now == null
        ? widget.signals.withMinutes(HomePetSignals.minutesOf(_now))
        : widget.signals;
    return _debug.apply(base);
  }

  @override
  void initState() {
    super.initState();
    _updateSky();
    _debug.addListener(_onDebug);
    _syncTicker();
    _checkMilestone();
  }

  @override
  void didUpdateWidget(LivingBanner old) {
    super.didUpdateWidget(old);
    _updateSky();
    _syncTicker();
    if (old.signals.streak != widget.signals.streak) _checkMilestone();
    if (!LivingBanner.autoplay) _advance(0);
  }

  @override
  void dispose() {
    _debug.removeListener(_onDebug);
    _gestures.cancel();
    _ticker.dispose();
    _frame.dispose();
    _rig?.dispose();
    super.dispose();
  }

  void _onDebug() {
    _updateSky();
    _checkMilestone();
    setState(() {});
  }

  void _syncTicker() {
    final run = LivingBanner.autoplay && widget.active;
    if (run && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    } else if (!run && _ticker.isActive) {
      _ticker.stop();
    }
  }

  void _updateSky() {
    final now = _now;
    final minute = DateTime.fromMillisecondsSinceEpoch(
        now.millisecondsSinceEpoch ~/ 60000 * 60000,
        isUtc: true);
    if (minute == _skyMinute) return;
    _skyMinute = minute;
    _sky = SkyNow.at(now);
    _palette = SkyPalette.at(_sky.sun.altitude, moonLight: _sky.moonLight);
  }

  void _checkMilestone() {
    final m = StreakMilestoneStore.reached(_signals.streak);
    if (m == null || m == _claimed) return;
    _claimed = m;
    unawaited(_milestones.claim(m).then((fresh) {
      if (!fresh || !mounted) return;
      // pet có thể chưa được tạo (chỉ tạo sau lần đo bố cục đầu); giữ lại và giao sau
      final brain = _brain;
      if (brain == null) {
        _pendingMilestone = m;
      } else {
        brain.celebrateMilestone(m);
      }
    }));
  }

  void _onTick(Duration elapsed) {
    final dt = _last == Duration.zero
        ? 0.0
        : math.min(.05, (elapsed - _last).inMicroseconds / 1e6);
    _last = elapsed;
    _advance(dt);
  }

  void _advance(double dt) {
    _time += dt;
    if (widget.now == null && _debug.now == null) _updateSky();
    final brain = _brain;
    final rig = _rig;
    if (brain != null && rig != null && widget.showPet) {
      brain.tick(dt, _signals);
      if (brain.ctl.seq != _rigSeq) {
        _rigSeq = brain.ctl.seq;
        rig.setMood(brain.ctl.mood);
      }
      rig.tick(dt, ctl: brain.ctl, still: !LivingBanner.autoplay);
      if (brain.prop != _prop) {
        _prop = brain.prop;
        _propSince = _time;
      }
    }
    _frame.ping();
  }

  // ------------------------------------------------------------ đo bố cục

  Rect? _rectOf(GlobalKey key, RenderBox stack) {
    final box = key.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return null;
    return box.localToGlobal(Offset.zero, ancestor: stack) & box.size;
  }

  void _measure(Size size, double top) {
    // khung đầu tiên có thể chưa có chiều rộng (Android báo "Width is zero")
    if (size.width < 160 || size.height < 120) return;
    final stack = _stackKey.currentContext?.findRenderObject();
    if (stack is! RenderBox || !stack.hasSize) return;
    final forbidden = [
      for (final k in [_titleKey, _trailingKey]) _rectOf(k, stack)?.inflate(4)
    ].whereType<Rect>().toList();
    final chips = [
      for (final k in _chipKeys.take(widget.chips.length)) _rectOf(k, stack)
    ].whereType<Rect>().toList();
    final next =
        SceneLayout(size: size, top: top, chips: chips, forbidden: forbidden);
    final old = _layout;
    if (old != null &&
        old.size == next.size &&
        listEquals(old.chips, next.chips) &&
        listEquals(old.forbidden, next.forbidden)) {
      return;
    }
    _layout = next;
    final brain = _brain;
    if (brain == null) {
      setState(() {
        _brain = PetBrain(PetBody(next, x: size.width * .78));
        _rig = ChibiRig();
      });
      final pending = _pendingMilestone;
      if (pending != null) {
        _pendingMilestone = null;
        _brain!.celebrateMilestone(pending);
      }
      widget.debugOnBrain?.call(_brain!);
    } else {
      brain.body.updateLayout(next);
    }
    if (!LivingBanner.autoplay) _advance(0);
    _frame.ping();
  }

  // ------------------------------------------------------------ vẽ

  Offset? get _sunPoint =>
      _sky.sunArc == null || !SceneLayout.visible(_sky.sun.altitude)
          ? null
          : _layout?.celestial(_sky.sunArc!, _sky.sun.altitude);
  Offset? get _moonPoint =>
      _sky.moonArc == null || !SceneLayout.visible(_sky.moon.position.altitude)
          ? null
          : _layout?.celestial(_sky.moonArc!, _sky.moon.position.altitude);

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final full = widget.height + top;
    while (_chipKeys.length < widget.chips.length) {
      _chipKeys.add(GlobalKey());
    }
    final fade = (1 - widget.shrink / (widget.height * .5)).clamp(0.0, 1.0);
    final ink = _palette.darkSky ? Colors.white : const Color(0xFF19231F);
    return LayoutBuilder(builder: (context, c) {
      final size = Size(c.maxWidth, full);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _measure(size, top);
      });
      final layout = _layout ?? SceneLayout(size: size, top: top);
      _brain?.skyPoint = _sunPoint ?? _moonPoint;
      final chipTop = full * .87 - 34;
      return ClipRect(
        child: SizedBox(
          height: math.max(0.0, full - widget.shrink),
          child: OverflowBox(
            alignment: Alignment.topCenter,
            minHeight: full,
            maxHeight: full,
            child: Stack(key: _stackKey, children: [
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: ScenePainter(
                      sky: _sky,
                      palette: _palette,
                      layout: layout,
                      time: () => _time,
                      repaint: _frame,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 20,
                right: 76,
                top: top + 14,
                child: GestureDetector(
                  onLongPress: kDebugMode
                      ? () => showSceneDebugPanel(context, _debug)
                      : null,
                  child: DefaultTextStyle.merge(
                    style: TextStyle(color: ink),
                    child: IconTheme.merge(
                      data: IconThemeData(color: ink),
                      child: KeyedSubtree(
                          key: _titleKey,
                          child: widget.title(context, ink, _now)),
                    ),
                  ),
                ),
              ),
              if (widget.trailing != null)
                Positioned(
                  right: 18,
                  top: top + 12,
                  child:
                      KeyedSubtree(key: _trailingKey, child: widget.trailing!),
                ),
              if (widget.chips.isNotEmpty)
                Positioned(
                  left: 20,
                  right: 20,
                  top: chipTop,
                  child: Opacity(
                    opacity: fade,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(children: [
                        for (var i = 0; i < widget.chips.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: KeyedSubtree(
                              key: _chipKeys[i],
                              child: widget.chips[i],
                            ),
                          ),
                      ]),
                    ),
                  ),
                ),
              if (widget.sheetColor != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 18,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: widget.sheetColor,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                  ),
                ),
              if (_brain != null && _rig != null && widget.showPet) ...[
                Positioned.fill(
                  child: IgnorePointer(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: PetScenePainter(
                          brain: _brain!,
                          rig: _rig!,
                          light: () => _sunPoint ?? _moonPoint,
                          lightStrength: () => _palette.light,
                          propAge: () => _time - _propSince,
                          opacity: () => fade,
                          repaint: _frame,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: _HitRegion(
                    test: _interactive,
                    child: RawGestureDetector(
                      gestures: {
                        EagerGestureRecognizer:
                            GestureRecognizerFactoryWithHandlers<
                                    EagerGestureRecognizer>(
                                EagerGestureRecognizer.new, (_) {}),
                      },
                      child: Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: (e) =>
                            _gestures.down(e.localPosition, e.timeStamp),
                        onPointerMove: (e) =>
                            _gestures.move(e.localPosition, e.timeStamp),
                        onPointerUp: (e) =>
                            _gestures.up(e.localPosition, e.timeStamp),
                        onPointerCancel: (e) => _gestures.cancel(),
                      ),
                    ),
                  ),
                ),
              ],
            ]),
          ),
        ),
      );
    });
  }

  // ------------------------------------------------------------ cử chỉ

  late final _gestures = PetGestureClassifier(
    onTap: _onTap,
    onDoubleTap: (p) {
      if (_zone(p) == _Zone.pet || _zone(p) == _Zone.blanket) {
        _brain?.doubleTapPet();
      }
    },
    onLongPressStart: (p) {
      if (_zone(p) == _Zone.sky) return;
      HapticFeedback.mediumImpact();
      _brain?.longPressStart();
    },
    onLongPressEnd: () => _brain?.longPressEnd(),
    onPanStart: _onPanStart,
    onPanUpdate: _onPanUpdate,
    onPanEnd: _onPanEnd,
  );

  _Zone? _panZone;
  Offset _panStart = Offset.zero;
  final _rub = RubDetector();
  Duration? _lastMove;

  bool _lying() {
    final m = _brain?.mood;
    return _brain?.asleep == true || m == PetMood.lie;
  }

  _Zone? _zone(Offset p) {
    final brain = _brain;
    if (brain == null || !widget.showPet) return null;
    final body = brain.body;
    if (brain.asleep) {
      if (PetScenePainter.pillowRect(body).contains(p)) return _Zone.pillow;
      if (PetScenePainter.blanketRect(body).contains(p)) return _Zone.blanket;
    }
    if (PetScenePainter.hitRect(body, lying: _lying()).contains(p)) {
      return _Zone.pet;
    }
    for (final s in [_sunPoint, _moonPoint]) {
      if (s != null && (s - p).distance < 28) return _Zone.sky;
    }
    return null;
  }

  bool _interactive(Offset p) => _zone(p) != null;

  void _onTap(Offset p) {
    final zone = _zone(p);
    if (zone == null) return;
    if (zone == _Zone.sky) return _brain?.tapSky();
    HapticFeedback.selectionClick();
    _brain?.tapPet();
  }

  void _onPanStart(Offset p) {
    final brain = _brain;
    _panZone = _zone(p);
    _panStart = p;
    _rub.reset();
    _lastMove = null;
    if (brain == null || _panZone == null || _panZone == _Zone.sky) return;
    if (_panZone == _Zone.pet && !brain.asleep) {
      if (!brain.grabPet(p)) _panZone = _Zone.rub;
    } else if (_panZone == _Zone.pet) {
      _panZone = _Zone.rub;
    }
  }

  void _onPanUpdate(Offset p, Offset delta, Duration t) {
    final brain = _brain;
    if (brain == null) return;
    final dt =
        _lastMove == null ? 1 / 60 : (t - _lastMove!).inMicroseconds / 1e6;
    _lastMove = t;
    switch (_panZone) {
      case _Zone.pillow:
        brain.dragPillow((p.dx - _panStart.dx) * 300 / PetScenePainter.box);
      case _Zone.blanket:
        brain.dragBlanket(
            (p.dx - _panStart.dx).abs() / (PetScenePainter.box * .6));
      case _Zone.pet:
        brain.dragPet(p, math.max(dt, 1 / 240));
        if (_rub.add(brain.now, delta.dx) && (p - _panStart).distance < 40) {
          brain.releasePet(Offset.zero);
          brain.rubPet();
          _panZone = _Zone.rub;
        }
      case _Zone.rub:
        if (_rub.add(brain.now, delta.dx)) brain.rubPet();
      case _Zone.sky:
      case null:
        break;
    }
  }

  void _onPanEnd(Offset velocity) {
    final brain = _brain;
    switch (_panZone) {
      case _Zone.pillow:
        brain?.releasePillow();
      case _Zone.blanket:
        brain?.releaseBlanket();
      case _Zone.pet:
        brain?.releasePet(velocity);
      default:
        break;
    }
    _panZone = null;
  }
}

enum _Zone { pet, blanket, pillow, sky, rub }

class _Frame extends ChangeNotifier {
  void ping() => notifyListeners();
}

/// Chỉ nhận hit-test khi [test] đúng, để cử chỉ bắt đầu ngoài pet rơi xuống lớp cuộn bên dưới.
class _HitRegion extends SingleChildRenderObjectWidget {
  const _HitRegion({required this.test, super.child});
  final bool Function(Offset) test;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderHitRegion(test);

  @override
  void updateRenderObject(BuildContext context, _RenderHitRegion r) =>
      r.test = test;
}

class _RenderHitRegion extends RenderProxyBox {
  _RenderHitRegion(this.test);
  bool Function(Offset) test;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) =>
      test(position) && super.hitTest(result, position: position);
}

/// Phân loại chuỗi sự kiện con trỏ thành chạm, chạm đôi, nhấn giữ, kéo.
///
/// Tự làm thay vì dùng [GestureDetector] vì vùng pet giành con trỏ ngay khi chạm
/// ([EagerGestureRecognizer]) để kéo pet không làm cuộn danh sách.
class PetGestureClassifier {
  PetGestureClassifier({
    required this.onTap,
    required this.onDoubleTap,
    required this.onLongPressStart,
    required this.onLongPressEnd,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
  });

  static const slop = 8.0;
  static const longPress = Duration(milliseconds: 500);
  static const doubleTap = Duration(milliseconds: 300);

  final void Function(Offset) onTap, onDoubleTap, onLongPressStart, onPanStart;
  final VoidCallback onLongPressEnd;
  final void Function(Offset position, Offset delta, Duration time) onPanUpdate;
  final void Function(Offset velocity) onPanEnd;

  Offset? _start, _last;
  Duration _downAt = Duration.zero;
  Duration? _lastTapAt;
  Offset? _lastTapPos;
  bool _panning = false, _pressing = false;
  Timer? _timer;
  final _samples = <(Duration, Offset)>[];

  void down(Offset p, Duration t) {
    _start = _last = p;
    _downAt = t;
    _panning = _pressing = false;
    _samples
      ..clear()
      ..add((t, p));
    _timer?.cancel();
    _timer = Timer(longPress, () {
      if (_start == null || _panning) return;
      _pressing = true;
      onLongPressStart(_start!);
    });
  }

  void move(Offset p, Duration t) {
    final start = _start;
    if (start == null) return;
    final delta = p - _last!;
    _last = p;
    _samples.add((t, p));
    if (_samples.length > 6) _samples.removeAt(0);
    if (_pressing) return;
    if (!_panning && (p - start).distance > slop) {
      _timer?.cancel();
      _panning = true;
      onPanStart(start);
    }
    if (_panning) onPanUpdate(p, delta, t);
  }

  void up(Offset p, Duration t) {
    final start = _start;
    if (start == null) return;
    _timer?.cancel();
    _start = null;
    if (_panning) {
      final (t0, p0) = _samples.first;
      final secs = (t - t0).inMicroseconds / 1e6;
      onPanEnd(secs > 0 ? (p - p0) / secs : Offset.zero);
      return;
    }
    if (_pressing) {
      onLongPressEnd();
      return;
    }
    final last = _lastTapAt;
    if (last != null &&
        _downAt - last < doubleTap &&
        (_lastTapPos! - start).distance < 30) {
      _lastTapAt = null;
      onDoubleTap(start);
      return;
    }
    _lastTapAt = t;
    _lastTapPos = start;
    onTap(start);
  }

  void cancel() {
    _timer?.cancel();
    if (_panning) onPanEnd(Offset.zero);
    if (_pressing) onLongPressEnd();
    _start = null;
    _panning = _pressing = false;
  }
}
