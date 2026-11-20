import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'mascot_artwork_painter.dart';

import 'mascot_controller.dart';
import 'mascot_painter.dart';
import 'mascot_rig.dart';

/// Linh vật DrugTime vẽ bằng code, điều khiển qua [controller].
///
/// Ticker tạo từ [SingleTickerProviderStateMixin] nên tự dừng khi route bị che
/// (`TickerMode` false). Khi bật "Giảm chuyển động", linh vật đứng yên ở tư thế chính
/// và không yêu cầu khung hình liên tục.
class MascotView extends StatefulWidget {
  static Future<void> preloadFigmaArtwork() async {
    await Future.wait([
      _MascotViewState._texture('assets/icons/dumi-farewell.png'),
      _MascotViewState._texture('assets/icons/mascot-protect.png'),
    ]);
  }

  const MascotView(
      {super.key,
      required this.controller,
      this.size = 220,
      this.height,
      this.figmaArtwork = false,
      this.outfit = MascotOutfit.plain,
      this.palette = MascotPalette.blue,
      this.onTap,
      this.semanticLabel = 'Linh vật DrugTime',
      this.random});

  final MascotController controller;
  final double size;
  final double? height;
  final bool figmaArtwork;
  final MascotOutfit outfit;
  final MascotPalette palette;

  /// Thay phản ứng mặc định khi chạm (phát [MascotMood.poke]).
  final VoidCallback? onTap;

  final String semanticLabel;

  /// Chỉ dùng cho test để chuyển động ngẫu nhiên xác định được.
  final math.Random? random;

  @override
  State<MascotView> createState() => _MascotViewState();
}

class _MascotViewState extends State<MascotView>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final MascotRig _rig = MascotRig(random: widget.random);
  late final Ticker _ticker = createTicker(_onTick);
  Duration _last = Duration.zero;
  int _seq = -1;
  bool _still = false;
  bool _foreground = true;
  bool _visible = true;
  ui.Image? _artwork;
  static final _textures = <String, Future<ui.Image>>{};
  static final _loadedTextures = <String, ui.Image>{};
  static Future<ui.Image> _texture(String path) =>
      _textures.putIfAbsent(path, () async {
        final data = await rootBundle.load(path);
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List(),
            targetWidth: 448, allowUpscaling: false);
        try {
          final image = (await codec.getNextFrame()).image;
          _loadedTextures[path] = image;
          return image;
        } finally {
          codec.dispose();
        }
      });
  Future<void> _loadArtwork() async {
    if (!widget.figmaArtwork) return;
    final path = widget.controller.mood == MascotMood.thumbsUp
        ? 'assets/icons/mascot-protect.png'
        : 'assets/icons/dumi-farewell.png';
    final cached = _loadedTextures[path];
    if (cached != null) {
      _artwork = cached;
      return;
    }
    final texture = await _texture(path);
    if (mounted) setState(() => _artwork = texture);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_onController);
    _loadArtwork();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _visible = TickerMode.valuesOf(context).enabled;
    _syncMood();
    _syncTicker();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncTicker();
  }

  void _syncTicker() {
    if (_still || !_foreground || !_visible) {
      if (_ticker.isActive) _ticker.stop();
      if (_still) _rig.tick(0, ctl: widget.controller, still: true);
    } else if (!_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  @override
  void didUpdateWidget(MascotView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.figmaArtwork != widget.figmaArtwork ||
        oldWidget.controller != widget.controller) {
      _artwork = null;
      _loadArtwork();
    }
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onController);
      widget.controller.addListener(_onController);
      _seq = -1;
      _onController();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
    _rig.outfit = widget.outfit;
    return Semantics(
      label: widget.semanticLabel,
      image: true,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: widget.onTap ?? () => widget.controller.play(MascotMood.poke),
        child: RepaintBoundary(
          child: CustomPaint(
            size: Size(widget.size, widget.height ?? widget.size),
            painter: widget.figmaArtwork
                ? (_artwork == null
                    ? null
                    : MascotArtworkPainter(_rig, _artwork!,
                        farewell:
                            widget.controller.mood != MascotMood.thumbsUp))
                : MascotPainter(_rig,
                    outfit: widget.outfit, palette: widget.palette),
          ),
        ),
      ),
    );
  }
}
