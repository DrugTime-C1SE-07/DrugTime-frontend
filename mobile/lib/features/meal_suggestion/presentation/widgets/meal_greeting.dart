import 'package:flutter/material.dart';

import '../../domain/entities/meal_suggestion.dart';
import 'meal_ui.dart';

/// Lời chào "{Bữa} nay ăn gì, {tên}?" (góp ý bản mẫu vòng 5, AC11b).
///
/// Chỉ chữ bữa (kèm icon buổi) đổi, trượt ngang cùng chiều thanh tab; phần chữ cố định đứng yên,
/// chỉ dịch ngang mượt theo bề rộng chữ bữa; dòng phụ mờ chéo tại chỗ.
class MealGreeting extends StatelessWidget {
  const MealGreeting({
    super.key,
    required this.meal,
    required this.dir,
    required this.who,
    this.caregiverMode = false,
  });

  final MealType meal;

  /// 1: sang phải (bữa sau), -1: sang trái.
  final int dir;
  final String who;
  final bool caregiverMode;

  static const _dur = Duration(milliseconds: 280);
  static const _title = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: MealColors.ink,
    height: 1.25,
  );

  static IconData icon(MealType m) => switch (m) {
        MealType.sang => Icons.wb_twilight_rounded,
        MealType.trua => Icons.wb_sunny_rounded,
        MealType.toi => Icons.nightlight_round,
      };

  static Color tint(MealType m) => switch (m) {
        MealType.sang => const Color(0xFFF59A23),
        MealType.trua => MealColors.caution,
        MealType.toi => MealColors.violet,
      };

  Widget _slide(Widget child, Animation<double> a, Key current) {
    final incoming = child.key == current;
    final from = Offset((incoming ? 1 : -1) * dir * .45, 0);
    return ClipRect(
      child: FadeTransition(
        opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
        child: SlideTransition(
          position: Tween(begin: from, end: Offset.zero)
              .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
    );
  }

  static Widget _leftStack(Widget? cur, List<Widget> prev) => Stack(
        alignment: Alignment.centerLeft,
        children: [...prev, if (cur != null) cur],
      );

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    const d = _dur;
    final key = ValueKey(meal);
    final word = Row(
      key: key,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon(meal), size: 20, color: tint(meal)),
        const SizedBox(width: 5),
        Text(meal.tabLabel, style: _title.copyWith(color: MealColors.brand)),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Giảm chuyển động: đổi tức thì (AnimatedSize với thời lượng 0 lỗi layout).
            if (still)
              word
            else
              AnimatedSize(
                duration: d,
                curve: Curves.easeOutCubic,
                alignment: Alignment.centerLeft,
                child: AnimatedSwitcher(
                  duration: d,
                  transitionBuilder: (c, a) => _slide(c, a, key),
                  layoutBuilder: _leftStack,
                  child: word,
                ),
              ),
            Text(
                caregiverMode ? ' nay ăn gì cho $who?' : ' nay ăn gì, $who?',
                key: const ValueKey('greeting-fixed'),
                style: _title),
          ],
        ),
        const SizedBox(height: 2),
        AnimatedSwitcher(
          duration: still ? Duration.zero : d,
          layoutBuilder: _leftStack,
          child: Text(
            'Gợi ý cho ${meal.mealLabel}',
            key: key,
            style: const TextStyle(fontSize: 15, color: MealColors.ink2),
          ),
        ),
      ],
    );
  }
}
