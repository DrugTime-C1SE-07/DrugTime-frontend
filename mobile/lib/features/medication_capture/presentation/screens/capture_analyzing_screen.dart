import 'package:flutter/material.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/app_assets.dart';

/// S07b, frame 51:5366. Progress must come from a real caller, never a timer.
class CaptureAnalyzingScreen extends StatelessWidget {
  const CaptureAnalyzingScreen(
      {super.key, required this.onCancel, this.step = 1, this.progress});
  final VoidCallback onCancel;
  final int step;
  final double? progress;
  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: AppColors.cameraScrim,
      body: SafeArea(
          child: Center(
              child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: AppShadows.cardElevation),
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            Container(
                                width: 80,
                                height: 80,
                                padding: const EdgeInsets.all(12),
                                decoration: const BoxDecoration(
                                    color: AppColors.brandTint,
                                    shape: BoxShape.circle),
                                child: Image.asset(AppAssets.mascotThinking,
                                    excludeFromSemantics: true)),
                            const SizedBox(height: 24),
                            Semantics(
                                header: true,
                                child: const Text('Đang đọc thông tin…',
                                    style: AppTextStyles.heading,
                                    textAlign: TextAlign.center)),
                            const SizedBox(height: 24),
                            for (final (i, label) in [
                              'Chuẩn bị ảnh',
                              'Đọc chữ trên bao bì',
                              'Tìm trong danh mục'
                            ].indexed)
                              Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: Row(children: [
                                    if (i < step)
                                      const Icon(Icons.check_circle_outline,
                                          size: 20, color: AppColors.brand)
                                    else if (i == step)
                                      SizedBox.square(
                                          dimension: 20,
                                          child: MediaQuery.disableAnimationsOf(
                                                  context)
                                              ? const Icon(Icons.more_horiz,
                                                  size: 20,
                                                  color: AppColors.brand)
                                              : const CircularProgressIndicator(
                                                  strokeWidth: 2))
                                    else
                                      const Icon(Icons.radio_button_unchecked,
                                          size: 20,
                                          color: AppColors.inkDisabled),
                                    const SizedBox(width: 12),
                                    Expanded(
                                        child: Text(label,
                                            style: AppTextStyles.caption
                                                .copyWith(
                                                    color: i <= step
                                                        ? AppColors.ink
                                                        : AppColors.inkMuted)))
                                  ])),
                            const SizedBox(height: 8),
                            Semantics(
                                label: 'Đang phân tích bao bì',
                                liveRegion: true,
                                child: LinearProgressIndicator(
                                    value: progress?.clamp(0, 1),
                                    minHeight: 5,
                                    borderRadius: BorderRadius.circular(4))),
                            if (progress != null)
                              Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                      '${(progress!.clamp(0, 1) * 100).round()}%',
                                      style: AppTextStyles.caption)),
                            const SizedBox(height: 16),
                            TextButton(
                                onPressed: onCancel, child: const Text('Hủy')),
                          ])))))));
}
