import 'package:flutter/material.dart';
import '../../../../app/theme/app_theme.dart';
import '../state/profile_controller.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, this.size = 84, this.ringed = true});
  final double size;

  /// false: hình tròn brand đặc, chữ 17/700 như avatar thẻ Figma S08.
  final bool ringed;
  @override
  Widget build(BuildContext context) {
    final c = ProfileScope.of(context);
    final words = (c.profile?.fullName ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    final initials = words.isEmpty
        ? '?'
        : words.reversed
            .take(2)
            .toList()
            .reversed
            .map((w) => String.fromCharCode(w.runes.first))
            .join()
            .toUpperCase();
    return Semantics(
        label: 'Ảnh đại diện',
        image: true,
        child: SizedBox(
          width: size,
          height: size,
          child: DecoratedBox(
            decoration: BoxDecoration(
                color: ringed ? AppColors.brandTint : AppColors.brand,
                shape: BoxShape.circle),
            child: Padding(
              padding: EdgeInsets.all(ringed ? 6 : 0),
              child: ClipOval(
                  child: c.avatar == null
                      ? ColoredBox(
                          color: AppColors.brand,
                          child: Center(
                              child: Text(initials,
                                  textScaler: TextScaler.noScaling,
                                  style: ringed
                                      ? TextStyle(
                                          fontSize: (size - 12) / 3,
                                          color: AppColors.onBrand)
                                      : _solidInitials)))
                      : Image.asset(c.avatar!,
                          fit: BoxFit.cover, excludeFromSemantics: true)),
            ),
          ),
        ));
  }
}

const _solidInitials = TextStyle(
  color: AppColors.onBrand,
  fontSize: 17,
  fontWeight: FontWeight.w700,
  height: 26 / 17,
);
