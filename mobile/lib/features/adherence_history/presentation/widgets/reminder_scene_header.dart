import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../utils/reminder_palette.dart';

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
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final DateTime? now;
  final bool monthMode;

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
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final Color background;
  final bool monthMode;

  static const _toolbarHeight = 48.0;
  static const _dateRowHeight = 42.0;

  @override
  double get minExtent => monthMode ? 54 : _toolbarHeight;

  @override
  double get maxExtent => monthMode ? 54 : _toolbarHeight + _dateRowHeight;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final titleWidget = Text(
      title,
      key: const Key('history-title'),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: monthMode ? TextAlign.center : TextAlign.start,
      style: (monthMode ? AppTextStyles.bodyStrong : AppTextStyles.heading)
          .copyWith(
              fontSize: monthMode
                  ? 16
                  : shrinkOffset < 22
                      ? 24
                      : 18),
    );
    final expandedHeight = monthMode
        ? 0.0
        : math.max(0, maxExtent - minExtent - shrinkOffset).toDouble();
    if (!monthMode && expandedHeight > 20) {
      return Material(
        key: const Key('reminder-scene-header'),
        color: background,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [background, ReminderPalette.canvas],
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
                    Flexible(
                      child: Row(children: [
                        const Icon(Icons.wb_sunny_outlined,
                            size: 16, color: ReminderPalette.morningInk),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(subtitle ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.captionStrong.copyWith(
                                  color: ReminderPalette.morningInk,
                                  fontSize: 12)),
                        ),
                      ]),
                    ),
                    Flexible(child: titleWidget),
                  ],
                ),
              ),
              Semantics(
                image: true,
                label: 'Dumi, linh vật DrugTime',
                child: Image.asset('assets/icons/mascot-happy.png',
                    width: 44, height: 44, fit: BoxFit.contain),
              ),
              if (trailing != null) trailing!,
            ]),
          ),
        ),
      );
    }
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

  @override
  bool shouldRebuild(covariant _ReminderHeaderDelegate oldDelegate) =>
      title != oldDelegate.title ||
      subtitle != oldDelegate.subtitle ||
      leading != oldDelegate.leading ||
      trailing != oldDelegate.trailing ||
      background != oldDelegate.background ||
      monthMode != oldDelegate.monthMode;
}
