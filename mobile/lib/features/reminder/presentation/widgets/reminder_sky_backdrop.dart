import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../home/presentation/scene/astronomy.dart';
import '../../../home/presentation/scene/living_banner.dart';
import '../../../home/presentation/scene/scene_layout.dart';
import '../../../home/presentation/scene/scene_painter.dart';
import '../../../home/presentation/scene/sky_palette.dart';

/// Bầu trời của Trang chủ trải toàn màn hình: mặt trời / trăng, sao, mây, đồi cỏ theo giờ thật.
///
/// [groundY]: toạ độ y (theo khung của widget) của mặt cỏ nơi pet đứng; cảnh được dựng sao cho
/// đường cỏ phía trước đi qua đây, phần dưới là đồng cỏ. Mây trôi, sao nhấp nháy khi có
/// hoạt họa; đứng yên khi "Giảm chuyển động" hoặc [LivingBanner.autoplay] tắt.
class ReminderSkyBackdrop extends StatefulWidget {
  const ReminderSkyBackdrop({
    super.key,
    required this.sky,
    required this.palette,
    required this.groundY,
    this.top = 0,
  });

  final SkyNow sky;
  final SkyPalette palette;
  final double groundY;

  /// Phần trên dành cho thanh trạng thái, để mặt trời / trăng không chui vào đó.
  final double top;

  @override
  State<ReminderSkyBackdrop> createState() => _ReminderSkyBackdropState();
}

class _ReminderSkyBackdropState extends State<ReminderSkyBackdrop>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  final _time = ValueNotifier<double>(0);
  Duration _last = Duration.zero;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = !LivingBanner.autoplay ||
        (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    if (still) {
      if (_ticker.isActive) _ticker.stop();
    } else if (!_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  void _onTick(Duration now) {
    final dt = _last == Duration.zero
        ? 0.0
        : math.min(.05, (now - _last).inMicroseconds / 1e6);
    _last = now;
    _time.value += dt;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, box) {
          // grassY của SceneLayout nằm ở 87% chiều cao: chọn chiều cao cảnh để cỏ đi qua groundY.
          final sceneHeight = math.max(widget.groundY / .87, 120.0);
          final layout = SceneLayout(
            size: Size(box.maxWidth, sceneHeight),
            top: widget.top,
          );
          return ExcludeSemantics(
            child: RepaintBoundary(
              child: CustomPaint(
                size: Size(box.maxWidth, box.maxHeight),
                painter: ScenePainter(
                  sky: widget.sky,
                  palette: widget.palette,
                  layout: layout,
                  time: () => _time.value,
                  repaint: _time,
                ),
              ),
            ),
          );
        },
      );
}
