import 'package:flutter/material.dart';
import '../../../../core/motion/shared_axis.dart';

const healthSetupMotionDuration = Duration(milliseconds: 280);
const _easeOut = Cubic(0.23, 1, 0.32, 1);

Widget healthSetupTransition(
  Animation<double> animation,
  Widget child, {
  double direction = 1,
}) {
  final eased = animation.drive(CurveTween(curve: _easeOut));
  final opacity = animation.drive(
    CurveTween(curve: const Interval(0, 0.8, curve: Curves.easeInOut)),
  );
  return FadeTransition(
    opacity: opacity,
    child: SlideTransition(
      position: Tween(begin: Offset(direction * 0.085, 0), end: Offset.zero)
          .animate(eased),
      textDirection: TextDirection.ltr,
      child: child,
    ),
  );
}

class HealthSetupAnimatedStep extends StatelessWidget {
  const HealthSetupAnimatedStep({
    super.key,
    required this.child,
    this.direction = 1,
  });

  final Widget child;
  final double direction;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return ClipRect(
      child: AnimatedSwitcher(
        duration: healthSetupMotionDuration,
        layoutBuilder: (current, previous) => Stack(
          fit: StackFit.expand,
          children: [
            for (final outgoing in previous)
              ExcludeSemantics(
                key: outgoing.key,
                child: IgnorePointer(child: outgoing),
              ),
            if (current != null) current,
          ],
        ),
        transitionBuilder: (child, animation) => healthSetupTransition(
          animation,
          child,
          direction: child.key == this.child.key ? direction : -direction,
        ),
        child: child,
      ),
    );
  }
}

/// Health-setup pages use the app-wide shared-axis route (AC9).
PageRouteBuilder<T> healthSetupPageRoute<T>({
  required RouteSettings settings,
  required WidgetBuilder builder,
}) =>
    sharedAxisRoute<T>(settings: settings, builder: builder);
