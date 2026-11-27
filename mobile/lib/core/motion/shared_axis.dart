import 'package:flutter/material.dart';

/// One transition for the whole app: Material 3 "shared axis" on the horizontal axis.
/// The incoming page slides in 30 dp from the leading edge while fading in; the outgoing page
/// slides 30 dp the other way while fading out. Reduce-motion turns it off.
const sharedAxisDuration = Duration(milliseconds: 300);
const sharedAxisDistance = 30.0;
const _curve = Curves.easeInOutCubic;

bool _reduceMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// Wraps [child] for a page that is [animation] in, and [secondaryAnimation] out under a
/// newer page. Forward means "deeper" (push, or a later tab).
Widget sharedAxisTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  if (_reduceMotion(context)) return child;
  final dir = Directionality.of(context) == TextDirection.rtl ? -1.0 : 1.0;
  return AnimatedBuilder(
    animation: Listenable.merge([animation, secondaryAnimation]),
    child: child,
    builder: (context, child) {
      final enter = _curve.transform(animation.value);
      final exit = _curve.transform(secondaryAnimation.value);
      final dx = dir * sharedAxisDistance * ((1 - enter) - exit);
      // Fade the incoming page in over the second half, the outgoing one out over the first.
      final opacity = ((enter - .3) / .7).clamp(0.0, 1.0) *
          (1 - (exit / .7).clamp(0.0, 1.0));
      return Opacity(
        opacity: opacity,
        child: Transform.translate(offset: Offset(dx, 0), child: child),
      );
    },
  );
}

/// Theme builder so every [MaterialPageRoute] in the app uses [sharedAxisTransition].
class SharedAxisPageTransitionsBuilder extends PageTransitionsBuilder {
  const SharedAxisPageTransitionsBuilder();

  @override
  Duration get transitionDuration => sharedAxisDuration;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) =>
      sharedAxisTransition(context, animation, secondaryAnimation, child);
}

const sharedAxisPageTransitionsTheme = PageTransitionsTheme(builders: {
  TargetPlatform.android: SharedAxisPageTransitionsBuilder(),
  TargetPlatform.iOS: SharedAxisPageTransitionsBuilder(),
  TargetPlatform.fuchsia: SharedAxisPageTransitionsBuilder(),
  TargetPlatform.linux: SharedAxisPageTransitionsBuilder(),
  TargetPlatform.macOS: SharedAxisPageTransitionsBuilder(),
  TargetPlatform.windows: SharedAxisPageTransitionsBuilder(),
});

/// The only custom page route in the app: same motion as the theme, for routes that need
/// [PageRouteBuilder] features (a typed result, opaque false, a custom builder).
PageRouteBuilder<T> sharedAxisRoute<T>({
  required WidgetBuilder builder,
  RouteSettings? settings,
  bool opaque = true,
}) =>
    PageRouteBuilder<T>(
      settings: settings,
      opaque: opaque,
      transitionDuration: sharedAxisDuration,
      reverseTransitionDuration: sharedAxisDuration,
      pageBuilder: (context, _, __) => builder(context),
      transitionsBuilder: sharedAxisTransition,
    );

/// [IndexedStack] with a shared-axis switch between tabs.
///
/// Every child keeps the same widget structure whatever its role (shown, leaving, hidden),
/// so tab state and scroll positions survive. Hidden tabs are offstage with tickers off,
/// like [IndexedStack]. Direction follows the tab index.
class SharedAxisTabSwitcher extends StatefulWidget {
  const SharedAxisTabSwitcher(
      {super.key, required this.index, required this.children});

  final int index;
  final List<Widget> children;

  @override
  State<SharedAxisTabSwitcher> createState() => _SharedAxisTabSwitcherState();
}

class _SharedAxisTabSwitcherState extends State<SharedAxisTabSwitcher>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: sharedAxisDuration, value: 1)
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed && mounted) {
            setState(() => _previous = null);
          }
        });
  int? _previous;

  @override
  void didUpdateWidget(SharedAxisTabSwitcher old) {
    super.didUpdateWidget(old);
    if (old.index == widget.index) return;
    if (_reduceMotion(context)) {
      _previous = null;
      _controller.value = 1;
      return;
    }
    _previous = old.index;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final previous = _previous;
    final forward = previous == null || widget.index > previous;
    final dir = (Directionality.of(context) == TextDirection.rtl ? -1.0 : 1.0) *
        (forward ? 1.0 : -1.0);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _curve.transform(_controller.value);
        return Stack(
          fit: StackFit.expand,
          children: [
            for (var i = 0; i < widget.children.length; i++)
              _tab(i, previous, t, dir),
          ],
        );
      },
    );
  }

  Widget _tab(int i, int? previous, double t, double dir) {
    final current = i == widget.index;
    final leaving = i == previous;
    final visible = current || leaving;
    var opacity = 1.0;
    var dx = 0.0;
    if (current && previous != null) {
      opacity = ((t - .3) / .7).clamp(0.0, 1.0);
      dx = dir * sharedAxisDistance * (1 - t);
    } else if (leaving) {
      opacity = 1 - (t / .7).clamp(0.0, 1.0);
      dx = -dir * sharedAxisDistance * t;
    }
    return Offstage(
      key: ValueKey(i),
      offstage: !visible,
      child: TickerMode(
        enabled: visible,
        child: IgnorePointer(
          ignoring: !current,
          child: Opacity(
            opacity: opacity,
            child: Transform.translate(
              offset: Offset(dx, 0),
              child: widget.children[i],
            ),
          ),
        ),
      ),
    );
  }
}
