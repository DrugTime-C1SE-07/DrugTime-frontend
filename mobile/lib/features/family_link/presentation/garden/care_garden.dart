import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../../../shared/widgets/mascot/mascot_controller.dart';
import '../../../../shared/widgets/mascot/mascot_view.dart';
import 'garden_backdrop_painter.dart';
import 'garden_mood.dart';
import 'garden_props_painter.dart';
import 'plant_painter.dart';

/// Một chậu cây trong vườn, đại diện cho một người được theo dõi.
class GardenPlant {
  const GardenPlant(
      {required this.id, required this.label, required this.shape});
  final String id;

  /// Tên đọc cho trình đọc màn hình, vd. "Chậu cây của Mẹ Hoa".
  final String label;
  final PlantShape shape;
}

/// Cảnh "Khu vườn chăm sóc": hai linh vật ngang hàng chăm sóc lẫn nhau và chăm các chậu cây.
///
/// Chỉ trang trí: cảnh nhận [mood] và [plants] đã tính sẵn từ dữ liệu, không nhận
/// repository hay controller dữ liệu, nên mọi cử chỉ (chạm, xoa, kéo ôm, tưới) không thể gửi
/// request hay đổi trạng thái liều. Hành động duy nhất ra ngoài là [onPlantTap] (điều hướng).
///
/// Cử chỉ kéo / xoa dùng kéo ngang, nên vuốt dọc qua cảnh vẫn cuộn trang.
class CareGarden extends StatefulWidget {
  const CareGarden({
    super.key,
    required this.mood,
    this.plants = const [],
    this.onPlantTap,
    this.height = 200,
    this.showWateringCan = true,
    this.now,
  });

  final GardenMood mood;
  final List<GardenPlant> plants;
  final ValueChanged<String>? onPlantTap;
  final double height;
  final bool showWateringCan;

  /// Đồng hồ cho giới hạn tần suất "điệu nhảy"; chỉ tiêm trong test.
  final DateTime Function()? now;

  @override
  State<CareGarden> createState() => CareGardenState();
}

/// Trạng thái công khai để test đọc được tư thế hai linh vật.
class CareGardenState extends State<CareGarden>
    with SingleTickerProviderStateMixin {
  static const _danceCooldown = Duration(seconds: 4);
  static const _danceTaps = 5;
  static const _danceWindow = Duration(milliseconds: 2500);
  static const _reactions = [
    MascotMood.poke,
    MascotMood.wave,
    MascotMood.celebrate
  ];

  final left = MascotController();
  final right = MascotController();
  final _clock = ValueNotifier<double>(0);
  late final Ticker _ticker = createTicker(_tick);
  bool _still = false;

  final _wobbleAt = <String, double>{};
  final _dropsAt = <String, double>{};
  final _potKeys = <String, GlobalKey>{};
  double? _confettiAt, _heartsAt;
  int _reaction = 0;
  final _tapTimes = <DateTime>[];
  DateTime? _lastDance;

  // kéo ngang
  final _offset = {false: 0.0, true: 0.0};
  final _releaseFrom = {false: 0.0, true: 0.0};
  final _releaseAt = <bool, double>{};
  final _dragging = <bool>{};
  final _petting = <bool>{};
  final _petDistance = {false: 0.0, true: 0.0};

  // bình tưới: vị trí ngón tay (toàn cục, để tìm chậu) và độ dời so với chỗ để
  Offset? _can;
  Offset _canDelta = Offset.zero;

  /// Số lần cử chỉ đã được xử lý; test dùng để chắc chắn cử chỉ có hiệu lực.
  int gestures = 0;

  DateTime _now() => (widget.now ?? DateTime.now)();
  GardenSpec get _spec => gardenSpecs[widget.mood]!;

  @override
  void initState() {
    super.initState();
    _applyMood();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_still) {
      if (_ticker.isActive) _ticker.stop();
    } else if (!_ticker.isActive) {
      _ticker.start();
    }
  }

  @override
  void didUpdateWidget(CareGarden oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mood != widget.mood) _applyMood();
  }

  /// Tư thế tự kết thúc (chọc, vẫy, ăn mừng) quay về tư thế nền đứng trước nó; đặt nền
  /// `idle` trước để vd. bạn đang ngủ gật được nhắc thì tỉnh hẳn, không ngủ lại.
  static const _transient = {
    MascotMood.poke,
    MascotMood.wave,
    MascotMood.celebrate,
  };

  void _applyMood() {
    final spec = _spec;
    for (final (ctl, mood) in [(left, spec.left), (right, spec.right)]) {
      if (_transient.contains(mood)) ctl.play(MascotMood.idle);
      ctl.play(mood);
    }
    if (spec.confetti) _confettiAt = _clock.value;
  }

  void _tick(Duration elapsed) {
    _clock.value = elapsed.inMicroseconds / 1e6;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _clock.dispose();
    left.dispose();
    right.dispose();
    super.dispose();
  }

  double _fade(double? at, double duration) {
    if (at == null || _still) return 0;
    final u = (_clock.value - at) / duration;
    return u < 0 || u > 1 ? 0 : 1 - u;
  }

  void _haptic() => HapticFeedback.lightImpact();

  // ------------------------------------------------------------- linh vật

  void _onMascotTap(bool isRight) {
    gestures++;
    _haptic();
    final me = isRight ? right : left, other = isRight ? left : right;
    me.play(_reactions[_reaction++ % _reactions.length]);
    other.lookAt(Offset(isRight ? 1 : -1, 0));
    other.play(MascotMood.wave);

    final now = _now();
    _tapTimes
      ..add(now)
      ..removeWhere((t) => now.difference(t) > _danceWindow);
    final cooled =
        _lastDance == null || now.difference(_lastDance!) >= _danceCooldown;
    if (_tapTimes.length >= _danceTaps && cooled) {
      _lastDance = now;
      _tapTimes.clear();
      left.play(MascotMood.celebrate);
      right.play(MascotMood.celebrate);
    }
  }

  void _onDragStart(bool isRight, DragStartDetails d, double size) {
    if (d.localPosition.dy < size * .42) {
      _petting.add(isRight);
      _petDistance[isRight] = 0;
    } else {
      _dragging.add(isRight);
      _releaseAt.remove(isRight);
    }
  }

  void _onDragUpdate(bool isRight, DragUpdateDetails d, double maxGap) {
    if (_petting.contains(isRight)) {
      _petDistance[isRight] = _petDistance[isRight]! + d.delta.dx.abs();
      if (_petDistance[isRight]! > 40) {
        _petting.remove(isRight);
        gestures++;
        _haptic();
        (isRight ? right : left).play(MascotMood.blissful);
        _heartsAt = _clock.value;
        setState(() {});
      }
      return;
    }
    if (!_dragging.contains(isRight)) return;
    setState(() {
      final next = _offset[isRight]! + d.delta.dx;
      // chỉ kéo về phía bạn kia (và lùi lại một chút)
      _offset[isRight] =
          isRight ? next.clamp(-maxGap, 12.0) : next.clamp(-12.0, maxGap);
    });
  }

  void _onDragEnd(bool isRight, double maxGap) {
    _petting.remove(isRight);
    if (!_dragging.remove(isRight)) return;
    final closed = _offset[false]! - _offset[true]!;
    if (closed >= maxGap * .8) {
      gestures++;
      _haptic();
      left.play(MascotMood.hug);
      right.play(MascotMood.hug);
      _heartsAt = _clock.value;
    }
    setState(() {
      if (_still) {
        _offset[isRight] = 0;
      } else {
        _releaseFrom[isRight] = _offset[isRight]!;
        _releaseAt[isRight] = _clock.value;
        _offset[isRight] = 0;
      }
    });
  }

  /// Vị trí hiển thị: đang kéo theo tay, thả ra thì lò xo về chỗ cũ.
  double _shown(bool isRight) {
    if (_dragging.contains(isRight)) return _offset[isRight]!;
    final at = _releaseAt[isRight];
    if (at == null || _still) return 0;
    final t = _clock.value - at;
    if (t > 1.2) return 0;
    return _releaseFrom[isRight]! * math.exp(-5 * t) * math.cos(9 * t);
  }

  // ------------------------------------------------------------- chậu cây

  void _onPlantTap(GardenPlant plant) {
    gestures++;
    _haptic();
    setState(() => _wobbleAt[plant.id] = _clock.value);
    widget.onPlantTap?.call(plant.id);
  }

  void _onCanEnd() {
    final can = _can;
    setState(() => _can = null);
    if (can == null) return;
    for (final plant in widget.plants) {
      final box = _potKeys[plant.id]?.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.hasSize) continue;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      if (rect.inflate(16).contains(can)) {
        gestures++;
        _haptic();
        setState(() {
          _dropsAt[plant.id] = _clock.value;
          _wobbleAt[plant.id] = _clock.value;
        });
        return;
      }
    }
  }

  // ------------------------------------------------------------- dựng

  @override
  Widget build(BuildContext context) {
    final spec = _spec;
    return Semantics(
      container: true,
      label: spec.label,
      child: SizedBox(
        // luôn chiếm hết chiều ngang: trong Column căn giữa, Stack chỉ có con Positioned sẽ co về 0
        width: double.infinity,
        height: widget.height,
        child: LayoutBuilder(builder: (context, constraints) {
          final w = constraints.maxWidth, h = widget.height;
          final m = math.max(56.0, math.min(h * .62, w * .3));
          final side = w * .03;
          final maxGap = math.max(0.0, (w - 2 * side - 2 * m) / 2);
          return ValueListenableBuilder<double>(
            valueListenable: _clock,
            builder: (context, _, __) =>
                Stack(clipBehavior: Clip.none, children: [
              Positioned.fill(
                child: ExcludeSemantics(
                  child: CustomPaint(
                    painter: GardenBackdropPainter(
                        spec: spec,
                        clock: _clock,
                        hearts: _fade(_heartsAt, 2.2)),
                  ),
                ),
              ),
              _plantsRow(w, h, side, m),
              _mascot(false, side + _shown(false), h, m, maxGap),
              _mascot(true, w - side - m + _shown(true), h, m, maxGap),
              ..._props(spec, w, h, side, m),
              if (widget.showWateringCan &&
                  spec.plant != PlantShape.emptyPot &&
                  widget.plants.isNotEmpty)
                _wateringCan(w, h),
              if (_fade(_confettiAt, 2.4) > 0)
                Positioned.fill(
                  child: IgnorePointer(
                    child: ExcludeSemantics(
                      child: CustomPaint(
                          painter:
                              ConfettiPainter(1 - _fade(_confettiAt, 2.4))),
                    ),
                  ),
                ),
            ]),
          );
        }),
      ),
    );
  }

  Widget _mascot(bool isRight, double x, double h, double m, double maxGap) {
    final controller = isRight ? right : left;
    return Positioned(
      key: Key(isRight ? 'garden-mascot-right' : 'garden-mascot-left'),
      left: x,
      bottom: h * .04,
      width: m,
      height: m,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (d) => _onDragStart(isRight, d, m),
        onHorizontalDragUpdate: (d) => _onDragUpdate(isRight, d, maxGap),
        onHorizontalDragEnd: (_) => _onDragEnd(isRight, maxGap),
        onHorizontalDragCancel: () => _onDragEnd(isRight, maxGap),
        child: MascotView(
          controller: controller,
          size: m,
          palette: isRight ? MascotPalette.peach : MascotPalette.blue,
          outfit: isRight ? MascotOutfit.scarf : MascotOutfit.gardenHat,
          semanticLabel: isRight ? 'Bạn thuốc cam' : 'Bạn thuốc xanh',
          onTap: () => _onMascotTap(isRight),
        ),
      ),
    );
  }

  Widget _plantsRow(double w, double h, double side, double m) {
    if (widget.plants.isEmpty && widget.mood != GardenMood.empty) {
      return const SizedBox.shrink();
    }
    final plants = widget.plants.isEmpty
        ? const [
            GardenPlant(
                id: '', label: 'Chậu đất trống', shape: PlantShape.emptyPot)
          ]
        : widget.plants;
    final area = math.max(1.0, w - 2 * side - 2 * m);
    final pw = (area / plants.length).clamp(48.0, 84.0);
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < plants.length; i++) _pot(plants[i], i, pw),
      ],
    );
    // Nhiều chậu trên màn hẹp: cuộn ngang thay vì thu nhỏ, để vùng chạm luôn ≥ 48.
    return Positioned(
      left: side + m,
      right: side + m,
      bottom: h * .05,
      height: pw * 1.2,
      child: pw * plants.length <= area
          ? Center(child: row)
          : SingleChildScrollView(
              key: const Key('garden-plants-scroll'),
              scrollDirection: Axis.horizontal,
              child: row,
            ),
    );
  }

  static const _accents = [
    Color(0xFFFF8FB1),
    Color(0xFFFFB347),
    Color(0xFF9B87E8),
    Color(0xFF6EC6F5),
  ];

  Widget _pot(GardenPlant plant, int index, double pw) {
    final key = _potKeys.putIfAbsent(plant.id, GlobalKey.new);
    final painter = PlantPainter(
      shape: plant.shape,
      clock: _clock,
      wobble: _fade(_wobbleAt[plant.id], .9),
      drops: _fade(_dropsAt[plant.id], 1.6),
      petals: _fade(_wobbleAt[plant.id], 1.4),
      accent: _accents[index % _accents.length],
    );
    final pot = SizedBox(
        key: key,
        width: pw,
        height: pw * 1.2,
        child: CustomPaint(painter: painter));
    if (plant.id.isEmpty) return ExcludeSemantics(child: pot);
    return Semantics(
      key: Key('garden-plant-${plant.id}'),
      button: widget.onPlantTap != null,
      label: plant.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _onPlantTap(plant),
        child: pot,
      ),
    );
  }

  List<Widget> _props(
      GardenSpec spec, double w, double h, double side, double m) {
    final leftX = side + _shown(false), rightX = w - side - m + _shown(true);
    final s = math.max(28.0, m * .34);
    Widget at(GardenProp prop, double x, double bottom) => Positioned(
          left: x,
          bottom: bottom,
          width: s,
          height: s,
          child: IgnorePointer(
            child: ExcludeSemantics(
              child:
                  CustomPaint(painter: GardenPropPainter(prop, clock: _clock)),
            ),
          ),
        );
    final out = <Widget>[];
    for (final prop in spec.leftProps) {
      if (prop == GardenProp.paperPlane) {
        final u = _still ? .5 : (_clock.value * .35) % 1;
        final x = leftX + m * .6 + (rightX - leftX - m * .6) * u;
        out.add(at(prop, x, h * .55 + math.sin(u * math.pi) * h * .2));
      } else if (prop != GardenProp.wateringCan) {
        out.add(at(prop, leftX + m * .7, h * .04 + m * .38));
      }
    }
    for (final prop in spec.rightProps) {
      out.add(at(prop, rightX - s * .3, h * .04 + m * .38));
    }
    return out;
  }

  Widget _wateringCan(double w, double h) {
    const size = 48.0;
    final moved = _can == null ? Offset.zero : _canDelta;
    return Positioned(
      key: const Key('garden-watering-can'),
      left: w - size - 6 + moved.dx,
      top: 6 + moved.dy,
      width: size,
      height: size,
      child: Semantics(
        label: 'Bình tưới, kéo lên chậu cây để tưới',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (d) => setState(() {
            _can = d.globalPosition;
            _canDelta = Offset.zero;
          }),
          onPanUpdate: (d) => setState(() {
            _can = d.globalPosition;
            _canDelta += d.delta;
          }),
          onPanEnd: (_) => _onCanEnd(),
          onPanCancel: () => setState(() => _can = null),
          child: CustomPaint(
              painter: GardenPropPainter(GardenProp.wateringCan,
                  clock: _clock, tilt: _can == null ? 0 : -.6)),
        ),
      ),
    );
  }
}
