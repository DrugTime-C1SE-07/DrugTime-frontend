import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/motion/shared_axis.dart';
import 'theme/app_theme.dart';

/// Thanh điều hướng dưới của app.
///
/// Viên chọn là một lớp riêng nằm trên [NavigationBar], vị trí là số thực (0 = tab đầu,
/// 3 = tab cuối) nên nó trượt ngang qua thanh thay vì nhảy.
/// - Bấm: viên trượt thẳng tới tab được chọn, cùng duration/curve với nội dung tab
///   ([sharedAxisTabDuration], [sharedAxisTabCurve]); không nảy vì người dùng không "ném" gì.
/// - Vuốt nội dung màn: thanh không tự nhận kéo. Viên đọc [swipe] (tiến độ vuốt, đơn vị tab,
///   dương là sang tab sau) nên luôn đứng đúng chỗ của trang đang kéo, kể cả khi người dùng
///   giữ tay, kéo ngược hay thả cho spring đưa về.
/// Nhãn chỉ bung ra khi viên tới gần tab, và co lại khi rời đi.
class AppNavBar extends StatefulWidget {
  const AppNavBar(
      {super.key,
      required this.selectedIndex,
      required this.onSelected,
      this.swipe});

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final ValueListenable<double>? swipe;

  static const items = [
    (icon: LucideIcons.house, label: 'Trang chủ'),
    (icon: LucideIcons.pill, label: 'Thuốc'),
    (icon: LucideIcons.calendarClock, label: 'Lịch nhắc'),
    (icon: LucideIcons.userRound, label: 'Hồ sơ'),
  ];

  @override
  State<AppNavBar> createState() => _AppNavBarState();
}

const _active = Color(0xFF0B5A8A);
const _pillColor = Color(0xFFD9EEFC);
const _barHeight = 68.0;
const _pillHeight = 52.0;
const _pillInset = 6.0;
// Nhãn bắt đầu bung khi viên cách tâm tab dưới khoảng này (tính theo bề rộng một ô).
const _labelReach = .35;
// Bề rộng (theo ô) quanh điểm giữa hai tab mà icon trong viên co/mờ để đổi.
const _iconSwapBand = .15;
// Bấm nhảy xa hơn một ô thì kéo dài thêm chút, để quãng dài không bị vụt qua.
const _extraPerStep = Duration(milliseconds: 40);

class _AppNavBarState extends State<AppNavBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pos = AnimationController.unbounded(
      vsync: this, value: widget.selectedIndex.toDouble());
  // Vị trí viên ở frame vuốt cuối cùng; để nhận ra tab vừa đổi là do vuốt (viên đã tới nơi).
  double? _swipedTo;

  int get _last => AppNavBar.items.length - 1;

  bool get _still => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  void initState() {
    super.initState();
    widget.swipe?.addListener(_onSwipe);
  }

  @override
  void didUpdateWidget(AppNavBar old) {
    super.didUpdateWidget(old);
    if (old.swipe != widget.swipe) {
      old.swipe?.removeListener(_onSwipe);
      widget.swipe?.addListener(_onSwipe);
    }
    if (old.selectedIndex == widget.selectedIndex) return;
    final swiped = _swipedTo;
    _swipedTo = null;
    if (swiped != null && (swiped - widget.selectedIndex).abs() < .05) {
      // vuốt đã đưa viên tới đúng tab mới: chỉ chốt lại, không chạy thêm
      _pos.value = widget.selectedIndex.toDouble();
    } else {
      _slideTo(widget.selectedIndex);
    }
  }

  @override
  void dispose() {
    widget.swipe?.removeListener(_onSwipe);
    _pos.dispose();
    super.dispose();
  }

  void _onSwipe() {
    final v = widget.swipe!.value;
    if (v != 0) _swipedTo = widget.selectedIndex + v;
    _pos.stop();
    _pos.value = (widget.selectedIndex + v).clamp(-.5, _last + .5);
  }

  void _slideTo(int target) {
    if (_still) {
      _pos.value = target.toDouble();
      return;
    }
    final steps = (target - _pos.value).abs().ceil().clamp(1, _last);
    _pos.animateTo(target.toDouble(),
        duration: sharedAxisTabDuration + _extraPerStep * (steps - 1),
        curve: sharedAxisTabCurve);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final slot = constraints.maxWidth / AppNavBar.items.length;
      return Stack(children: [
        NavigationBar(
          height: _barHeight,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
          selectedIndex: widget.selectedIndex,
          onDestinationSelected: widget.onSelected,
          destinations: [
            for (final item in AppNavBar.items)
              NavigationDestination(
                // Cùng một icon ở hai trạng thái: viên phủ lên trên mới là chỉ báo.
                icon: Icon(item.icon, color: AppColors.inkMuted, size: 25),
                selectedIcon:
                    Icon(item.icon, color: AppColors.inkMuted, size: 25),
                label: item.label,
              ),
          ],
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: AnimatedBuilder(
                animation: _pos,
                builder: (context, _) => CustomSingleChildLayout(
                  delegate: _PillLayout(
                      centerX: (_pos.value + .5) * slot, inset: _pillInset),
                  child: _Pill(position: _pos.value, last: _last),
                ),
              ),
            ),
          ),
        ),
      ]);
    });
  }
}

/// Đặt viên quanh tâm [centerX], kẹp trong thanh để viên ở hai đầu không tràn ra ngoài.
class _PillLayout extends SingleChildLayoutDelegate {
  const _PillLayout({required this.centerX, required this.inset});
  final double centerX, inset;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(Size(
          (constraints.maxWidth - 2 * inset).clamp(0.0, 150.0), _pillHeight));

  @override
  Offset getPositionForChild(Size size, Size child) {
    final maxLeft = size.width - inset - child.width;
    final left = (centerX - child.width / 2).clamp(inset, maxLeft);
    return Offset(left, (size.height - child.height) / 2);
  }

  @override
  bool shouldRelayout(_PillLayout old) =>
      old.centerX != centerX || old.inset != inset;
}

class _Pill extends StatelessWidget {
  const _Pill({required this.position, required this.last});
  final double position;
  final int last;

  @override
  Widget build(BuildContext context) {
    final p = position.clamp(0.0, last.toDouble());
    final nearest = p.round();
    // 0 ở đúng điểm giữa hai tab, 1 khi đã cách điểm giữa từ _iconSwapBand trở lên
    final swap = (((p - p.floor()) - .5).abs() / _iconSwapBand).clamp(0.0, 1.0);
    final reach = ((p - nearest).abs() / _labelReach).clamp(0.0, 1.0);
    final open = Curves.easeOutCubic.transform(1 - reach);
    final label = AppNavBar.items[nearest].label;
    return Container(
      key: ValueKey('selected-nav-$label'),
      height: _pillHeight,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: _pillColor,
        borderRadius: BorderRadius.circular(_pillHeight / 2),
      ),
      // vừa chỗ thì giữ nguyên cỡ; thiếu chỗ (chữ hệ thống to) thì thu nhỏ cả cụm, không cắt chữ
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          // Luôn chỉ một icon (của tab gần nhất). Qua điểm giữa hai tab thì icon co nhẹ,
          // mờ đi rồi đổi, không chồng hai icon lên nhau.
          Opacity(
            opacity: .35 + .65 * swap,
            child: Transform.scale(
              scale: .85 + .15 * swap,
              child:
                  Icon(AppNavBar.items[nearest].icon, color: _active, size: 24),
            ),
          ),
          ClipRect(
            child: Align(
              alignment: Alignment.centerLeft,
              widthFactor: open,
              child: Opacity(
                opacity: open,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(label,
                      key: ValueKey('selected-nav-label-$label'),
                      maxLines: 1,
                      softWrap: false,
                      style: const TextStyle(
                          color: _active,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
