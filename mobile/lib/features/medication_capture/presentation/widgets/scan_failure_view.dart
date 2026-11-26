import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_theme.dart';

/// Light-theme failure body aligned with Figma `S07-O3e · Không nhận diện được`.
class ScanFailureBody extends StatelessWidget {
  const ScanFailureBody({
    super.key,
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  key: const Key('scan-failure-illus'),
                  width: 160,
                  height: 160,
                  decoration: const BoxDecoration(
                    color: AppColors.cautionBg,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.scanLine,
                    color: AppColors.caution,
                    size: 64,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.heading.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 17,
                    color: AppColors.inkMuted,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Container(
                  key: const Key('scan-failure-tips'),
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    boxShadow: AppShadows.cardElevation,
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FailureTipRow(
                        badgeKey: Key('tip-badge-light'),
                        icon: LucideIcons.sun,
                        iconColor: AppColors.caution,
                        badgeColor: AppColors.cautionBg,
                        text: 'Đủ ánh sáng, không bị loá',
                      ),
                      SizedBox(height: AppSpacing.lg),
                      _FailureTipRow(
                        badgeKey: Key('tip-badge-frame'),
                        icon: LucideIcons.scanLine,
                        iconColor: AppColors.brand,
                        badgeColor: AppColors.brandTint,
                        text: 'Tên thuốc nằm trong khung',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _FailureTipRow extends StatelessWidget {
  const _FailureTipRow({
    required this.badgeKey,
    required this.icon,
    required this.iconColor,
    required this.badgeColor,
    required this.text,
  });

  final Key badgeKey;
  final IconData icon;
  final Color iconColor;
  final Color badgeColor;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            key: badgeKey,
            width: AppSizes.iconTile,
            height: AppSizes.iconTile,
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 22, color: iconColor),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.body.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      );
}

/// Pinned bottom action bar for `S07-O3e`.
///
/// When [isLockedFailure] is true (session revoked, 401 unauthorized, or cleanup failure),
/// hides retry/manual/gallery/retake and exposes only a safe exit/cleanup button.
class ScanFailureActions extends StatelessWidget {
  const ScanFailureActions({
    super.key = const Key('scan-failure-actions'),
    required this.isLockedFailure,
    required this.cleanupPending,
    required this.canRetry,
    required this.busy,
    required this.onRetry,
    required this.onManualEntry,
    required this.onChooseAnother,
    required this.onRetake,
    required this.onExit,
  });

  final bool isLockedFailure;
  final bool cleanupPending;
  final bool canRetry;
  final bool busy;
  final VoidCallback onRetry;
  final VoidCallback onManualEntry;
  final VoidCallback onChooseAnother;
  final VoidCallback onRetake;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, AppSpacing.md, 20, AppSpacing.lg),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: isLockedFailure
              ? [
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(AppSizes.primaryButton),
                    ),
                    onPressed: busy ? null : onExit,
                    child: Text(cleanupPending ? 'Thử dọn lại' : 'Đóng'),
                  ),
                ]
              : canRetry
                  ? [
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          minimumSize:
                              const Size.fromHeight(AppSizes.primaryButton),
                        ),
                        onPressed: busy ? null : onRetry,
                        icon: const Icon(LucideIcons.refreshCw),
                        label: const Text('Thử lại'),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize:
                              const Size.fromHeight(AppSizes.primaryButton),
                        ),
                        onPressed: busy ? null : onManualEntry,
                        child: const Text('Tìm thuốc thủ công'),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: busy ? null : onChooseAnother,
                              child: const Text(
                                'Chọn ảnh khác',
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          Expanded(
                            child: TextButton(
                              onPressed: busy ? null : onRetake,
                              child: const Text(
                                'Chụp lại',
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ]
                  : [
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize:
                              const Size.fromHeight(AppSizes.primaryButton),
                        ),
                        onPressed: busy ? null : onManualEntry,
                        child: const Text('Tìm thuốc thủ công'),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      TextButton(
                        onPressed: busy ? null : onChooseAnother,
                        child: const Text('Chọn ảnh khác'),
                      ),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          minimumSize:
                              const Size.fromHeight(AppSizes.primaryButton),
                        ),
                        onPressed: busy ? null : onRetake,
                        icon: const Icon(LucideIcons.scanLine),
                        label: const Text('Chụp lại'),
                      ),
                    ],
        ),
      );
}
