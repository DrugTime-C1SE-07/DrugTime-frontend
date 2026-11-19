import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/utils/app_assets.dart';
import '../../domain/entities/meal_suggestion.dart';

/// Màu riêng của tính năng gợi ý bữa ăn (theo prototype S05-D và màn chờ tím–mint).
abstract final class MealColors {
  static const canvas = Color(0xFFF6F6F3);
  static const brand = Color(0xFF00594F);
  static const brandInk = Color(0xFF0B4A43);
  static const mint = Color(0xFFE4F2EF);
  static const mintInk = Color(0xFF0E6B5F);
  static const ink = Color(0xFF1E2321);
  static const ink2 = Color(0xFF5E6663);
  static const line = Color(0xFFE6E8E6);
  static const chip = Color(0xFFF0F1EF);
  static const caution = Color(0xFFF5A524);
  static const danger = Color(0xFFD64545);

  static const galaxyTop = Color(0xFFEDE7FF);
  static const galaxyMid = Color(0xFFF4F1FF);
  static const galaxyBottom = Color(0xFFDDF3EE);
  static const violet = Color(0xFF8B6CF6);
  static const blue = Color(0xFF5B8DEF);
  static const teal = Color(0xFF2BB5A0);
  static const pink = Color(0xFFF29BD4);
  static const gold = Color(0xFFFFC928);
}

/// Ease-out có vượt nhẹ (nút, pop).
const kMealSpring = Cubic(.2, 1.35, .35, 1);

/// Font Inter đóng gói trong app (family đăng ký trong pubspec là `WelcomeInter`, 400–700).
const kMealFont = 'WelcomeInter';

/// Bọc các màn gợi ý bữa ăn để chữ dùng đúng Inter (phương án A: không đổi font toàn app).
class MealTypography extends StatelessWidget {
  const MealTypography({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        textTheme: theme.textTheme.apply(fontFamily: kMealFont),
        primaryTextTheme: theme.primaryTextTheme.apply(fontFamily: kMealFont),
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(fontFamily: kMealFont),
        child: child,
      ),
    );
  }
}

/// Icon nguyên liệu màu (SVG). Không dùng emoji.
class FoodIcon extends StatelessWidget {
  const FoodIcon(this.name, {super.key, this.size = 28});
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
        AppAssets.foodIcon(name),
        width: size,
        height: size,
        excludeFromSemantics: true,
      );
}

/// Ô bo góc chứa icon (dòng lợi ích, nguyên liệu).
class IconTile extends StatelessWidget {
  const IconTile(this.name, {super.key, this.size = 44});
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFFF4F5F3),
          borderRadius: BorderRadius.circular(size * .3),
        ),
        alignment: Alignment.center,
        child: FoodIcon(name, size: size * .62),
      );
}

/// Co nhẹ khi nhấn (phản hồi ≤ 100 ms).
class Pressable extends StatefulWidget {
  const Pressable(
      {super.key, required this.child, this.onTap, this.scale = .96});
  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.onTap == null ? null : (_) => _set(true),
        onTapCancel: () => _set(false),
        onTapUp: (_) => _set(false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? widget.scale : 1,
          duration: Duration(milliseconds: _down ? 70 : 220),
          curve: _down ? Curves.easeOut : kMealSpring,
          child: widget.child,
        ),
      );
}

/// Trượt lên + mờ dần theo thứ tự [index] (so le 60 ms). Giảm chuyển động: hiện ngay.
class StaggerIn extends StatelessWidget {
  const StaggerIn(
      {super.key, required this.index, required this.child, this.dy = 16});
  final int index;
  final Widget child;
  final double dy;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final total = 380 + index * 60;
    final start = index * 60 / total;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      builder: (context, v, child) {
        final t = Curves.easeOutCubic
            .transform(((v - start) / (1 - start)).clamp(0, 1));
        return Opacity(
          opacity: t,
          child: Transform.translate(
              offset: Offset(0, dy * (1 - t)), child: child),
        );
      },
      child: child,
    );
  }
}

/// Kiểu chip tag món theo từ khóa (nhãn do server trả nên không cố định); không khớp → icon chung.
({String icon, Color bg, Color fg}) tagStyle(String tag) {
  final t = tag.toLowerCase();
  if (t.contains('kcal')) {
    return (
      icon: 'flame',
      bg: const Color(0xFFFFF0E6),
      fg: const Color(0xFFB4501A)
    );
  }
  if (t.contains('muối') || t.contains('mặn')) {
    return (
      icon: 'salt',
      bg: const Color(0xFFE8F3FD),
      fg: const Color(0xFF2F6FA8)
    );
  }
  if (t.contains('đường') || t.contains('ngọt')) {
    return (
      icon: 'sugar',
      bg: const Color(0xFFFBEFF7),
      fg: const Color(0xFF9A3F78)
    );
  }
  if (t.contains('rau') || t.contains('chay') || t.contains('xơ')) {
    return (
      icon: 'leafy',
      bg: const Color(0xFFEAF6E6),
      fg: const Color(0xFF3B7A2F)
    );
  }
  if (t.contains('đạm') || t.contains('nạc') || t.contains('protein')) {
    return (
      icon: 'chicken',
      bg: const Color(0xFFFFF3E3),
      fg: const Color(0xFF9A5A1A)
    );
  }
  if (t.contains('dầu') || t.contains('béo')) {
    return (
      icon: 'oil',
      bg: const Color(0xFFF3F7E3),
      fg: const Color(0xFF5C7A1F)
    );
  }
  return (icon: 'generic', bg: MealColors.chip, fg: MealColors.ink2);
}

/// Chip tag: icon màu 16 px + chữ, nền theo nhóm.
class TagChip extends StatelessWidget {
  const TagChip(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final s = tagStyle(text);
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 4, 9, 4),
      decoration:
          BoxDecoration(color: s.bg, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        FoodIcon(s.icon, size: 16),
        const SizedBox(width: 4),
        Text(text,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: s.fg)),
      ]),
    );
  }
}

/// Hàng chip luôn một dòng thẳng; màn hẹp hoặc chữ lớn thì cả hàng co đều (AC11b).
class TagRow extends StatelessWidget {
  const TagRow(this.tags, {super.key});
  final List<String> tags;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: [for (final t in tags) TagChip(t)],
          ),
        ),
      );
}

/// Icon nguyên liệu theo từ khóa tên; không khớp thì icon theo nhóm (chính / gia vị).
String ingredientAsset(MealIngredient ingredient) {
  final name = ingredient.name.toLowerCase();
  const rules = <(List<String>, String)>[
    (['gạo', 'cơm', 'bún', 'phở', 'miến', 'mì', 'bánh', 'yến mạch'], 'rice'),
    (['gà', 'vịt'], 'chicken'),
    (['bò', 'heo', 'lợn', 'thịt'], 'meat'),
    (['cá', 'tôm', 'cua', 'mực'], 'fish'),
    (['trứng'], 'egg'),
    (['nấm'], 'mushroom'),
    (['đậu', 'đỗ', 'lạc', 'hạt', 'mè', 'vừng'], 'beans'),
    (['cà rốt', 'củ'], 'carrot'),
    (['cà chua'], 'tomato'),
    (['bí'], 'pumpkin'),
    (['tỏi', 'hành', 'gừng', 'sả'], 'garlic'),
    (['muối'], 'salt'),
    (['đường', 'mật ong'], 'sugar'),
    (['dầu', 'mỡ', 'bơ'], 'oil'),
    (
      ['nước mắm', 'nước tương', 'xì dầu', 'giấm', 'nước chấm', 'tương'],
      'sauce'
    ),
    (
      ['rau', 'cải', 'xà lách', 'mướp', 'ngò', 'húng', 'mồng tơi', 'cần'],
      'leafy'
    ),
  ];
  for (final (keys, icon) in rules) {
    if (keys.any(name.contains)) return icon;
  }
  return ingredient.isMain ? 'salad' : 'generic';
}

/// Icon cho một dòng lợi ích theo loại (bệnh nền, dị ứng, hạn chế, chung).
String benefitAsset(MealBenefit benefit) => switch (benefit.type) {
      'condition' => 'leafy',
      'allergy' => 'egg',
      'restriction' => 'salt',
      _ => 'salad',
    };

/// Icon giữ chỗ cho ảnh món theo loại món.
String dishTypeAsset(MealDishType type) => switch (type) {
      MealDishType.com => 'rice',
      MealDishType.monNuoc => 'sauce',
      MealDishType.monMan => 'meat',
      MealDishType.monXao => 'carrot',
      MealDishType.monHapLuoc => 'fish',
      MealDishType.chaoSup => 'pumpkin',
      MealDishType.salad => 'salad',
      MealDishType.khac => 'generic',
    };

/// Nút tròn (quay lại).
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.background = MealColors.mint,
    this.color = MealColors.brand,
    this.tooltip = 'Quay lại',
    this.shadow = false,
  });
  final IconData icon;
  final VoidCallback onTap;
  final Color background, color;
  final String tooltip;
  final bool shadow;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: tooltip,
        child: Pressable(
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: background,
              shape: BoxShape.circle,
              boxShadow: shadow
                  ? const [BoxShadow(color: Color(0x22000000), blurRadius: 10)]
                  : null,
            ),
            child: Icon(icon, size: 18, color: color),
          ),
        ),
      );
}
