import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'mascot_controller.dart';
import 'mascot_painter.dart';
import 'mascot_rig.dart';

/// Linh vật DrugTime vẽ bằng code, điều khiển qua [controller].
///
/// Ticker tạo từ [SingleTickerProviderStateMixin] nên tự dừng khi route bị che
/// (`TickerMode` false). Khi bật "Giảm chuyển động", linh vật đứng yên ở tư thế chính
/// và không yêu cầu khung hình liên tục.
class MascotView extends StatefulWidget {
  const MascotView(
      {super.key, required this.controller, this.size = 220, this.random});

  final MascotController controller;
  final double size;

  /// Chỉ dùng cho test để chuyển động ngẫu nhiên xác định được.
  final math.Random? random;

  @override
  State<MascotView> createState() => _MascotViewState();
}

class _MascotViewState extends State<MascotView>
    with SingleTickerProviderStateMixin {
  late final MascotRig _rig = MascotRig(random: widget.random);
  late final Ticker _ticker = createTicker(_onTick);
  Duration _last = Duration.zero;
  int _seq = -1;
  bool _still = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onController);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _syncMood();
    if (_still) {
      if (_ticker.isActive) _ticker.stop();
      _rig.tick(0, ctl: widget.controller, still: true);
    } else if (!_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  @override
  void didUpdateWidget(MascotView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onController);
      widget.controller.addListener(_onController);
      _seq = -1;
      _onController();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onController);
    _ticker.dispose();
    _rig.dispose();
    super.dispose();
  }

  void _syncMood() {
    final c = widget.controller;
    if (c.seq == _seq) return;
    _seq = c.seq;
    _rig.setMood(c.mood, ledge: c.ledge, still: _still);
  }

  void _onController() {
    _syncMood();
    // Giảm chuyển động: không có ticker, cập nhật tư thế ngay một lần.
    if (_still) _rig.tick(0, ctl: widget.controller, still: true);
  }

  void _onTick(Duration now) {
    final dt = _last == Duration.zero
        ? 0.0
        : math.min(.05, (now - _last).inMicroseconds / 1e6);
    _last = now;
    _rig.tick(dt, ctl: widget.controller, still: false);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Linh vật DrugTime',
      image: true,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => widget.controller.play(MascotMood.poke),
        child: RepaintBoundary(
          child: CustomPaint(
            size: Size.square(widget.size),
            painter: MascotPainter(_rig),
          ),
        ),
      ),
    );
  }
}
