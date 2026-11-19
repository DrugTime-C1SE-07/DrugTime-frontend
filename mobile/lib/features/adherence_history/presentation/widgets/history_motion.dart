import 'package:flutter/material.dart';

abstract final class HistoryMotion {
  static const selection = Duration(milliseconds: 180);
  static const entrance = Duration(milliseconds: 240);
  static const progress = Duration(milliseconds: 450);
  static const shimmer = Duration(milliseconds: 1200);

  static bool enabled(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_MotionEnabled>()?.enabled ??
      (!MediaQuery.disableAnimationsOf(context) &&
          TickerMode.valuesOf(context).enabled &&
          (ModalRoute.isCurrentOf(context) ?? true) &&
          (WidgetsBinding.instance.lifecycleState == null ||
              WidgetsBinding.instance.lifecycleState ==
                  AppLifecycleState.resumed));
}

/// Each route owns its policy; hidden tabs and covered routes stop repeating work.
class HistoryMotionScope extends StatefulWidget {
  const HistoryMotionScope(
      {super.key, required this.child, this.active = true});
  final Widget child;
  final bool active;
  @override
  State<HistoryMotionScope> createState() => _HistoryMotionScopeState();
}

class _HistoryMotionScopeState extends State<HistoryMotionScope>
    with WidgetsBindingObserver {
  AppLifecycleState? _lifecycle = WidgetsBinding.instance.lifecycleState;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (mounted) setState(() => _lifecycle = state);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.active &&
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.isCurrentOf(context) ?? true) &&
        (_lifecycle == null || _lifecycle == AppLifecycleState.resumed);
    return TickerMode(
        enabled: enabled,
        child: _MotionEnabled(enabled: enabled, child: widget.child));
  }
}

class _MotionEnabled extends InheritedWidget {
  const _MotionEnabled({required this.enabled, required super.child});
  final bool enabled;
  @override
  bool updateShouldNotify(_MotionEnabled oldWidget) =>
      enabled != oldWidget.enabled;
}

/// The route keeps live widgets instead of a raster snapshot of health content.
class HistoryPageRoute<T> extends MaterialPageRoute<T> {
  HistoryPageRoute(
      {required super.builder, super.settings, required this.reduceMotion})
      : super(allowSnapshotting: false);
  final bool reduceMotion;
  @override
  Duration get transitionDuration =>
      reduceMotion ? Duration.zero : const Duration(milliseconds: 250);
  @override
  Duration get reverseTransitionDuration =>
      reduceMotion ? Duration.zero : const Duration(milliseconds: 220);
  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
          Animation<double> secondaryAnimation, Widget child) =>
      reduceMotion || MediaQuery.disableAnimationsOf(context)
          ? child
          : super
              .buildTransitions(context, animation, secondaryAnimation, child);
}

/// Animates only the current child. No outgoing child or payload is retained.
class HistoryEntrance extends StatefulWidget {
  const HistoryEntrance(
      {super.key,
      required this.child,
      this.index = 0,
      this.offset = const Offset(0, 8)});
  final Widget child;
  final int index;
  final Offset offset;
  @override
  State<HistoryEntrance> createState() => _HistoryEntranceState();
}

class _HistoryEntranceState extends State<HistoryEntrance>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 240 + widget.index.clamp(0, 5) * 35));
  bool _started = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!HistoryMotion.enabled(context) || widget.index >= 6) {
      _started = true;
      _controller.stop();
      _controller.value = 1;
    } else if (!_started) {
      _started = true;
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!HistoryMotion.enabled(context) || widget.index >= 6) {
      return widget.child;
    }
    final delay = widget.index * 35 / (240 + widget.index * 35);
    return AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (context, child) {
          final value = Curves.easeOutCubic.transform(
              ((_controller.value - delay) / (1 - delay)).clamp(0.0, 1.0));
          return Opacity(
              opacity: value,
              alwaysIncludeSemantics: true,
              child: Transform.translate(
                  offset: widget.offset * (1 - value), child: child));
        });
  }
}

class HistorySelection extends StatelessWidget {
  const HistorySelection(
      {super.key,
      required this.decoration,
      required this.child,
      this.margin,
      this.padding});
  final Decoration decoration;
  final Widget child;
  final EdgeInsetsGeometry? margin, padding;
  @override
  Widget build(BuildContext context) => HistoryMotion.enabled(context)
      ? AnimatedContainer(
          duration: HistoryMotion.selection,
          curve: Curves.easeOut,
          margin: margin,
          padding: padding,
          decoration: decoration,
          child: child)
      : Container(
          margin: margin,
          padding: padding,
          decoration: decoration,
          child: child);
}

class HistoryProgress extends StatelessWidget {
  const HistoryProgress(
      {super.key,
      required this.value,
      required this.color,
      required this.backgroundColor});
  final double value;
  final Color color, backgroundColor;
  Widget _bar(double current) => LinearProgressIndicator(
      value: current,
      minHeight: 6,
      color: color,
      backgroundColor: backgroundColor);
  @override
  Widget build(BuildContext context) => !HistoryMotion.enabled(context)
      ? _bar(value)
      : TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value),
          duration: HistoryMotion.progress,
          curve: Curves.easeOutCubic,
          builder: (_, current, __) => _bar(current));
}

class HistoryExpandableSize extends StatelessWidget {
  const HistoryExpandableSize({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => !HistoryMotion.enabled(context)
      ? child
      : AnimatedSize(
          duration: HistoryMotion.entrance,
          alignment: Alignment.topCenter,
          child: child);
}

class HistoryShimmer extends StatefulWidget {
  const HistoryShimmer(
      {super.key,
      required this.child,
      required this.base,
      required this.highlight});
  final Widget child;
  final Color base, highlight;
  @override
  State<HistoryShimmer> createState() => _HistoryShimmerState();
}

class _HistoryShimmerState extends State<HistoryShimmer>
    with SingleTickerProviderStateMixin {
  late final _controller =
      AnimationController(vsync: this, duration: HistoryMotion.shimmer);
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (HistoryMotion.enabled(context)) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
      child: !HistoryMotion.enabled(context)
          ? widget.child
          : AnimatedBuilder(
              animation: _controller,
              child: widget.child,
              builder: (_, child) => ShaderMask(
                  blendMode: BlendMode.srcATop,
                  shaderCallback: (rect) => LinearGradient(
                          begin: Alignment(-3 + 6 * _controller.value, 0),
                          end: Alignment(-1 + 6 * _controller.value, 0),
                          colors: [widget.base, widget.highlight, widget.base])
                      .createShader(rect),
                  child: child)));
}
