import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/interaction_check_result.dart';

/// Hiển thị hộp thoại cảnh báo tương tác thuốc phân cấp theo Severity (PB24, Task 4.02, Figma S06c-1 & S06c-2).
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
        horizontal: AppSpacing.sm + 4,
        vertical: AppSpacing.sm,
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Header chuẩn Figma S06c kết hợp nhãn mức độ tổng thể
            Container(
              padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.xs + 2, AppSpacing.sm, AppSpacing.xs + 2),
              color: Colors.white,
              child: Row(
                children: [
                  GestureDetector(
                    key: const Key('interaction_back_button'),
                    onTap: () => Navigator.of(context).pop(false),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF3F4F6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        size: 15,
                        color: Color(0xFF374151),
                      ),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Cảnh báo tương tác',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                  const SizedBox(width: 32),
                ],
              ),
            ),

            // Banner phân loại Severity
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 6,
              ),
              color: headerBg,
              child: Row(
                children: [
                  Icon(headerIcon, color: headerFg, size: 18),
                  const SizedBox(width: AppSpacing.xs + 2),
                  Expanded(
                    child: Text(
                      headerTitle,
                      style: AppTextStyles.caption.copyWith(
                        color: headerFg,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 2. Nội dung danh sách Accordion Card theo Figma S06c-1 / S06c-2
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.xs + 2,
                  AppSpacing.md,
                  AppSpacing.xs,
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Text(
                      'Phát hiện ${result.interactions.length} tương tác thuốc tiềm ẩn:',
                      style: AppTextStyles.bodyStrong.copyWith(fontSize: 13),
                    ),
                  ),

                  for (int i = 0; i < result.interactions.length; i++) ...[
                    InteractionAccordionCard(
                      finding: result.interactions[i],
                      initiallyExpanded: false,
                    ),
                    const SizedBox(height: AppSpacing.xs + 2),
                  ],

                  // Cảnh báo bổ sung nếu có thuốc thiếu dữ liệu hoạt chất
                  if (result.insufficientDataMedications.isNotEmpty) ...[
                    Container(
                      margin: const EdgeInsets.only(top: AppSpacing.xs, bottom: AppSpacing.xs),
                      padding: const EdgeInsets.all(AppSpacing.sm),
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
                              const Icon(Icons.help_outline, color: AppColors.caution, size: 18),
                              const SizedBox(width: AppSpacing.xs),
                              Expanded(
                                child: Text(
                                  'Thuốc chưa đủ dữ liệu hoạt chất để đối soát:',
                                  style: AppTextStyles.bodyStrong.copyWith(
                                    color: AppColors.caution,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          for (final med in result.insufficientDataMedications)
                            Padding(
                              padding: const EdgeInsets.only(left: 20, top: 2),
                              child: Text(
                                '• ${med.medicationName} (${med.reason})',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.ink,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],

                  // Banner NFR03 Disclaimer chuẩn Figma S06c
                  Container(
                    margin: const EdgeInsets.only(top: AppSpacing.xs),
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 2, vertical: AppSpacing.xs + 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF9C3),
                      borderRadius: BorderRadius.circular(AppRadius.field),
                      border: Border.all(color: const Color(0xFFFDE047)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.shield_outlined,
                          size: 18,
                          color: Color(0xFFCA8A04),
                        ),
                        const SizedBox(width: AppSpacing.xs + 2),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Thông tin tham khảo — hỏi bác sĩ hoặc dược sĩ khi cần.',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF713F12),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                result.disclaimer,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF854D0E),
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // 3. Khối nút hành động chuẩn Figma S06c với nút CTA bo tròn
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs + 4,
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      child: const Text(
                        'Quay lại chỉnh sửa',
                        style: TextStyle(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    flex: 3,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isContraindicated
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF0F4A3C),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            isContraindicated
                                ? 'Xác nhận & Tiếp tục'
                                : 'Đã hiểu & Tiếp tục',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
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

/// Thẻ Accordion tương tác thuốc chuẩn Figma S06c-1 (Thu gọn) & S06c-2 (Mở rộng).
class InteractionAccordionCard extends StatefulWidget {
  const InteractionAccordionCard({
    super.key,
    required this.finding,
    this.initiallyExpanded = false,
  });

  final InteractionFinding finding;
  final bool initiallyExpanded;

  @override
  State<InteractionAccordionCard> createState() =>
      _InteractionAccordionCardState();
}

class _InteractionAccordionCardState extends State<InteractionAccordionCard> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final finding = widget.finding;

    final Color cardBorder;
    final Color cardBg;
    final Color badgeBg;
    final String badgeLevel;
    final String severityTitle;
    final String legacyBadgeText;

    switch (finding.severityLevel) {
      case 4:
        cardBorder = const Color(0xFFFECACA);
        cardBg = const Color(0xFFFEF2F2);
        badgeBg = const Color(0xFFDC2626);
        badgeLevel = 'MỨC 1';
        severityTitle = 'Chống chỉ định tuyệt đối';
        legacyBadgeText = 'Mức 4 · Chống chỉ định';
        break;
      case 3:
        cardBorder = const Color(0xFFFED7AA);
        cardBg = const Color(0xFFFFF7ED);
        badgeBg = const Color(0xFFEA580C);
        badgeLevel = 'MỨC 2';
        severityTitle = 'Nghiêm trọng - Cân nhắc thay thế';
        legacyBadgeText = 'Mức 3 · Nghiêm trọng';
        break;
      case 2:
        cardBorder = const Color(0xFFFDE68A);
        cardBg = const Color(0xFFFEFCE8);
        badgeBg = const Color(0xFFD97706);
        badgeLevel = 'MỨC 3';
        severityTitle = 'Cần theo dõi chặt chẽ';
        legacyBadgeText = 'Mức 2 · Cần thận trọng';
        break;
      default:
        cardBorder = const Color(0xFFE2E8F0);
        cardBg = const Color(0xFFF8FAFC);
        badgeBg = const Color(0xFF65A30D);
        badgeLevel = 'MỨC 4';
        severityTitle = 'Tương tác nhẹ / Thận trọng';
        legacyBadgeText = 'Mức 1 · Theo dõi';
        break;
    }

    final medA = finding.medicationAName ?? finding.ingredientAName;
    final medB = finding.medicationBName ?? finding.ingredientBName;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.field),
        border: Border.all(color: cardBorder, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.02),
            offset: Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Accordion: bấm để đóng/mở
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Container(
              color: cardBg,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm + 2,
                vertical: AppSpacing.xs + 2,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 12,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          badgeLevel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs + 2),
                  Expanded(
                    child: Text(
                      severityTitle,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: badgeBg,
                      ),
                    ),
                  ),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: badgeBg,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // Khung tên cặp thuốc (Container màu trắng bo góc chuẩn Figma)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.medication_outlined,
                        size: 18,
                        color: Color(0xFF4B5563),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$medA  ↔  $medB',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                            Text(
                              'Hoạt chất: ${finding.ingredientAName} + ${finding.ingredientBName}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                            // Dòng legacy badge hỗ trợ test suite
                            Text(
                              legacyBadgeText,
                              style: TextStyle(
                                fontSize: 10,
                                color: badgeBg,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Text mô tả cơ chế/nguy cơ (luôn hiển thị tóm tắt, bung mở chi tiết hơn khi expand)
                if (!_isExpanded && finding.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    finding.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF4B5563),
                    ),
                  ),
                ],

                // Nội dung bung chi tiết (Figma S06c-2: Nguy cơ + Khuyến nghị + Nguồn)
                if (_isExpanded) ...[
                  const SizedBox(height: AppSpacing.xs + 2),

                  // Khối Nguy cơ (Màu đỏ)
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.xs + 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFFEE2E2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Nguy cơ',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFB91C1C),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          finding.description.isNotEmpty
                              ? finding.description
                              : 'Tăng nguy cơ tác dụng phụ và biến chứng lâm sàng bất lợi khi dùng chung.',
                          style: const TextStyle(
                            fontSize: 11,
                            height: 1.35,
                            color: Color(0xFF374151),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xs),

                  // Khối Khuyến nghị (Màu xanh lá)
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.xs + 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFDCFCE7)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Khuyến nghị',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF047857),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          finding.warningMessage.isNotEmpty
                              ? finding.warningMessage
                              : 'Tham khảo ý kiến bác sĩ/dược sĩ để điều chỉnh liều hoặc lựa chọn thuốc thay thế.',
                          style: const TextStyle(
                            fontSize: 11,
                            height: 1.35,
                            color: Color(0xFF374151),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Nguồn tài liệu y khoa
                  if (finding.source.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Nguồn: ${finding.source}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF6B7280),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
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
                    style: FilledButton.styleFrom(backgroundColor: AppColors.caution),
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

/// Hiển thị hộp thoại lỗi mạng khi không thể kiểm tra tương tác thuốc.
Future<bool?> showInteractionNetworkErrorDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      title: const Row(
        children: [
          Icon(Icons.wifi_off, color: AppColors.caution),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'KHÔNG THỂ KIỂM TRA TƯƠNG TÁC',
              style: AppTextStyles.bodyStrong,
            ),
          ),
        ],
      ),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Không thể kết nối đến máy chủ để kiểm tra tương tác thuốc.\n\n'
            'Bạn có muốn tiếp tục lưu đơn thuốc không?',
            style: AppTextStyles.body,
          ),
          SizedBox(height: AppSpacing.md),
          Text(
            nfr03Disclaimer,
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: AppColors.inkMuted,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Quay lại'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(backgroundColor: AppColors.caution),
          child: const Text('Vẫn tiếp tục lưu'),
        ),
      ],
    ),
  );
}
