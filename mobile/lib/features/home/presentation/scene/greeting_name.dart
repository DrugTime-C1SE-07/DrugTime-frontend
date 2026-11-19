import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Given name in Vietnamese order: the last word of the full name ("Nguyễn Quang Bảo" →
/// "Bảo"). Extra spaces are ignored; null or blank gives null.
String? givenName(String? fullName) {
  final words = (fullName ?? '').trim().split(RegExp(r'\s+'));
  final last = words.isEmpty ? '' : words.last;
  return last.isEmpty ? null : last;
}

/// "Chào buổi tối, Bảo"; without a name just the greeting.
String greetingLine(String greeting, String? fullName) {
  final name = givenName(fullName);
  return name == null ? greeting : '$greeting, $name';
}

/// Greeting on one line under the sky: moon/sun icon then "Chào buổi tối, Bảo" in large bold
/// type with a soft shadow so it reads on every sky colour. Never wraps; a long name is cut
/// with "…" instead of pushing into the bell button.
class GreetingTitle extends StatelessWidget {
  const GreetingTitle(this.text,
      {super.key, required this.ink, required this.night, this.fontSize = 26});

  final String text;

  /// Text colour that reads on the current sky (white at night, near-black by day).
  final Color ink;
  final bool night;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: ink,
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      letterSpacing: -.4,
      height: 1.2,
      shadows: [
        Shadow(
          color: (night ? const Color(0xFF0B0F2A) : Colors.white)
              .withValues(alpha: .55),
          blurRadius: 10,
        ),
      ],
    );
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: MediaQuery.maybeDisableAnimationsOf(context) ?? false
          ? Duration.zero
          : const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: math.min(1, t * 1.4),
        child:
            Transform.translate(offset: Offset(0, (1 - t) * 6), child: child),
      ),
      child: Row(children: [
        Icon(night ? LucideIcons.moon : LucideIcons.sun,
            size: fontSize * .85, color: ink),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            key: const Key('home-greeting'),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
      ]),
    );
  }
}
