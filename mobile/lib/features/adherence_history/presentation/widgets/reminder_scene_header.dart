import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/app_assets.dart';
import '../utils/reminder_palette.dart';
import 'history_motion.dart';

/// Compact Reminder header from the Figma frames; it is intentionally separate
/// from Home's landscape banner.
class ReminderSceneHeader extends StatelessWidget {
  const ReminderSceneHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.now,
    this.monthMode = false,
    this.mascot = AppAssets.mascotHappy,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final DateTime? now;
  final bool monthMode;

  /// Dumi's pose for today's progress (day mode only).
  final String mascot;

  @override
  Widget build(BuildContext context) {
    final current = now ?? DateTime.now();
    return SliverPersistentHeader(
      pinned: !monthMode,
      delegate: _ReminderHeaderDelegate(
        title: title,
        subtitle: subtitle,
        leading: leading,
        trailing: trailing,
        background: ReminderPalette.headerFor(current),
        monthMode: monthMode,
        mascot: mascot,
      ),
    );
  }
}

class _ReminderHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _ReminderHeaderDelegate({
    required this.title,
    required this.subtitle,
    required this.leading,
    required this.trailing,
    required this.background,
    required this.monthMode,
    required this.mascot,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final Color background;
  final bool monthMode;
  final String mascot;

  static const _toolbarHeight = 48.0;
  static const _dateRowHeight = 42.0;

  @override
  double get minExtent => monthMode ? 54 : _toolbarHeight;

  @override
  double get maxExtent => monthMode ? 54 : _toolbarHeight + _dateRowHeight;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    if (!monthMode) return _dayHeader(context, shrinkOffset);
    final titleWidget = Text(
      title,
      key: const Key('history-title'),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: AppTextStyles.bodyStrong.copyWith(fontSize: 16),
    );
    return Material(
      key: const Key('reminder-scene-header'),
      color: background,
      child: Column(
        children: [
          SizedBox(
            height: _toolbarHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  if (monthMode && leading != null) ...[
                    leading!,
                    const SizedBox(width: 8),
                  ],
                  Expanded(child: titleWidget),
                  if (monthMode && trailing != null) ...[
                    const SizedBox(width: 8),
                    trailing!,
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Day header: one layout whose title size and date line follow the scroll continuously
  /// (no jump between an expanded and a collapsed variant).
  Widget _dayHeader(BuildContext context, double shrinkOffset) {
    final t = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    final title = Text(
      this.title,
      key: const Key('history-title'),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTextStyles.heading.copyWith(fontSize: lerpDouble(24, 18, t)),
    );
    // The sun icon is dropped when the column gets too narrow (large text), so the date line
    // ellipsizes instead of overflowing.
    final dateText = Text(subtitle ?? '',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.captionStrong
            .copyWith(color: ReminderPalette.morningInk, fontSize: 12));
    final date = LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth < 64
          ? dateText
          : Row(children: [
              const Icon(Icons.wb_sunny_outlined,
                  size: 16, color: ReminderPalette.morningInk),
              const SizedBox(width: 5),
              Expanded(child: dateText),
            ]),
    );
    final mascotSize = lerpDouble(44, 32, t)!;
    return Material(
      key: const Key('reminder-scene-header'),
      color: background,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              background,
              Color.lerp(ReminderPalette.canvas, background, t)!,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRect(
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      heightFactor: 1 - t,
                      child: Opacity(
                          key: const Key('reminder-header-date'),
                          opacity: (1 - t * 2).clamp(0.0, 1.0),
                          child: date),
                    ),
                  ),
                  Flexible(child: title),
                ],
              ),
            ),
            Semantics(
              image: true,
              label: 'Dumi, linh vật DrugTime',
              child: ExcludeSemantics(
                child: AnimatedSwitcher(
                  duration: HistoryMotion.enabled(context)
                      ? HistoryMotion.entrance
                      : Duration.zero,
                  child: Image.asset(mascot,
                      key: ValueKey(mascot),
                      width: mascotSize,
                      height: mascotSize,
                      fit: BoxFit.contain),
                ),
              ),
            ),
            if (trailing != null) trailing!,
          ]),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _ReminderHeaderDelegate oldDelegate) =>
      mascot != oldDelegate.mascot ||
      title != oldDelegate.title ||
      subtitle != oldDelegate.subtitle ||
      leading != oldDelegate.leading ||
      trailing != oldDelegate.trailing ||
      background != oldDelegate.background ||
      monthMode != oldDelegate.monthMode;
}
