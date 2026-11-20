import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../home/presentation/scene/astronomy.dart';
import '../../../home/presentation/scene/living_banner.dart';
import '../../../home/presentation/scene/sky_palette.dart';
import 'reminder_mascot.dart';
import 'reminder_sky_backdrop.dart';

/// Màu chữ đặt trực tiếp trên cảnh trời.
class ReminderInk {
  const ReminderInk({required this.dark});

  /// Nền dịu cho chữ trên màu thương hiệu (không có cảnh).
  static const brand = ReminderInk(dark: true);

  /// Trời tối thì chữ sáng.
  final bool dark;

  Color get strong => dark ? Colors.white : const Color(0xFF15302A);
  Color get soft => dark ? AppColors.onBrand : const Color(0xFF2B4A42);
}

/// Nền bầu trời theo giờ của Trang chủ cho màn nhắc thuốc và màn khóa.
///
/// Bọc nội dung trong một [Stack] có [ReminderSkyBackdrop] phía sau. Nội dung gắn
/// [groundKey] vào [ReminderMascot] để mặt cỏ của cảnh đi qua chân pet (đo lại sau mỗi
/// lần dựng và khi cuộn). Trời cập nhật mỗi phút khi có hoạt họa.
class ReminderScene extends StatefulWidget {
  const ReminderScene({
    super.key,
    required this.builder,
    this.clock,
  });

  final DateTime Function()? clock;
  final Widget Function(BuildContext context, ReminderInk ink, Key groundKey)
      builder;

  @override
  State<ReminderScene> createState() => _ReminderSceneState();
}

class _ReminderSceneState extends State<ReminderScene> {
  final _stackKey = GlobalKey();
  final _groundKey = GlobalKey();
  double? _groundY;
  Timer? _timer;
  late SkyNow _sky;
  late SkyPalette _palette;

  @override
  void initState() {
    super.initState();
    _refresh();
    if (LivingBanner.autoplay) {
      _timer = Timer.periodic(const Duration(minutes: 1), (_) {
        if (mounted) setState(_refresh);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _refresh() {
    _sky = SkyNow.at((widget.clock ?? DateTime.now)().toUtc());
    _palette = SkyPalette.at(_sky.sun.altitude, moonLight: _sky.moonLight);
  }

  void _measure() {
    if (!mounted) return;
    final stack = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stack == null || !stack.hasSize) return;
    final stage = _groundKey.currentContext?.findRenderObject() as RenderBox?;
    final y = stage != null && stage.attached && stage.hasSize
        ? stage
            .localToGlobal(
              Offset(0, stage.size.height - ReminderMascot.feetInset),
              ancestor: stack,
            )
            .dy
        : stack.size.height * .42;
    if (_groundY == null || (y - _groundY!).abs() > .5) {
      setState(() => _groundY = y);
    }
  }

  void _scheduleMeasure() =>
      WidgetsBinding.instance.addPostFrameCallback((_) => _measure());

  @override
  Widget build(BuildContext context) {
    _scheduleMeasure();
    return Stack(
      key: _stackKey,
      children: [
        Positioned.fill(
          child: ReminderSkyBackdrop(
            sky: _sky,
            palette: _palette,
            groundY: _groundY ?? MediaQuery.sizeOf(context).height * .42,
            top: MediaQuery.paddingOf(context).top,
          ),
        ),
        Positioned.fill(
          child: NotificationListener<ScrollUpdateNotification>(
            onNotification: (_) {
              _scheduleMeasure();
              return false;
            },
            child: widget.builder(
              context,
              ReminderInk(dark: _palette.darkSky),
              _groundKey,
            ),
          ),
        ),
      ],
    );
  }
}
