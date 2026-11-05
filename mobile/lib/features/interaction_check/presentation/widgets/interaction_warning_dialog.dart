import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/interaction_check_result.dart';

/// Hiển thị hộp thoại cảnh báo tương tác thuốc phân cấp theo Severity (PB24, Task 4.02).
///
/// Trả về `true` nếu người dùng quyết định tiếp tục lưu, hoặc `false`/`null` nếu quay lại chỉnh sửa.
Future<bool?> showInteractionWarningDialog(
  BuildContext context,
  InteractionCheckResult result,
) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => InteractionWarningDialog(result: result),
  );
}

class InteractionWarningDialog extends StatelessWidget {
  const InteractionWarningDialog({
    super.key,
    required this.result,
  });

  final InteractionCheckResult result;

  @override
  Widget build(BuildContext context) {
    final maxSev = result.maxSeverity;
    final isContraindicated = result.hasContraindication;

    final Color headerBg;
    final Color headerFg;
    final IconData headerIcon;
    final String headerTitle;

    switch (maxSev) {
      case 4:
        headerBg = AppColors.dangerBg;
        headerFg = AppColors.danger;
        headerIcon = Icons.cancel;
        headerTitle = 'CẢNH BÁO CHỐNG CHỈ ĐỊNH';
        break;
      case 3:
        headerBg = const Color(0xFFFFF7ED);
        headerFg = const Color(0xFFEA580C);
        headerIcon = Icons.warning_amber_rounded;
        headerTitle = 'CÂN NHẮC LỢI ÍCH / NGUY CƠ';
        break;
      case 2:
        headerBg = AppColors.cautionBg;
        headerFg = AppColors.caution;
        headerIcon = Icons.error_outline;
        headerTitle = 'CẦN THẬN TRỌNG PHỐI HỢP';
        break;
      default:
        headerBg = AppColors.infoBg;
        headerFg = AppColors.info;
        headerIcon = Icons.info_outline;
        headerTitle = 'CẦN THEO DÕI KHI DÙNG';
        break;
    }

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.page,
        vertical: AppSpacing.xl,
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Header cảnh báo phân màu theo Severity
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              color: headerBg,
              child: Row(
                children: [
                  Icon(headerIcon, color: headerFg, size: 28),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      headerTitle,
                      style: AppTextStyles.bodyStrong.copyWith(
                        color: headerFg,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 2. Nội dung chi tiết các cặp tương tác
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  AppSpacing.md,
                  AppSpacing.page,
                  AppSpacing.sm,
                ),
                children: [
                  Text(
                    'Phát hiện ${result.interactions.length} tương tác thuốc tiềm ẩn:',
                    style: AppTextStyles.bodyStrong,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  for (final item in result.interactions) ...[
                    _InteractionItemCard(finding: item),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // Cảnh báo bổ sung nếu có thuốc thiếu dữ liệu hoạt chất trong cùng đơn
                  if (result.insufficientDataMedications.isNotEmpty) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: AppSpacing.md),
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.cautionBg,
                        borderRadius: BorderRadius.circular(AppRadius.field),
                        border: Border.all(color: AppColors.caution.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.help_outline, color: AppColors.caution, size: 20),
                              const SizedBox(width: AppSpacing.xs),
                              Expanded(
                                child: Text(
                                  'Thuốc chưa đủ dữ liệu hoạt chất để đối soát:',
                                  style: AppTextStyles.bodyStrong.copyWith(color: AppColors.caution),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          for (final med in result.insufficientDataMedications)
                            Padding(
                              padding: const EdgeInsets.only(top: AppSpacing.xs),
                              child: Text(
                                '• ${med.medicationName} (${med.reason})',
                                style: AppTextStyles.caption.copyWith(color: AppColors.ink),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],

                  // Cảnh báo NFR03 Disclaimer bắt buộc
                  Container(
                    margin: const EdgeInsets.only(top: AppSpacing.xs),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(AppRadius.field),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.health_and_safety_outlined,
                          size: 20,
                          color: AppColors.inkMuted,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            result.disclaimer,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.inkMuted,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // 3. Nút hành động với Wrap chống tràn giao diện
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Quay lại chỉnh sửa'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: isContraindicated
                          ? AppColors.danger
                          : AppColors.brand,
                    ),
                    child: Text(
                      isContraindicated
                          ? 'Xác nhận & Tiếp tục'
                          : 'Đã hiểu & Tiếp tục',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InteractionItemCard extends StatelessWidget {
  const _InteractionItemCard({required this.finding});

  final InteractionFinding finding;

  @override
  Widget build(BuildContext context) {
    final (badgeColor, badgeText) = switch (finding.severityLevel) {
      4 => (AppColors.danger, 'Mức 4 · Chống chỉ định'),
      3 => (const Color(0xFFEA580C), 'Mức 3 · Nghiêm trọng'),
      2 => (AppColors.caution, 'Mức 2 · Cần thận trọng'),
      _ => (AppColors.info, 'Mức 1 · Theo dõi'),
    };

    final medA = finding.medicationAName ?? finding.ingredientAName;
    final medB = finding.medicationBName ?? finding.ingredientBName;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.field),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badgeText,
                  style: AppTextStyles.caption.copyWith(
                    color: badgeColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '$medA  ↔  $medB',
            style: AppTextStyles.bodyStrong,
          ),
          Text(
            'Hoạt chất: ${finding.ingredientAName} + ${finding.ingredientBName}',
            style: AppTextStyles.caption.copyWith(color: AppColors.inkMuted),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (finding.description.isNotEmpty) ...[
            Text(
              finding.description,
              style: AppTextStyles.body,
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          if (finding.warningMessage.isNotEmpty &&
              finding.warningMessage != finding.description) ...[
            Text(
              finding.warningMessage,
              style: AppTextStyles.bodyStrong.copyWith(color: badgeColor),
            ),
          ],
          if (finding.source.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Nguồn: ${finding.source}',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.inkDisabled,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Hiển thị hộp thoại cảnh báo khi thuốc chưa đủ dữ liệu hoạt chất để đối soát (PB24, Task 4.02).
Future<bool?> showInsufficientDataDialog(
  BuildContext context,
  InteractionCheckResult result,
) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => InsufficientDataDialog(result: result),
  );
}

class InsufficientDataDialog extends StatelessWidget {
  const InsufficientDataDialog({super.key, required this.result});

  final InteractionCheckResult result;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.page,
        vertical: AppSpacing.xl,
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              color: AppColors.cautionBg,
              child: Row(
                children: [
                  const Icon(Icons.help_outline, color: AppColors.caution, size: 28),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'THIẾU DỮ LIỆU ĐỐI SOÁT TƯƠNG TÁC',
                      style: AppTextStyles.bodyStrong.copyWith(
                        color: AppColors.caution,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  const Text(
                    'Thuốc sau chưa có đầy đủ thông tin hoạt chất trong danh mục dược thư để đối soát tương tác:',
                    style: AppTextStyles.body,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  for (final item in result.insufficientDataMedications)
                    Container(
                      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.field),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.medication_outlined, size: 20, color: AppColors.inkMuted),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.medicationName, style: AppTextStyles.bodyStrong),
                                Text(item.reason, style: AppTextStyles.caption.copyWith(color: AppColors.inkMuted)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(AppRadius.field),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline, size: 16, color: AppColors.inkMuted),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            result.disclaimer,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.inkMuted,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Quay lại chỉnh sửa'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: FilledButton.styleFrom(backgroundColor: AppColors.brand),
                    child: const Text('Vẫn tiếp tục lưu'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hiển thị hộp thoại cảnh báo khi gặp sự cố mạng hoặc lỗi API khi kiểm tra tương tác.
Future<bool?> showInteractionNetworkErrorDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const InteractionNetworkErrorDialog(),
  );
}

class InteractionNetworkErrorDialog extends StatelessWidget {
  const InteractionNetworkErrorDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.page,
        vertical: AppSpacing.xl,
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              color: AppColors.cautionBg,
              child: Row(
                children: [
                  const Icon(Icons.wifi_off_rounded, color: AppColors.caution, size: 28),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'KHÔNG THỂ KIỂM TRA TƯƠNG TÁC',
                      style: AppTextStyles.bodyStrong.copyWith(
                        color: AppColors.caution,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  const Text(
                    'Không thể kết nối đến máy chủ để đối soát tương tác thuốc của người bệnh. '
                    'Việc lưu thuốc mà chưa được kiểm tra tương tác có thể tiềm ẩn rủi ro an toàn điều trị.',
                    style: AppTextStyles.body,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(AppRadius.field),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline, size: 16, color: AppColors.inkMuted),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            nfr03Disclaimer,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.inkMuted,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Quay lại'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: FilledButton.styleFrom(backgroundColor: AppColors.brand),
                    child: const Text('Vẫn tiếp tục lưu'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
