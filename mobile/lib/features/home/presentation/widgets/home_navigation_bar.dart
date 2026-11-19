import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../app/app_shell.dart';
import '../../../../app/theme/app_theme.dart';

class HomeNavigationBar extends StatelessWidget {
  const HomeNavigationBar({super.key, required this.onSelected});

  final ValueChanged<AppTab> onSelected;

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        bottom: false,
        minimum: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          _bottomSpacing(context),
        ),
        child: Material(
          color: Colors.white,
          elevation: 4,
          shadowColor: const Color(0x33013D39),
          borderRadius: BorderRadius.circular(18),
          child: Row(
            children: [
              for (final (tab, label, glyph) in const [
                (AppTab.home, 'Trang chủ', 'house-filled'),
                (AppTab.medications, 'Thuốc', 'pill-outline'),
                (AppTab.reminders, 'Lịch nhắc', 'calendar-clock-outline'),
                (AppTab.profile, 'Hồ sơ', 'user-outline'),
              ])
                Expanded(
                  child: Semantics(
                    selected: tab == AppTab.home,
                    button: true,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => onSelected(tab),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 58),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 44,
                              height: 28,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: tab == AppTab.home
                                    ? const Color(0xFFD5EBFA)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: SvgPicture.asset(
                                'assets/icons/navigation/$glyph.svg',
                                width: 24,
                                height: 24,
                                excludeFromSemantics: true,
                                colorFilter: ColorFilter.mode(
                                  tab == AppTab.home
                                      ? const Color(0xFF005982)
                                      : AppColors.inkMuted,
                                  BlendMode.srcIn,
                                ),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(label,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'WelcomeInter',
                                  fontSize: 12,
                                  fontWeight: tab == AppTab.home
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                  color: tab == AppTab.home
                                      ? const Color(0xFF005982)
                                      : AppColors.inkMuted,
                                )),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );

  double _bottomSpacing(BuildContext context) {
    final inset = MediaQuery.viewPaddingOf(context).bottom;
    // The iOS home indicator occupies the bottom of its 34 dp inset.
    // Use the Figma gap there and keep the full inset on other platforms.
    if (Theme.of(context).platform == TargetPlatform.iOS && inset == 34) {
      return 20;
    }
    return inset.clamp(8.0, double.infinity).toDouble();
  }
}
