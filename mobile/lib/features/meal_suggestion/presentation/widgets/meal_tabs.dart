import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import 'meal_ui.dart';

/// Thanh tab dạng viên: nút trắng trượt theo lò xo; kéo nút để đổi tab.
class MealPillTabs extends StatefulWidget {
  const MealPillTabs({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
    this.badges = const {},
    this.height = 50,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;
  final Map<int, Widget> badges;
  final double height;

  @override
  State<MealPillTabs> createState() => _MealPillTabsState();
}

class _MealPillTabsState extends State<MealPillTabs>
    with SingleTickerProviderStateMixin {
  late final AnimationController _x = AnimationController.unbounded(
      vsync: this, value: widget.selected.toDouble());
  static const _spring =
      SpringDescription(mass: 1, stiffness: 520, damping: 34);

  @override
  void didUpdateWidget(MealPillTabs old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) _animateTo(widget.selected.toDouble());
  }

  void _animateTo(double target) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _x.value = target;
      return;
    }
    _x.animateWith(SpringSimulation(_spring, _x.value, target, _x.velocity));
  }

  @override
  void dispose() {
    _x.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.labels.length;
    return LayoutBuilder(builder: (context, box) {
      const pad = 4.0;
      final w = (box.maxWidth - pad * 2) / n;
      return GestureDetector(
        onHorizontalDragUpdate: (d) =>
            _x.value = (_x.value + d.delta.dx / w).clamp(0, n - 1.0),
        onHorizontalDragEnd: (_) {
          final i = _x.value.round();
          _animateTo(i.toDouble());
          if (i != widget.selected) widget.onChanged(i);
        },
        child: Container(
          height: widget.height,
          padding: const EdgeInsets.all(pad),
          decoration: BoxDecoration(
              color: const Color(0xFFEDEFEC),
              borderRadius: BorderRadius.circular(widget.height)),
          child: AnimatedBuilder(
            animation: _x,
            builder: (context, _) => Stack(children: [
              Positioned(
                left: _x.value * w,
                width: w,
                top: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(widget.height),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x1A000000),
                          blurRadius: 10,
                          offset: Offset(0, 3))
                    ],
                  ),
                ),
              ),
              Row(children: [
                for (var i = 0; i < n; i++)
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (i == widget.selected) return;
                        widget.onChanged(i);
                      },
                      child: Center(
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(
                            widget.labels[i],
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color.lerp(
                                  MealColors.brand,
                                  MealColors.ink2,
                                  ((_x.value - i).abs()).clamp(0, 1)),
                            ),
                          ),
                          if (widget.badges[i] case final b?) ...[
                            const SizedBox(width: 6),
                            b
                          ],
                        ]),
                      ),
                    ),
                  ),
              ]),
            ]),
          ),
        ),
      );
    });
  }
}
