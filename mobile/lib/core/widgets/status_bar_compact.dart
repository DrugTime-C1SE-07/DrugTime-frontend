import 'package:flutter/material.dart';
import '../../app/theme/app_theme.dart';
import 'vector_icons.dart';

/// Pixel-perfect Status Bar (40px) matching `statusrow/compact`
class StatusBarCompact extends StatelessWidget {
  final String time;

  const StatusBarCompact({
    super.key,
    this.time = '09:41',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 40.0,
      color: AppColors.canvas,
      padding: const EdgeInsets.only(left: 20.0, right: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Time
          Text(
            time,
            style: AppTextStyles.figureSmall.copyWith(
              color: AppColors.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
          // Icon cluster
          const Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              StatusBarSignalIcon(size: 16.0),
              SizedBox(width: 5.0),
              StatusBarWifiIcon(size: 16.0),
              SizedBox(width: 5.0),
              StatusBarBatteryIcon(size: 18.0),
            ],
          ),
        ],
      ),
    );
  }
}
