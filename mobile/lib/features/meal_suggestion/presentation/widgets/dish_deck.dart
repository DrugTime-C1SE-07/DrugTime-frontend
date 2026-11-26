import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/entities/meal_suggestion.dart';
import '../state/meal_plan_controller.dart';
import 'choose_burst.dart';
import 'dish_hero.dart';
import 'meal_ui.dart';
import 'meal_widgets.dart';

/// Chồng thẻ món vuốt ngang của một bữa (AC7). Thẻ đầu có nhãn "Dumi chọn".
///
/// Mỗi deck tự giữ [PageController]: khi "Gợi ý khác" thay danh sách, deck cũ và mới cùng tồn tại
/// một khung hình; dùng chung controller sẽ gắn vào hai PageView (lỗi ở bản mẫu vòng 1).
class DishDeck extends StatefulWidget {
  const DishDeck({
    super.key,
    required this.meal,
    required this.result,
    required this.plan,
    required this.chosenIndex,
    required this.celebratingIndex,
    required this.onChoose,
    required this.onDetail,
  });

  final MealType meal;
  final MealSuggestionResult result;
  final MealPlanController plan;
  final int? chosenIndex, celebratingIndex;
  final ValueChanged<int> onChoose, onDetail;

  @override
  State<DishDeck> createState() => _DishDeckState();
}

class _DishDeckState extends State<DishDeck>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flip = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 650));

  late final PageController _pages = PageController(
    viewportFraction: .86,
    initialPage: widget.plan
        .stateOf(widget.meal)
        .pageIndex
        .clamp(0, math.max(0, widget.result.dishes.length - 1)),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _flip.value = 1;
    } else if (_flip.value == 0 && !_flip.isAnimating) {
      _flip.forward();
    }
  }

  @override
  void dispose() {
    _flip.dispose();
    _pages.dispose();
    super.dispose();
  }

  double _page(int fallback) =>
      _pages.hasClients && _pages.position.haveDimensions
          ? _pages.page ?? fallback.toDouble()
          : widget.plan.stateOf(widget.meal).pageIndex.toDouble();

  @override
  Widget build(BuildContext context) {
    final dishes = widget.result.dishes;
    final still = MediaQuery.disableAnimationsOf(context);
    return Column(children: [
      SizedBox(
        height: 452,
        child: PageView.builder(
          key: const ValueKey('dish-deck'),
          controller: _pages,
          itemCount: dishes.length,
          onPageChanged: (i) => widget.plan.setPage(widget.meal, i),
          itemBuilder: (context, i) => AnimatedBuilder(
            animation: Listenable.merge([_pages, _flip]),
            builder: (context, child) {
              final d = (_page(i) - i).clamp(-1.0, 1.0);
              // thẻ lật vào lần lượt khi có danh sách mới
              final flip = still
                  ? 1.0
                  : Curves.easeOutBack
                      .transform(((_flip.value - i * .12) / .7).clamp(0, 1));
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, .0012)
                  ..translateByDouble(0, 14 * d.abs(), 0, 1)
                  ..rotateZ(still ? 0 : -d * .035)
                  ..rotateY((1 - flip) * math.pi / 2)
                  ..scaleByDouble(1 - .07 * d.abs(), 1 - .07 * d.abs(), 1, 1),
                child: Opacity(
                    opacity: (1 - .35 * d.abs()).clamp(0, 1), child: child),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Align(
                alignment: Alignment.topCenter,
                child: DishCard(
                  key: ValueKey('dish-card-$i'),
                  meal: widget.meal,
                  result: widget.result,
                  index: i,
                  plan: widget.plan,
                  pages: _pages,
                  chosen: widget.chosenIndex == i,
                  celebrating: widget.celebratingIndex == i,
                  onChoose: () => widget.onChoose(i),
                  onDetail: () => widget.onDetail(i),
                ),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 4),
      AnimatedBuilder(
        animation: _pages,
        builder: (context, _) {
          final page = _page(0);
          return Semantics(
            label: 'Món ${page.round() + 1} trên ${dishes.length}',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < dishes.length; i++)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: 8 + 14 * (1 - (page - i).abs()).clamp(0, 1),
                    height: 8,
                    decoration: BoxDecoration(
                      color: Color.lerp(
                          MealColors.brand,
                          const Color(0xFFCBD2CF),
                          (page - i).abs().clamp(0, 1)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    ]);
  }
}

class DishCard extends StatelessWidget {
  const DishCard({
    super.key,
    required this.meal,
    required this.result,
    required this.index,
    required this.plan,
    required this.pages,
    required this.chosen,
    required this.celebrating,
    required this.onChoose,
    required this.onDetail,
  });

  final MealType meal;
  final MealSuggestionResult result;
  final int index;
  final MealPlanController plan;
  final PageController pages;
  final bool chosen, celebrating;
  final VoidCallback onChoose, onDetail;

  @override
  Widget build(BuildContext context) {
    final dish = result.dishes[index];
    return Pressable(
      scale: .985,
      onTap: onDetail,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
              color: chosen ? MealColors.teal : Colors.transparent, width: 2),
          boxShadow: [
            BoxShadow(
              color: (chosen ? MealColors.teal : const Color(0xFF1E2321))
                  .withValues(alpha: chosen ? .22 : .08),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ảnh co lại khi phần chữ cao hơn (chữ lớn), để thẻ không tràn
            Flexible(
              child: SizedBox(
                height: 212,
                child: Stack(fit: StackFit.expand, children: [
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: AnimatedBuilder(
                      animation: pages,
                      builder: (context, _) {
                        final page =
                            pages.hasClients && pages.position.haveDimensions
                                ? pages.page ?? 0
                                : index.toDouble();
                        final d = (page - index).clamp(-1.0, 1.0);
                        return MealDishHero(
                          tag: mealDishHeroTag(result.suggestionId, index),
                          dish: dish,
                          plan: plan,
                          radius: 22,
                          alignment: Alignment(d * .8, 0),
                        );
                      },
                    ),
                  ),
                  if (index == 0)
                    const Positioned(
                        left: 18,
                        top: 18,
                        child: _ShimmerBadge(text: 'Dumi chọn')),
                  if (chosen)
                    Positioned(
                      right: 18,
                      top: 18,
                      child: Container(
                        key: const ValueKey('chosen-badge'),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                            color: MealColors.teal,
                            borderRadius: BorderRadius.circular(30)),
                        child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_rounded,
                                  size: 16, color: Colors.white),
                              SizedBox(width: 4),
                              Text('Đã chọn',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700)),
                            ]),
                      ),
                    ),
                  if (celebrating) const Center(child: ChooseBurst()),
                ]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dish.name,
                      key: ValueKey('dish-name-$index'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      // Inter 20/700, giãn dòng đủ cho dấu tiếng Việt chồng (ặ, ẫ…)
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: MealColors.ink,
                        height: 1.3,
                        letterSpacing: -.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TagRow([...dish.tags, kcalLabel(dish.kcalEstimate)],
                        key: ValueKey('dish-tags-$index')),
                    const SizedBox(height: 10),
                    const Text('Gợi ý dựa trên danh sách thuốc của bạn',
                        style: TextStyle(fontSize: 14, color: MealColors.ink2)),
                    const SizedBox(height: 14),
                    Row(children: [
                      Expanded(
                        flex: 4,
                        child: Pressable(
                          key: ValueKey('detail-$index'),
                          onTap: onDetail,
                          child: Container(
                            height: 50,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: const Color(0xFFD5DCD9), width: 1.4),
                            ),
                            child: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('Chi tiết',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: MealColors.brand)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 6,
                        child: Semantics(
                          button: true,
                          selected: chosen,
                          child: Pressable(
                            key: ValueKey('choose-$index'),
                            onTap: onChoose,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 280),
                              height: 50,
                              alignment: Alignment.center,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                color:
                                    chosen ? MealColors.mint : MealColors.brand,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.check_rounded,
                                          color: chosen
                                              ? MealColors.brand
                                              : Colors.white,
                                          size: 20),
                                      const SizedBox(width: 6),
                                      Text(
                                        chosen ? 'Đã chọn' : 'Chọn món này',
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: chosen
                                                ? MealColors.brand
                                                : Colors.white),
                                      ),
                                    ]),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ]),
                  ]),
            ),
          ],
        ),
      ),
    );
  }
}

/// Nhãn "Dumi chọn" có ánh lấp lánh quét qua.
class _ShimmerBadge extends StatefulWidget {
  const _ShimmerBadge({required this.text});
  final String text;
  @override
  State<_ShimmerBadge> createState() => _ShimmerBadgeState();
}

class _ShimmerBadgeState extends State<_ShimmerBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2600));

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
        builder: (_, __) {
          final x = -1.5 + _c.value * 4;
          return Container(
            padding: const EdgeInsets.fromLTRB(10, 6, 14, 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              gradient: LinearGradient(
                begin: Alignment(x - .6, 0),
                end: Alignment(x + .6, 0),
                colors: const [Colors.white, Color(0xFFFFF6D6), Colors.white],
              ),
              boxShadow: const [
                BoxShadow(color: Color(0x22000000), blurRadius: 8)
              ],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Transform.rotate(
                angle: math.sin(_c.value * math.pi * 2) * .25,
                child: const Icon(Icons.auto_awesome_rounded,
                    size: 18, color: MealColors.caution),
              ),
              const SizedBox(width: 6),
              Text(widget.text,
                  style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: MealColors.brand)),
            ]),
          );
        },
      ));
}
