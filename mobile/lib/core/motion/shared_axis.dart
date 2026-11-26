import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

/// One transition for the whole app: Material 3 "shared axis" on the horizontal axis.
/// The incoming page slides in 30 dp from the leading edge while fading in; the outgoing page
/// slides 30 dp the other way while fading out. Reduce-motion turns it off.
const sharedAxisDuration = Duration(milliseconds: 300);
const sharedAxisDistance = 30.0;
const _curve = Curves.easeInOutCubic;

/// Đổi tab bấm nhiều lần mỗi ngày: ngắn hơn chuyển trang và ease-out mạnh để phản hồi ngay
/// từ frame đầu, không đợi pha "ease-in". Viên chọn của AppNavBar dùng chung cặp giá trị này.
const sharedAxisTabDuration = Duration(milliseconds: 280);
const sharedAxisTabCurve = Cubic(0.23, 1, 0.32, 1);

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

/// [IndexedStack] with a shared-axis switch between tabs, plus an optional swipe pager.
///
/// Every child keeps the same widget structure whatever its role (shown, leaving, hidden),
/// so tab state and scroll positions survive. Hidden tabs are offstage with tickers off,
/// like [IndexedStack]. Direction follows the tab index.
///
/// When [swipeTarget] and [onSwiped] are set, a horizontal swipe on the content moves to the
/// neighbouring tab. A swipe is a commitment, not a scrub: as soon as the drag shows a direction
/// that has a neighbour, the pages slide all the way there on their own (one tab per swipe) and
/// the rest of that gesture is ignored, so the user can never park the UI between two tabs.
/// Where there is no neighbour the page rubber-bands under the finger and springs back.
/// Progress is published on [swipe] in tab units (positive = next tab) so other UI, like the nav
/// bar pill, is derived from the same value instead of animating on its own. Inner horizontal
/// scrollables and drags win the gesture arena, since they sit deeper in the hit test.
class SharedAxisTabSwitcher extends StatefulWidget {
  const SharedAxisTabSwitcher(
      {super.key,
      required this.index,
      required this.children,
      this.swipeTarget,
      this.onSwiped,
      this.swipe});

  final int index;
  final List<Widget> children;

  /// Child index reached by swiping from [index] towards [dir] (+1 next, -1 previous), or
  /// null when there is nothing that way.
  final int? Function(int index, int dir)? swipeTarget;
  final ValueChanged<int>? onSwiped;
  final ValueNotifier<double>? swipe;

  @override
  State<SharedAxisTabSwitcher> createState() => _SharedAxisTabSwitcherState();
}

// Vuốt sang tab: trang chạy hết quãng với curve chung của chuyển tab, dài hơn chút vì đi
// trọn bề rộng màn.
const _pageSwipeDuration = Duration(milliseconds: 320);
// Bật về khi kéo ở đầu không còn tab: tắt dần tới hạn, không nảy.
final _pageSpring =
    SpringDescription.withDampingRatio(mass: 1, stiffness: 380, ratio: 1);
const _pageEdgeFriction = .25;
const _pageEdgeLimit = .15;

class _SharedAxisTabSwitcherState extends State<SharedAxisTabSwitcher>
    with TickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
      vsync: this, duration: sharedAxisTabDuration, value: 1)
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _previous = null);
      }
    });
  // Tiến độ vuốt theo đơn vị tab: 0 = đứng yên, 1 = đã sang hẳn tab sau, -1 = tab trước.
  late final AnimationController _drag =
      AnimationController.unbounded(vsync: this)
        ..addListener(() => widget.swipe?.value = _drag.value);
  int? _previous;
  // Tab đổi do chính cú vuốt chốt lại: trang mới đã nằm đúng chỗ, không chạy shared-axis nữa.
  bool _swipeCommitted = false;
  // Hướng cú vuốt đang tự chạy sang tab (null = không có); trong lúc đó bỏ qua mọi thao tác kéo.
  int? _swipingTo;
  // Cú kéo bắt đầu khi trang còn đang tự chạy: bỏ qua cả cú kéo đó.
  bool _ignoreDrag = false;
  // Vị trí/độ mờ của tab rời đi lúc bắt đầu: khác 0/1 khi đổi tab giữa chừng, để tab đó
  // đi tiếp từ chỗ đang đứng thay vì nhảy về giữa rồi mới trượt ra.
  double _leaveDx = 0, _leaveOpacity = 1;

  bool get _swipeEnabled =>
      widget.swipeTarget != null && widget.onSwiped != null;

  int? _neighbour(int dir) => widget.swipeTarget?.call(widget.index, dir);

  bool _forward(int index, int? previous) =>
      previous == null || index > previous;

  double _dir(bool forward) =>
      (Directionality.of(context) == TextDirection.rtl ? -1.0 : 1.0) *
      (forward ? 1.0 : -1.0);

  @override
  void didUpdateWidget(SharedAxisTabSwitcher old) {
    super.didUpdateWidget(old);
    if (old.index == widget.index) return;
    if (_swipeCommitted || _reduceMotion(context)) {
      _swipeCommitted = false;
      _previous = null;
      _controller.value = 1;
      return;
    }
    // Đổi tab bằng nút trong lúc trang còn đang trượt theo cú vuốt: bỏ cú vuốt.
    _drag.stop();
    _swipingTo = null;
    _drag.value = 0;
    if (_controller.isAnimating && _previous != null) {
      // Tab cũ (old.index) đang trượt vào dở: lấy đúng trạng thái hiện tại của nó.
      final t = sharedAxisTabCurve.transform(_controller.value);
      final dir = _dir(_forward(old.index, _previous));
      _leaveDx = dir * sharedAxisDistance * (1 - t);
      _leaveOpacity = _enterOpacity(t);
    } else {
      _leaveDx = 0;
      _leaveOpacity = 1;
    }
    _previous = old.index;
    _controller.forward(from: 0);
  }

  static double _enterOpacity(double t) => (t / .6).clamp(0.0, 1.0);

  @override
  void dispose() {
    _controller.dispose();
    _drag.dispose();
    super.dispose();
  }

  void _onDragStart(DragStartDetails _) {
    _ignoreDrag = _swipingTo != null;
    if (_ignoreDrag) return;
    if (_previous != null) {
      // đang chạy chuyển tab do bấm: kết thúc ngay để cú vuốt bắt đầu từ trạng thái đứng yên
      _controller.value = 1;
      setState(() => _previous = null);
    }
    _drag.stop();
  }

  void _onDragUpdate(DragUpdateDetails d, double width) {
    if (_ignoreDrag || _swipingTo != null) return;
    var delta = -d.delta.dx / width;
    final v = _drag.value;
    final next = v + delta;
    final dir = next.sign.toInt();
    if (dir == 0) return;
    if (_neighbour(dir) != null) {
      _swipeTo(dir);
      return;
    }
    // không có tab phía đó: nặng dần dưới ngón tay, không dừng cứng
    if (next.abs() > v.abs()) delta *= _pageEdgeFriction;
    _drag.value = (v + delta).clamp(-_pageEdgeLimit, _pageEdgeLimit);
  }

  void _onDragEnd(DragEndDetails d, double width) {
    if (_ignoreDrag || _swipingTo != null) return;
    _springBack(-d.velocity.pixelsPerSecond.dx / width);
  }

  void _onDragCancel() {
    if (_ignoreDrag || _swipingTo != null) return;
    _springBack(0);
  }

  /// Đã có hướng: chạy hẳn sang tab kế, không chờ thả tay và không cho dừng giữa chừng.
  void _swipeTo(int dir) {
    final target = _neighbour(dir);
    _swipingTo = dir;
    // phần còn lại của cú kéo này không được kích thêm tab nữa, kể cả sau khi đã chốt
    _ignoreDrag = true;
    HapticFeedback.selectionClick();
    if (_reduceMotion(context)) {
      _drag.value = dir.toDouble();
      _commit(target);
      return;
    }
    _drag
        .animateTo(dir.toDouble(),
            duration: _pageSwipeDuration, curve: sharedAxisTabCurve)
        .orCancel
        .then((_) => _commit(target), onError: (Object _) {
      _swipingTo = null;
    });
  }

  void _springBack(double velocity) {
    if (_drag.value == 0) return;
    if (_reduceMotion(context)) {
      _drag.value = 0;
      return;
    }
    _drag
        .animateWith(SpringSimulation(_pageSpring, _drag.value, 0, velocity))
        .orCancel
        // spring dừng trong sai số nhỏ; chốt đúng 0 để trang và viên về hẳn chỗ cũ
        .then((_) => _drag.value = 0, onError: (Object _) {});
  }

  void _commit(int? target) {
    _swipingTo = null;
    if (!mounted) return;
    if (target == null) {
      _drag.value = 0;
      return;
    }
    _swipeCommitted = true;
    _drag.value = 0;
    widget.onSwiped!(target);
  }

  @override
  Widget build(BuildContext context) {
    final previous = _previous;
    final dir = _dir(_forward(widget.index, previous));
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final stack = AnimatedBuilder(
        animation: Listenable.merge([_controller, _drag]),
        builder: (context, _) {
          final t = sharedAxisTabCurve.transform(_controller.value);
          final swipe = previous == null ? _drag.value : 0.0;
          final neighbour = swipe == 0 ? null : _neighbour(swipe.sign.toInt());
          return Stack(
            fit: StackFit.expand,
            children: [
              for (var i = 0; i < widget.children.length; i++)
                swipe == 0
                    ? _tab(i, previous, t, dir)
                    : _page(i, swipe, neighbour, width),
            ],
          );
        },
      );
      if (!_swipeEnabled) return stack;
      return GestureDetector(
        // nhận vuốt cả ở vùng trống của trang (khoảng giữa các widget con)
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: _onDragStart,
        onHorizontalDragUpdate: (d) => _onDragUpdate(d, width),
        onHorizontalDragEnd: (d) => _onDragEnd(d, width),
        onHorizontalDragCancel: _onDragCancel,
        child: stack,
      );
    });
  }

  /// Vuốt: tab hiện tại và tab kế nằm cạnh nhau, cả hai dịch theo ngón tay.
  Widget _page(int i, double swipe, int? neighbour, double width) {
    final current = i == widget.index;
    final next = i == neighbour;
    final dx = current
        ? -swipe * width
        : next
            ? (swipe.sign - swipe) * width
            : 0.0;
    return _slot(i,
        visible: current || next, interactive: current, opacity: 1, dx: dx);
  }

  Widget _tab(int i, int? previous, double t, double dir) {
    final current = i == widget.index;
    final leaving = i == previous;
    var opacity = 1.0;
    var dx = 0.0;
    if (current && previous != null) {
      opacity = _enterOpacity(t);
      dx = dir * sharedAxisDistance * (1 - t);
    } else if (leaving) {
      opacity = _leaveOpacity * (1 - (t / .5).clamp(0.0, 1.0));
      dx = _leaveDx - dir * sharedAxisDistance * t;
    }
    return _slot(i,
        visible: current || leaving,
        interactive: current,
        opacity: opacity,
        dx: dx);
  }

  // Cùng một cấu trúc cho mọi vai trò để state của tab không bị dựng lại.
  Widget _slot(int i,
          {required bool visible,
          required bool interactive,
          required double opacity,
          required double dx}) =>
      Offstage(
        key: ValueKey(i),
        offstage: !visible,
        child: TickerMode(
          enabled: visible,
          child: IgnorePointer(
            ignoring: !interactive,
            child: Opacity(
              opacity: opacity,
              child: Transform.translate(
                offset: Offset(dx, 0),
                // dịch cả trang mỗi frame chỉ là ghép lớp, không vẽ lại nội dung
                child: RepaintBoundary(child: widget.children[i]),
              ),
            ),
          ),
        ),
      );
}
