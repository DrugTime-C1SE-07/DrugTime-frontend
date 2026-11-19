import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../domain/entities/meal_suggestion.dart';
import '../state/meal_plan_controller.dart';
import 'meal_ui.dart';
import 'meal_widgets.dart';

/// Hero tag chung cho ảnh một món (đĩa màn chờ ↔ thẻ ↔ chi tiết).
String mealDishHeroTag(int suggestionId, int index) =>
    'meal-dish-$suggestionId-$index';

/// Ảnh món bay giữa các màn; bo góc nội suy trong lúc bay (tròn → thẻ → khung chi tiết).
class MealDishHero extends StatelessWidget {
  const MealDishHero({
    super.key,
    required this.tag,
    required this.dish,
    required this.plan,
    required this.radius,
    this.alignment = Alignment.center,
    this.showAttribution = true,
  });

  final String tag;
  final MealDish dish;
  final MealPlanController plan;
  final double radius;
  final Alignment alignment;
  final bool showAttribution;

  Widget _picture({required bool attribution}) => MealImageView(
        image: plan.imageOf(dish),
        loadBytes: plan.imageBytes,
        height: double.infinity,
        showAttribution: attribution,
        placeholderIcon: dishTypeAsset(dish.dishType),
        alignment: alignment,
      );

  @override
  Widget build(BuildContext context) => Hero(
        tag: tag,
        flightShuttleBuilder: (ctx, anim, dir, from, to) {
          double r(HeroFlightDirection _, BuildContext c) {
            final w = (c.widget as Hero).child;
            return w is _Radius ? w.radius : radius;
          }

          final fromR = r(dir, from);
          final toR = r(dir, to);
          return AnimatedBuilder(
            animation: anim,
            builder: (_, __) {
              final v = Curves.easeInOutCubic.transform(anim.value);
              final push = dir == HeroFlightDirection.push;
              final value = lerpDouble(
                  push ? fromR : toR, push ? toR : fromR, push ? v : 1 - v)!;
              return ClipRRect(
                borderRadius: BorderRadius.circular(value),
                child: _picture(attribution: false),
              );
            },
          );
        },
        child: _Radius(
          radius,
          ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: _picture(attribution: showAttribution),
          ),
        ),
      );
}

class _Radius extends StatelessWidget {
  const _Radius(this.radius, this.child);
  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
