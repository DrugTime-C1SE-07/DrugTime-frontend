import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../shared/widgets/mascot/mascot_controller.dart';
import '../../../../shared/widgets/mascot/mascot_view.dart';
import '../../domain/entities/meal_suggestion.dart';
import '../state/meal_plan_controller.dart';
import '../widgets/dish_hero.dart';
import '../widgets/meal_ui.dart';
import 'analysis_timeline.dart';
import 'galaxy_painter.dart';
import 'supernova.dart';
import '../../../../core/motion/shared_axis.dart';

/// Màn chờ "Dumi đang lên thực đơn…" (3 bữa song song) hoặc "Dumi đang tìm món khác…" (một bữa).
///
/// Pop với `true` khi có kết quả để hiện (bữa mở sẵn đã đặt vào `plan.tab`); `false`/`null` khi
/// người dùng quay lại hoặc "Giữ món cũ".
class AnalyzingView extends StatefulWidget {
  const AnalyzingView({super.key, required this.plan, this.refreshMeal});

  final MealPlanController plan;

  /// Khác `null`: "Gợi ý khác" cho riêng bữa này (AC9).
  final MealType? refreshMeal;

  static Route<bool> route(MealPlanController plan, {MealType? refreshMeal}) =>
      sharedAxisRoute<bool>(
          builder: (_) => AnalyzingView(plan: plan, refreshMeal: refreshMeal));

  @override
  State<AnalyzingView> createState() => _AnalyzingViewState();
}

enum _Stage { running, finale, failed }

class _AnalyzingViewState extends State<AnalyzingView>
    with TickerProviderStateMixin {
  final mascot = MascotController();
  late final AnimationController _clock =
      AnimationController(vsync: this, duration: const Duration(hours: 1));
  late final AnimationController _finale =
      AnimationController(vsync: this, duration: AnalysisTimeline.finale);
  _Stage _stage = _Stage.running;
  bool _minPassed = false;
  bool _flashed = false, _cheered = false, _left = false, _inFlight = false;
  Timer? _minTimer, _settleTimer, _imageTimer;
  bool _preparingImages = false;
  MealTabStatus? _refreshStatus;
  late MealType _reveal = widget.refreshMeal ?? widget.plan.tab;

  MealPlanController get plan => widget.plan;
  List<MealType> get _meals =>
      widget.refreshMeal == null ? MealType.values : [widget.refreshMeal!];

  Map<MealType, MealTabStatus> get _statuses => widget.refreshMeal == null
      ? {for (final t in MealType.values) t: plan.stateOf(t).status}
      : {widget.refreshMeal!: _refreshStatus ?? MealTabStatus.loading};

  bool get _still => MediaQuery.disableAnimationsOf(context);

  @override
  void initState() {
    super.initState();
    plan.addListener(_check);
    _finale.addListener(_onFinale);
    _finale.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        _settleTimer = Timer(AnalysisTimeline.settle, _go);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  /// Bắt đầu (hoặc "Thử lại"). Chỉ một lượt gọi chạy cùng lúc (chống bấm liên tục, AC9b).
  void _start() {
    if (!mounted || _inFlight) return;
    _inFlight = true;
    _imageTimer?.cancel();
    setState(() {
      _stage = _Stage.running;
      _minPassed = false;
      _preparingImages = false;
      _refreshStatus = MealTabStatus.loading;
    });
    mascot.play(MascotMood.cooking);
    if (!_still) _clock.repeat(period: const Duration(hours: 1));
    _minTimer?.cancel();
    _minTimer = Timer(AnalysisTimeline.minShow, () {
      _minPassed = true;
      _check();
    });
    final r = widget.refreshMeal;
    if (r != null) {
      plan.refresh(r).then((ok) {
        if (!mounted) return;
        setState(() =>
            _refreshStatus = ok ? MealTabStatus.data : MealTabStatus.error);
        _check();
      });
      return;
    }
    if (plan.isAnalyzing) return; // đang chạy sẵn (mở lại màn giữa chừng)
    final anyData = MealType.values
        .any((t) => plan.stateOf(t).status == MealTabStatus.data);
    unawaited(anyData ? plan.retryFailed() : plan.analyze());
  }

  void _check() {
    if (!mounted || _stage != _Stage.running) return;
    final statuses = _statuses;
    final reveal = widget.refreshMeal ??
        AnalysisTimeline.revealMeal(
            statuses, MealType.forVietnamTime(plan.now()));
    // Chỉ chờ ảnh của bữa sắp hiển thị; các bữa khác tải nền (Q2).
    final imagesReady =
        plan.leadImageSettled(reveal) || plan.imageWaitExpired(reveal);
    final step = AnalysisTimeline.next(
        statuses: statuses,
        minShowPassed: _minPassed,
        reduceMotion: _still,
        imagesReady: imagesReady);
    if (step == AnalysisStep.wait) {
      setState(() {}); // cập nhật viên bữa
      return;
    }
    if (step == AnalysisStep.preparingImages) {
      setState(() => _preparingImages = true);
      // Ảnh xong thì controller báo listener; hẹn thêm lượt kiểm khi hết giờ chờ (AC5).
      final left = plan.imageWaitRemaining(reveal);
      if (left != null && !(_imageTimer?.isActive ?? false)) {
        _imageTimer =
            Timer(left + const Duration(milliseconds: 50), _check);
      }
      return;
    }
    _imageTimer?.cancel();
    _preparingImages = false;
    _inFlight = false;
    if (step == AnalysisStep.failed) {
      setState(() => _stage = _Stage.failed);
      _clock.stop();
      mascot.play(MascotMood.concerned);
      return;
    }
    _reveal = widget.refreshMeal ??
        AnalysisTimeline.revealMeal(
            statuses, MealType.forVietnamTime(plan.now()));
    // Đổi trạng thái trước khi selectTab: selectTab báo listener và gọi lại _check.
    setState(() => _stage = _Stage.finale);
    plan.selectTab(_reveal);
    if (step == AnalysisStep.done) {
      _go();
      return;
    }
    _finale.forward(from: 0);
  }

  void _onFinale() {
    final f = _finale.value;
    if (!_flashed && f >= FinalePhase.anticipateEnd) {
      _flashed = true;
      HapticFeedback.heavyImpact();
    }
    if (!_cheered && f >= .6) {
      _cheered = true;
      mascot.play(MascotMood.celebrate);
    }
  }

  void _skip() {
    if (_stage != _Stage.finale) return;
    _finale.value = 1;
    _go();
  }

  void _go() {
    if (_left || !mounted) return;
    _left = true;
    Navigator.of(context).pop(true);
  }

  void _leave() {
    if (_left) return;
    _left = true;
    Navigator.of(context).pop(false);
  }

  @override
  void dispose() {
    plan.removeListener(_check);
    _minTimer?.cancel();
    _settleTimer?.cancel();
    _imageTimer?.cancel();
    _clock.dispose();
    _finale.dispose();
    mascot.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return MealTypography(
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _leave();
        },
        child: Scaffold(
          body: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _skip,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    MealColors.galaxyTop,
                    MealColors.galaxyMid,
                    MealColors.galaxyBottom
                  ],
                  stops: [0, .5, 1],
                ),
              ),
              child: AnimatedBuilder(
                animation: Listenable.merge([_clock, _finale]),
                builder: (context, _) => _scene(context, mq),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _scene(BuildContext context, MediaQueryData mq) {
    final t = _clock.value * 3600;
    final f = _stage == _Stage.finale ? _finale.value : 0.0;
    final collapse = finaleSeg(f, 0, FinalePhase.collapseEnd);
    final core = f < FinalePhase.collapseEnd
        ? 1.0
        : (f < FinalePhase.anticipateEnd
            ? 1 -
                .55 *
                    finaleSeg(
                        f, FinalePhase.collapseEnd, FinalePhase.anticipateEnd)
            : 0.0);
    final stageH = math.min(mq.size.height * .52, 440.0);
    final stageTop = mq.padding.top + 64;
    final center = Offset(mq.size.width / 2, stageTop + stageH / 2);
    final revealResult = plan.stateOf(_reveal).result;
    return Stack(children: [
      const Positioned.fill(key: ValueKey('analyzing-dust'), child: _Dust()),
      Positioned(
        key: const ValueKey('analyzing-stage'),
        left: 0,
        right: 0,
        top: stageTop,
        height: stageH,
        child: f >= FinalePhase.anticipateEnd
            ? const SizedBox.shrink()
            : GalaxyStage(
                t: t,
                collapse: collapse,
                core: core,
                mascotSpin: collapse * collapse * math.pi * 3,
                mascot: MascotView(
                    key: const ValueKey('analyzing-mascot'),
                    controller: mascot,
                    outfit: MascotOutfit.chef),
              ),
      ),
      if (f >= FinalePhase.plateStart &&
          revealResult != null &&
          revealResult.dishes.isNotEmpty)
        _PlateReveal(
          key: const ValueKey('analyzing-plate'),
          f: f,
          t: t,
          top: stageTop,
          height: stageH,
          meal: _reveal,
          result: revealResult,
          plan: plan,
          mascot: mascot,
        ),
      Positioned.fill(
        key: const ValueKey('analyzing-finale'),
        child: IgnorePointer(
            child: CustomPaint(painter: FinalePainter(f: f, center: center))),
      ),
      Positioned.fill(
        key: const ValueKey('analyzing-flash'),
        child: FlashLayer(
          f: f,
          center: Alignment(0, (center.dy / mq.size.height) * 2 - 1),
        ),
      ),
      Positioned(
        key: const ValueKey('analyzing-status'),
        left: 20,
        right: 20,
        top: stageTop + stageH + 16,
        child: Opacity(
          opacity: 1 -
              finaleSeg(f, FinalePhase.anticipateEnd, FinalePhase.flashPeak),
          child: _Status(
            failed: _stage == _Stage.failed,
            statuses: {for (final m in _meals) m: _statuses[m]!},
            refreshMeal: widget.refreshMeal,
            preparingImages: _preparingImages,
            onRetry: _start,
            onKeep: _leave,
          ),
        ),
      ),
      Positioned(
        key: const ValueKey('analyzing-back'),
        left: 12,
        top: mq.padding.top + 8,
        child: RoundIconButton(
          icon: Icons.arrow_back_ios_new_rounded,
          background: Colors.white.withValues(alpha: .85),
          color: MealColors.brandInk,
          onTap: _leave,
        ),
      ),
    ]);
  }
}

class _PlateReveal extends StatelessWidget {
  const _PlateReveal({
    super.key,
    required this.f,
    required this.t,
    required this.top,
    required this.height,
    required this.meal,
    required this.result,
    required this.plan,
    required this.mascot,
  });
  final double f, t, top, height;
  final MealType meal;
  final MealSuggestionResult result;
  final MealPlanController plan;
  final MascotController mascot;

  @override
  Widget build(BuildContext context) {
    final u = finaleSeg(f, FinalePhase.plateStart, .78);
    final s = Curves.elasticOut.transform(u) * .9 + .1;
    final title = Curves.easeOutCubic
        .transform(finaleSeg(f, FinalePhase.titleStart, .85));
    final pop = Curves.easeOutBack.transform(finaleSeg(f, .58, .8));
    const plate = 210.0;
    final dish = result.dishes.first;
    return Positioned(
      left: 0,
      right: 0,
      top: top,
      height: height + 110,
      child: Column(children: [
        SizedBox(height: (height - plate) / 2 - 10),
        SizedBox(
          width: plate + 120,
          height: plate + 40,
          child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Positioned(
                  left: 40,
                  top: 0,
                  width: plate + 40,
                  height: plate + 40,
                  child: CustomPaint(painter: ArcRingPainter(t, u)),
                ),
                Transform.scale(
                  scale: s,
                  child: Container(
                    width: plate,
                    height: plate,
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                            color: const Color(0xFFFFD98A)
                                .withValues(alpha: .7 * (1 - u * .5)),
                            blurRadius: 40,
                            spreadRadius: 6),
                        BoxShadow(
                            color: MealColors.violet.withValues(alpha: .18),
                            blurRadius: 24,
                            offset: const Offset(0, 10)),
                      ],
                    ),
                    child: MealDishHero(
                      tag: mealDishHeroTag(result.suggestionId, 0),
                      dish: dish,
                      plan: plan,
                      radius: plate / 2,
                      showAttribution: false,
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  bottom: -6,
                  child: Opacity(
                    opacity: pop.clamp(0, 1),
                    child: Transform.scale(
                      scale: pop,
                      alignment: Alignment.bottomCenter,
                      child: SizedBox(
                        width: 104,
                        height: 104,
                        child: MascotView(
                            controller: mascot,
                            outfit: MascotOutfit.chef,
                            size: 104),
                      ),
                    ),
                  ),
                ),
              ]),
        ),
        const SizedBox(height: 18),
        Opacity(
          opacity: title,
          child: Transform.translate(
            offset: Offset(0, 14 * (1 - title)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(children: [
                Text(dish.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                        color: MealColors.ink)),
                const SizedBox(height: 6),
                Text('Dumi gợi ý cho ${meal.mealLabel}',
                    style:
                        const TextStyle(fontSize: 15, color: MealColors.ink2)),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({
    required this.failed,
    required this.statuses,
    required this.refreshMeal,
    required this.preparingImages,
    required this.onRetry,
    required this.onKeep,
  });
  final bool failed;
  final bool preparingImages;
  final Map<MealType, MealTabStatus> statuses;
  final MealType? refreshMeal;
  final VoidCallback onRetry, onKeep;

  @override
  Widget build(BuildContext context) {
    if (failed) {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        Text(
            refreshMeal == null
                ? 'Dumi chưa lên được thực đơn'
                : 'Dumi chưa tìm được món khác',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: MealColors.ink)),
        const SizedBox(height: 6),
        Text(
            refreshMeal == null
                ? 'Kết nối đang chập chờn. Bạn thử lại nhé.'
                : 'Món cũ cho ${refreshMeal!.mealLabel} vẫn còn. Bạn thử lại nhé.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, color: MealColors.ink2)),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            key: const ValueKey('analyzing-retry'),
            style: FilledButton.styleFrom(
                backgroundColor: MealColors.brand,
                shape: const StadiumBorder()),
            onPressed: onRetry,
            child: const Text('Thử lại',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
        if (refreshMeal != null)
          TextButton(
            key: const ValueKey('analyzing-keep'),
            onPressed: onKeep,
            child: const Text('Giữ món cũ',
                style: TextStyle(fontSize: 15, color: MealColors.brand)),
          ),
      ]);
    }
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(
          preparingImages
              ? 'Đang chuẩn bị ảnh món…'
              : refreshMeal == null
                  ? 'Dumi đang lên thực đơn…'
                  : 'Dumi đang tìm món khác…',
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: MealColors.ink,
              letterSpacing: -.3)),
      const SizedBox(height: 6),
      // Không hiện tên thuốc, bệnh nền, dị ứng cụ thể (AC3).
      const Text('Dựa trên thuốc, bệnh nền và dị ứng của bạn',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: MealColors.ink2)),
      const SizedBox(height: 22),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (final m in statuses.keys) ...[
          _MealPill(meal: m, status: statuses[m]!),
          if (m != statuses.keys.last) const SizedBox(width: 10),
        ],
      ]),
    ]);
  }
}

/// Viên Sáng/Trưa/Tối: đang chạy (vòng xoay) → tích (nảy) / cảnh báo, theo response thật.
class _MealPill extends StatelessWidget {
  const _MealPill({required this.meal, required this.status});
  final MealType meal;
  final MealTabStatus status;

  @override
  Widget build(BuildContext context) {
    final done = status == MealTabStatus.data;
    final err = status == MealTabStatus.error;
    return Semantics(
      label: '${meal.tabLabel}: ${done ? 'xong' : err ? 'lỗi' : 'đang chạy'}',
      child: AnimatedContainer(
        key: ValueKey('meal-pill-${meal.apiValue}'),
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.fromLTRB(10, 9, 16, 9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: done ? 1 : .8),
          borderRadius: BorderRadius.circular(40),
          border: Border.all(
              color:
                  done ? MealColors.teal.withValues(alpha: .5) : Colors.white),
          boxShadow: [
            BoxShadow(
                color: MealColors.violet.withValues(alpha: .12),
                blurRadius: 14,
                offset: const Offset(0, 4))
          ],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: 24,
            height: 24,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 380),
              switchInCurve: kMealSpring,
              transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
              child: done
                  ? const _Dot(
                      key: ValueKey('ok'),
                      color: MealColors.teal,
                      icon: Icons.check_rounded)
                  : err
                      ? const _Dot(
                          key: ValueKey('err'),
                          color: MealColors.caution,
                          icon: Icons.priority_high_rounded)
                      : const _Spinner(key: ValueKey('run')),
            ),
          ),
          const SizedBox(width: 8),
          Text(meal.tabLabel,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: MealColors.ink)),
        ]),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({super.key, required this.color, required this.icon});
  final Color color;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, size: 17, color: Colors.white),
      );
}

class _Spinner extends StatelessWidget {
  const _Spinner({super.key});
  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return Container(
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: MealColors.violet, width: 2.6)),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(2),
      child: CircularProgressIndicator(
        strokeWidth: 2.6,
        strokeCap: StrokeCap.round,
        color: MealColors.violet,
        backgroundColor: MealColors.violet.withValues(alpha: .15),
      ),
    );
  }
}

/// Hạt sáng trôi chậm trên nền.
class _Dust extends StatefulWidget {
  const _Dust();
  @override
  State<_Dust> createState() => _DustState();
}

class _DustState extends State<_Dust> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 40));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: AnimatedBuilder(
            animation: _c,
            builder: (_, __) => CustomPaint(painter: _DustPainter(_c.value))),
      );
}

class _DustPainter extends CustomPainter {
  _DustPainter(this.v);
  final double v;
  static final _pts = List.generate(26, (i) {
    final r = math.Random(i * 31 + 3);
    return (
      r.nextDouble(),
      r.nextDouble(),
      1.5 + r.nextDouble() * 2.5,
      r.nextDouble()
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint();
    for (final (x, y, s, ph) in _pts) {
      final yy = (y - v * (.3 + ph * .4)) % 1;
      final a = .25 + .3 * math.sin((v * 6 + ph) * math.pi * 2).abs();
      p.color =
          (ph > .5 ? MealColors.violet : MealColors.teal).withValues(alpha: a);
      canvas.drawCircle(Offset(x * size.width, yy * size.height), s, p);
    }
  }

  @override
  bool shouldRepaint(_DustPainter old) => old.v != v;
}
