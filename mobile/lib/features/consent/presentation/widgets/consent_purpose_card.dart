import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/consent.dart';
import 'consent_texts.dart';

/// Một mục đích: tiêu đề, mô tả, công tắc. Mỗi mục đích một thẻ riêng (không gộp).
class ConsentPurposeCard extends StatelessWidget {
  const ConsentPurposeCard({
    super.key,
    required this.purpose,
    required this.value,
    required this.onChanged,
  });

  final ConsentPurpose purpose;
  final bool value;

  /// `null` thì công tắc bị khóa (đang gửi request).
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final text = consentTexts[purpose]!;
    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: AppSpacing.sm,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(text.title, style: AppTextStyles.bodyStrong),
                      Text(
                        purpose.isRequired ? 'Bắt buộc' : 'Tùy chọn',
                        style: AppTextStyles.captionStrong.copyWith(
                          color: purpose.isRequired ? AppColors.brand : AppColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(text.description, style: AppTextStyles.caption),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Switch(
              key: Key('consent-switch-${purpose.apiValue}'),
              value: value,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}
