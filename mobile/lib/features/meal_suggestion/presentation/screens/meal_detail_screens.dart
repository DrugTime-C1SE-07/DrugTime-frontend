import 'package:flutter/material.dart';

import '../../domain/entities/meal_suggestion.dart';
import '../state/meal_plan_controller.dart';
import '../widgets/dish_hero.dart';
import '../widgets/ingredients_sheet.dart';
import '../widgets/meal_greeting.dart';
import '../widgets/meal_tabs.dart';
import '../widgets/meal_ui.dart';
import '../widgets/meal_widgets.dart';
import '../../../../core/motion/shared_axis.dart';

/// Chi tiết món (S05-D1, D1c, D2): ảnh bo góc có lề (Hero, giãn khi kéo quá, parallax),
/// tab Lợi ích / Nên tránh, thanh đáy Nguyên liệu + Chọn món (AC11).
///
/// Pop với `true` khi người dùng bấm nút chọn/bỏ chọn (màn kết quả xử lý và chạy ăn mừng).
class MealDetailScreen extends StatefulWidget {
  const MealDetailScreen({
    super.key,
    required this.plan,
    required this.meal,
    required this.result,
    required this.index,
    required this.chosen,
  });

  final MealPlanController plan;
  final MealType meal;
  final MealSuggestionResult result;
  final int index;
  final bool chosen;

  static Route<bool> route({
    required MealPlanController plan,
    required MealType meal,
    required MealSuggestionResult result,
    required int index,
    required bool chosen,
  }) =>
      sharedAxisRoute<bool>(
          builder: (_) => MealDetailScreen(
              plan: plan,
              meal: meal,
              result: result,
              index: index,
              chosen: chosen));

  @override
  State<MealDetailScreen> createState() => _MealDetailScreenState();
}

class _MealDetailScreenState extends State<MealDetailScreen> {
  int _tab = 0;

  MealDish get dish => widget.result.dishes[widget.index];

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final d = dish;
    final hasRecipe = d.ingredients.isNotEmpty;
    final chosen = widget.chosen;
    return MealTypography(
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(children: [
          ListenableBuilder(
            listenable: widget.plan, // ảnh pending → ready
            builder: (context, _) => CustomScrollView(
              physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                SliverAppBar(
                  expandedHeight: 300 + mq.padding.top,
                  stretch: true,
                  backgroundColor: Colors.white,
                  surfaceTintColor: Colors.white,
                  automaticallyImplyLeading: false,
                  flexibleSpace: FlexibleSpaceBar(
                    stretchModes: const [StretchMode.zoomBackground],
                    collapseMode: CollapseMode.parallax,
                    // ảnh bo góc, có lề, không tràn viền (góp ý bản mẫu vòng 1)
                    background: Padding(
                      padding:
                          EdgeInsets.fromLTRB(12, mq.padding.top + 8, 12, 4),
                      child: DecoratedBox(
                        key: const ValueKey('detail-image-frame'),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: const [
                            BoxShadow(
                                color: Color(0x22000000),
                                blurRadius: 18,
                                offset: Offset(0, 8))
                          ],
                        ),
                        child: MealDishHero(
                          tag: mealDishHeroTag(
                              widget.result.suggestionId, widget.index),
                          dish: d,
                          plan: widget.plan,
                          radius: 28,
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                        20, 16, 20, 120 + mq.padding.bottom),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          StaggerIn(
                            index: 0,
                            child: Text(d.name,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    color: MealColors.ink,
                                    height: 1.25)),
                          ),
                          const SizedBox(height: 12),
                          StaggerIn(
                            index: 1,
                            child: Wrap(
                                alignment: WrapAlignment.center,
                                runSpacing: 6,
                                children: [
                                  _Meta(
                                      icon: MealGreeting.icon(widget.meal),
                                      color: MealGreeting.tint(widget.meal),
                                      text: widget.meal.tabLabel),
                                  _Meta(
                                      icon: Icons.bolt_rounded,
                                      color: MealColors.danger,
                                      text: kcalLabel(d.kcalEstimate)),
                                  if (d.cookMinutes > 0)
                                    _Meta(
                                        icon: Icons.timer_rounded,
                                        color: MealColors.teal,
                                        text: 'Nấu ${d.cookMinutes} phút'),
                                ]),
                          ),
                          const SizedBox(height: 22),
                          if (!hasRecipe) ...[
                            StaggerIn(index: 2, child: _NoRecipe(d)),
                            const SizedBox(height: 18),
                          ],
                          StaggerIn(
                            index: 2,
                            child: MealPillTabs(
                              labels: const ['Lợi ích', 'Nên tránh'],
                              selected: _tab,
                              onChanged: (i) => setState(() => _tab = i),
                            ),
                          ),
                          const SizedBox(height: 18),
                          AnimatedSwitcher(
                            duration: MediaQuery.disableAnimationsOf(context)
                                ? Duration.zero
                                : const Duration(milliseconds: 280),
                            transitionBuilder: (c, a) =>
                                FadeTransition(opacity: a, child: c),
                            child: KeyedSubtree(
                              key: ValueKey(_tab),
                              child: _tab == 0
                                  ? _Benefits(d.benefits)
                                  : MealFoodCheckView(widget.result.foodCheck),
                            ),
                          ),
                          const SizedBox(height: 18),
                          MealDisclaimer(widget.result.disclaimer),
                        ]),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 24,
            top: mq.padding.top + 20,
            child: RoundIconButton(
              icon: Icons.arrow_back_ios_new_rounded,
              background: Colors.white,
              color: MealColors.ink,
              shadow: true,
              onTap: () => Navigator.of(context).pop(false),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + mq.padding.bottom),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: MealColors.line)),
              ),
              child: Row(children: [
                if (hasRecipe) ...[
                  Expanded(
                    flex: 4,
                    child: Pressable(
                      key: const ValueKey('open-ingredients'),
                      onTap: () => showIngredientsSheet(context,
                          plan: widget.plan,
                          dish: d,
                          disclaimer: widget.result.disclaimer),
                      child: Container(
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: const Color(0xFFCFE3DD), width: 1.6),
                        ),
                        child: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('Nguyên liệu',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: MealColors.brand)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  flex: 6,
                  child: Pressable(
                    key: const ValueKey('detail-choose'),
                    onTap: () => Navigator.of(context).pop(true),
                    child: Container(
                      height: 52,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: chosen ? MealColors.mint : MealColors.brand,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: chosen
                            ? null
                            : [
                                BoxShadow(
                                    color:
                                        MealColors.brand.withValues(alpha: .3),
                                    blurRadius: 14,
                                    offset: const Offset(0, 6))
                              ],
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.check_rounded,
                              color: chosen ? MealColors.brand : Colors.white),
                          const SizedBox(width: 6),
                          Text(chosen ? 'Đã chọn' : 'Chọn món này',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: chosen
                                      ? MealColors.brand
                                      : Colors.white)),
                        ]),
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.color, required this.text});
  final IconData icon;
  final Color color;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 5),
          Text(text,
              style: const TextStyle(
                  fontSize: 15,
                  color: MealColors.ink2,
                  fontWeight: FontWeight.w600)),
        ]),
      );
}

class _NoRecipe extends StatelessWidget {
  const _NoRecipe(this.dish);
  final MealDish dish;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F6F4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFDCE8E3)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Thông tin món',
              style: TextStyle(
                  fontSize: 17,
                  color: MealColors.mintInk,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('${dish.dishType.label} · ${kcalLabel(dish.kcalEstimate)}',
              style: const TextStyle(fontSize: 15, color: MealColors.ink)),
          const SizedBox(height: 6),
          const Text('Chưa có công thức và định lượng cho món này',
              style: TextStyle(fontSize: 14, color: MealColors.ink2)),
        ]),
      );
}

class _Benefits extends StatelessWidget {
  const _Benefits(this.items);
  final List<MealBenefit> items;

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Căn cứ Dumi gợi ý',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: MealColors.ink)),
        const SizedBox(height: 8),
        for (var i = 0; i < items.length; i++)
          StaggerIn(
            index: i,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                border: i == items.length - 1
                    ? null
                    : const Border(bottom: BorderSide(color: MealColors.line)),
              ),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                IconTile(benefitAsset(items[i])),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(items[i].text,
                      style: const TextStyle(
                          fontSize: 16, height: 1.4, color: MealColors.ink)),
                ),
                // Nhãn từ hồ sơ (bệnh nền, dị ứng, hạn chế); không bao giờ là tên thuốc.
                if (items[i].label case final label?) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: MealColors.mint,
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(label,
                        key: const ValueKey('benefit-label'),
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: MealColors.mintInk)),
                  ),
                ],
              ]),
            ),
          ),
      ]);
}
