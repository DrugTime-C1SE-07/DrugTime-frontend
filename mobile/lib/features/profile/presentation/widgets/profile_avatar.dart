import 'package:flutter/material.dart';
import '../../../../app/theme/app_theme.dart';
import '../state/profile_controller.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, this.size = 84});
  final double size;
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
          child: ClipOval(
              child: c.avatar == null
                  ? ColoredBox(
                      color: AppColors.brand,
                      child: Center(
                          child: Text(initials,
                              textScaler: TextScaler.noScaling,
                              style: TextStyle(
                                  fontSize: size / 3,
                                  color: AppColors.onBrand))))
                  : Image.asset(c.avatar!,
                      fit: BoxFit.cover, excludeFromSemantics: true)),
        ));
  }
}
