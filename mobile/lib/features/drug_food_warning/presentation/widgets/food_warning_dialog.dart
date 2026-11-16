import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/drug_food_interaction.dart';

/// Hiển thị hộp thoại cảnh báo tương tác thuốc & thức ăn/đồ uống (Task 4.06, Figma Frames S06d-1 & S06d-2).
///
/// Trả về `true` nếu người dùng quyết định tiếp tục lưu, hoặc `false`/`null` nếu quay lại chỉnh sửa.
Future<bool?> showFoodWarningDialog(
  BuildContext context,
  DrugFoodInteractionResult result,
) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => FoodWarningDialog(result: result),
  );
}

/// Hộp thoại thông báo lỗi khi không thể tra cứu tương tác thuốc - thức ăn.
Future<bool?> showFoodNetworkErrorDialog(BuildContext context) {
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
              'Không thể kiểm tra thức ăn',
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
            'Hệ thống không thể đối soát tương tác thuốc với thức ăn/đồ uống do sự cố kết nối mạng.\n\n'
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
          child: const Text('Quay lại', style: TextStyle(color: AppColors.inkMuted)),
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

class FoodWarningDialog extends StatelessWidget {
  const FoodWarningDialog({
    super.key,
    required this.result,
  });

  final DrugFoodInteractionResult result;

  @override
  Widget build(BuildContext context) {
    final highestSev = result.highestSeverityLevel;
    final hasContraindication = result.hasContraindication;

    final Color headerBg;
    final Color headerFg;
    final IconData headerIcon;
    final String headerTitle;

    switch (highestSev) {
      case 1:
        headerBg = AppColors.dangerBg;
        headerFg = AppColors.danger;
        headerIcon = Icons.cancel;
        headerTitle = 'CẢNH BÁO CHỐNG CHỈ ĐỊNH THỰC PHẨM';
        break;
      case 2:
        headerBg = const Color(0xFFFFF7ED);
        headerFg = const Color(0xFFEA580C);
        headerIcon = Icons.warning_amber_rounded;
        headerTitle = 'TƯƠNG TÁC THỨC ĂN NGUY CƠ CAO';
        break;
      case 3:
        headerBg = AppColors.cautionBg;
        headerFg = AppColors.caution;
        headerIcon = Icons.error_outline;
        headerTitle = 'THẬN TRỌNG PHÂN CÁCH GIỜ ĂN';
        break;
      default:
        headerBg = AppColors.infoBg;
        headerFg = AppColors.info;
        headerIcon = Icons.info_outline;
        headerTitle = 'LƯU Ý CHẾ ĐỘ ĂN UỐNG';
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
            // 1. Header cảnh báo phân cấp theo mức độ nguy cơ cao nhất
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

            // 2. Nội dung danh sách cảnh báo Accordion (Figma S06d-1 / S06d-2)
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
                    'Phát hiện ${result.warnings.length} lưu ý tương tác thức ăn:',
                    style: AppTextStyles.bodyStrong,
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  for (final item in result.warnings) ...[
                    FoodWarningAccordionCard(item: item),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // Danh sách thuốc chưa đủ dữ liệu hoạt chất (nếu có)
                  if (result.insufficientDataMedications.isNotEmpty) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: AppSpacing.md),
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.cautionBg,
                        borderRadius: BorderRadius.circular(AppRadius.field),
                        border: Border.all(
                          color: AppColors.caution.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.help_outline,
                                color: AppColors.caution,
                                size: 20,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Expanded(
                                child: Text(
                                  'Thuốc chưa đủ dữ liệu hoạt chất để đối soát:',
                                  style: AppTextStyles.bodyStrong.copyWith(
                                    color: AppColors.caution,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          for (final med in result.insufficientDataMedications)
                            Padding(
                              padding: const EdgeInsets.only(left: 24, top: 2),
                              child: Text('• $med', style: AppTextStyles.body),
                            ),
                        ],
                      ),
                    ),
                  ],

                  // 3. Disclaimer NFR03 bắt buộc luôn hiển thị
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEFCE8),
                      borderRadius: BorderRadius.circular(AppRadius.field),
                      border: Border.all(color: const Color(0xFFFEF08A)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.shield_outlined,
                          size: 18,
                          color: Color(0xFFCA8A04),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            result.disclaimer,
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              color: Color(0xFF713F12),
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

            // 4. Thanh nút tác vụ
            Padding(
              padding: const EdgeInsets.all(AppSpacing.page),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('food_warning_back_button'),
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.field),
                        ),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      child: const Text(
                        'Quay lại chỉnh sửa',
                        style: TextStyle(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: ElevatedButton(
                      key: const Key('food_warning_proceed_button'),
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: hasContraindication
                            ? AppColors.danger
                            : AppColors.brand,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.field),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Tôi đã hiểu và tiếp tục',
                        style: TextStyle(fontWeight: FontWeight.bold),
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

/// Thẻ tương tác Accordion (Figma S06d-1 thu gọn / S06d-2 mở rộng).
/// Khóa cố định cột nhãn `width: 92px` để căn thẳng tắp toàn bộ nội dung.
class FoodWarningAccordionCard extends StatefulWidget {
  const FoodWarningAccordionCard({
    super.key,
    required this.item,
    this.initiallyExpanded = false,
  });

  final FoodWarningItem item;
  final bool initiallyExpanded;

  @override
  State<FoodWarningAccordionCard> createState() =>
      _FoodWarningAccordionCardState();
}

class _FoodWarningAccordionCardState extends State<FoodWarningAccordionCard> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    final Color cardBorder;
    final Color cardBg;
    final Color badgeBg;
    final Color badgeFg;
    final String severitySubtitle;

    switch (item.severity) {
      case FoodInteractionSeverity.contraindicated:
        cardBorder = const Color(0xFFFECACA);
        cardBg = const Color(0xFFFEF2F2);
        badgeBg = const Color(0xFF991B1B);
        badgeFg = Colors.white;
        severitySubtitle = 'Chống chỉ định · ${item.foodCategory}';
        break;
      case FoodInteractionSeverity.severe:
        cardBorder = const Color(0xFFFED7AA);
        cardBg = const Color(0xFFFFF7ED);
        badgeBg = const Color(0xFFC2410C);
        badgeFg = Colors.white;
        severitySubtitle = 'Nghiêm trọng · ${item.foodCategory}';
        break;
      case FoodInteractionSeverity.moderate:
        cardBorder = const Color(0xFFFDE68A);
        cardBg = const Color(0xFFFEFCE8);
        badgeBg = const Color(0xFFD97706);
        badgeFg = Colors.white;
        severitySubtitle = 'Thận trọng · ${item.foodCategory}';
        break;
      case FoodInteractionSeverity.minor:
        cardBorder = const Color(0xFFBFDBFE);
        cardBg = const Color(0xFFEFF6FF);
        badgeBg = const Color(0xFF2563EB);
        badgeFg = Colors.white;
        severitySubtitle = 'Theo dõi · ${item.foodCategory}';
        break;
    }

    return Container(
      key: Key('food_warning_card_${item.id}'),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.field),
        border: Border.all(color: cardBorder, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.04),
            offset: Offset(0, 2),
            blurRadius: 6,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header bấm để thu gọn / mở rộng (Accordion Header)
          InkWell(
            key: Key('food_warning_toggle_${item.id}'),
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Container(
              color: cardBg,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  // Icon cảnh báo nhỏ
                  Icon(
                    item.isContraindicated
                        ? Icons.error_outline
                        : Icons.warning_amber_rounded,
                    color: badgeBg,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.sm),

                  // Pill mức độ nguy cơ
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      item.severity.tag,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: badgeFg,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),

                  // Tiêu đề mức độ & Nhóm thực phẩm
                  Expanded(
                    child: Text(
                      severitySubtitle,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: badgeBg,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  // Dấu mũi tên tam giác ngược nhỏ khi thu gọn, mũi tên hướng lên khi mở rộng
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: AppColors.inkMuted,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),

          // Tóm tắt cặp tương tác (Luôn hiển thị ở cả trạng thái thu gọn lẫn mở rộng)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.restaurant_menu,
                        size: 18,
                        color: AppColors.brand,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.ink,
                              fontWeight: FontWeight.w600,
                            ),
                            children: [
                              TextSpan(text: item.medicationName),
                              const TextSpan(
                                text: '  ⇄  ',
                                style: TextStyle(
                                  color: AppColors.inkMuted,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextSpan(
                                text: item.foodName,
                                style: TextStyle(color: badgeBg),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Khi mở rộng: Bung chi tiết (Căn thẳng tắp cột nhãn 92px)
                if (_isExpanded) ...[
                  const SizedBox(height: AppSpacing.md),
                  const Divider(height: 1, color: Color(0xFFF3F4F6)),
                  const SizedBox(height: AppSpacing.md),

                  // Dòng 1: Nguy cơ (Nhãn cố định 92px)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(
                        width: 92,
                        child: Text(
                          '• Nguy cơ:',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFB91C1C),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          item.mechanismAndRisk,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            color: Color(0xFF374151),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.sm),

                  // Dòng 2: Khuyến nghị (Nhãn cố định 92px)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(
                        width: 92,
                        child: Text(
                          '• Khuyến nghị:',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF047857),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          item.recommendation,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            color: Color(0xFF374151),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Khuyến nghị về thời gian uống (nếu có)
                  if (item.timingAdvice != null &&
                      item.timingAdvice!.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.schedule,
                            size: 16,
                            color: Color(0xFFD97706),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Phân cách: ${item.timingAdvice!}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFB45309),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.sm),

                  // Nguồn tham khảo
                  Text(
                    'Nguồn tham khảo: ${item.source}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
