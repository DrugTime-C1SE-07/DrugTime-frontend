import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/app_assets.dart';
import '../../../../shared/widgets/mascot/mascot_controller.dart';
import '../../../../shared/widgets/mascot/mascot_view.dart';
import 'pill_sky_scene.dart';

/// Phần đầu màn đăng nhập: nền "Bầu trời viên thuốc", chữ logo và linh vật.
///
/// [entrance] (0→1) là hiệu ứng vào màn do màn hình sở hữu, dùng chung với sheet.
/// Khi [entrance] qua mốc [climbAt], linh vật bám mép sheet leo lên mây. Mép sheet
/// chính là đáy của widget này.
///
/// Màn OTP dùng lại với [showBrand] = false (tiêu đề đã nằm trong sheet) và
/// [entranceMood] = [MascotMood.idle] (linh vật chỉ bật ra, không leo).
class LoginHero extends StatefulWidget {
  const LoginHero({
    super.key,
    required this.entrance,
    required this.mascot,
    this.mascotKey,
    this.showBrand = true,
    this.entranceMood = MascotMood.climb,
  });

  final Animation<double> entrance;
  final MascotController mascot;

  /// Hiện chữ logo và dòng giới thiệu ở trên cùng.
  final bool showBrand;

  /// Trạng thái linh vật phát khi vào màn: [MascotMood.climb] leo từ mép sheet,
  /// trạng thái khác thì phát ngay sau khung hình đầu khi [entrance] đã xong.
  final MascotMood entranceMood;

  /// Gắn vào [MascotView] để màn hình tính hướng nhìn theo con trỏ.
  final GlobalKey? mascotKey;

  /// Mốc của [entrance] để linh vật bắt đầu leo (≈ lúc sheet đã trượt lên).
  static const climbAt = .75;

  @override
  State<LoginHero> createState() => _LoginHeroState();
}

class _LoginHeroState extends State<LoginHero>
    with SingleTickerProviderStateMixin {
  late final Ticker _clock = createTicker(_onClock);
  final _time = ValueNotifier<double>(0);
  final _kick = ValueNotifier<double>(-1);
  Duration _last = Duration.zero;
  MascotMood _lastMood = MascotMood.hidden;
  bool _still = false;

  @override
  void initState() {
    super.initState();
    widget.entrance.addListener(_onEntrance);
    widget.mascot.addListener(_onMascot);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage(AppAssets.logoWordmark), context);
    _still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_still) {
      if (_clock.isActive) _clock.stop();
    } else if (!_clock.isActive) {
      _last = Duration.zero;
      _clock.start();
    }
    _onEntrance();
  }

  @override
  void dispose() {
    widget.entrance.removeListener(_onEntrance);
    widget.mascot.removeListener(_onMascot);
    _clock.dispose();
    _time.dispose();
    _kick.dispose();
    super.dispose();
  }

  void _onClock(Duration now) {
    final dt = _last == Duration.zero
        ? 0.0
        : math.min(.05, (now - _last).inMicroseconds / 1e6);
    _last = now;
    _time.value += dt;
  }

  void _onEntrance() {
    if (widget.mascot.mood != MascotMood.hidden) return;
    final climb = widget.entranceMood == MascotMood.climb;
    if ((_still || !climb) && widget.entrance.value >= 1) {
      // không gọi controller giữa lúc build
      final mood = _still ? MascotMood.idle : widget.entranceMood;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.mascot.mood == MascotMood.hidden) {
          widget.mascot.play(mood);
        }
      });
    } else if (!_still && climb && widget.entrance.value >= LoginHero.climbAt) {
      widget.mascot.play(MascotMood.climb);
    }
  }

  // viên thuốc nảy theo linh vật khi nó tiếp đất hoặc ăn mừng
  void _onMascot() {
    final m = widget.mascot.mood;
    if (m != _lastMood) {
      if (m == MascotMood.climb) _kick.value = _time.value + 2.6;
      if (m == MascotMood.celebrate) _kick.value = _time.value + .15;
    }
    _lastMood = m;
  }

  double _iv(double a, double b) => Curves.easeOutCubic
      .transform(((widget.entrance.value - a) / (b - a)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth, h = box.maxHeight;
      final s = PillSkyScenePainter.designScale(Size(w, h));
      // cụm mây dưới chân ở y = 298 trong khung thiết kế 360×380, neo theo đáy
      final footY = h - (380 - 298) * s;
      final m = math.min(220.0, h * .6);
      final mascotTop = footY - m * 262 / 300;
      widget.mascot.ledge = (h - mascotTop) * 300 / m;
      final wordmarkWidth = math.min(190.0, w * .52);
      return Stack(clipBehavior: Clip.none, children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: PillSkyScenePainter(
                  entrance: widget.entrance, time: _time, kick: _kick),
            ),
          ),
        ),
        if (widget.showBrand)
          Positioned(
            top: AppSpacing.md,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: widget.entrance,
              builder: (_, child) {
                final e = _iv(.22, .55);
                return Opacity(
                  opacity: e,
                  child: Transform.translate(
                      offset: Offset(0, (1 - e) * -14), child: child),
                );
              },
              child: MediaQuery.withClampedTextScaling(
                maxScaleFactor: 1.3,
                child: Column(children: [
                  Image.asset(
                    AppAssets.logoWordmark,
                    key: const Key('login-wordmark'),
                    width: wordmarkWidth,
                    fit: BoxFit.contain,
                    semanticLabel: 'DrugTime',
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Trợ lý nhắc uống thuốc của bạn',
                    style: TextStyle(fontSize: 14, color: AppColors.inkMuted),
                  ),
                ]),
              ),
            ),
          ),
        Positioned(
          left: w / 2 - m / 2,
          top: mascotTop,
          width: m,
          height: m,
          child: MascotView(
              key: widget.mascotKey, controller: widget.mascot, size: m),
        ),
      ]);
    });
  }
}
