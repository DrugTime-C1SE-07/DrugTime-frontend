import 'package:flutter/material.dart';
import '../../app/theme/app_theme.dart';

/// Pixel-perfect iOS Home Indicator matching `homeindicator-slot` (21px height)
class HomeIndicator extends StatelessWidget {
  const HomeIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 21.0,
      color: Colors.transparent,
      alignment: Alignment.topCenter,
      padding: const EdgeInsets.only(top: 8.0),
      child: Container(
        width: 134.0,
        height: 5.0,
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(9999.0),
        ),
      ),
    );
  }
}
