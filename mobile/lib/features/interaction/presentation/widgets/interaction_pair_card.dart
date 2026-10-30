import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/drug_interaction_result.dart';

/// Card hiển thị chi tiết cặp tương tác thuốc–thuốc theo phong cách Clean UI/UX.
///
/// Tinh gọn, giảm tải nhận thức:
/// - Header phân cấp mức độ Chống chỉ định / Nghiêm trọng / Trung bình / Nhẹ.
/// - Khối capsule 2 tên thuốc trực quan với biểu tượng hoán đổi.
/// - 2 dòng bullet points cốt lõi (Nguy cơ + Khuyến nghị) đọc được trong 3 giây.
class InteractionPairCard extends StatelessWidget {
  const InteractionPairCard({
    super.key,
    required this.pair,
  });

  final DrugInteractionPair pair;

  @override
  Widget build(BuildContext context) {
    final severity = pair.severity;

    // Phối màu theo mức độ nghiêm trọng
    final isDanger = severity == InteractionSeverity.contraindicated ||
        severity == InteractionSeverity.severe;
    final isCaution = severity == InteractionSeverity.moderate;

    final cardBg = isDanger
        ? const Color(0xFFFDECEC)
        : (isCaution ? const Color(0xFFFFFBEB) : const Color(0xFFF0FDF4));

    final cardBorder = isDanger
        ? const Color(0xFFF4C7C7)
        : (isCaution ? const Color(0xFFFDE68A) : const Color(0xFFBBF7D0));

    final iconBg = isDanger
        ? const Color(0xFFDC2626)
        : (isCaution ? const Color(0xFFD97706) : const Color(0xFF16A34A));

    final badgeBg = isDanger
        ? const Color(0xFFBA1A1A)
        : (isCaution ? const Color(0xFFB45309) : const Color(0xFF15803D));

    final subtitleText = isDanger
        ? 'Phát hiện tương tác nguy hiểm'
        : (isCaution ? 'Cần theo dõi khi dùng chung' : 'Tương tác mức độ nhẹ');

    final subtitleColor = isDanger
        ? const Color(0xFF7A0000)
        : (isCaution ? const Color(0xFF92400E) : const Color(0xFF166534));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cardBorder,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Header: Icon tròn cảnh báo + Badge mức độ
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: iconBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isDanger
                        ? Icons.warning_amber_rounded
                        : (isCaution ? Icons.info_outline_rounded : Icons.check_circle_outline_rounded),
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          severity.label,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitleText,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: subtitleColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 2. Khối Capsule 2 tên thuốc
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cardBorder),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.medication_outlined, size: 15, color: AppColors.inkMuted),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            pair.firstDrugName,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      '⇄',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: iconBg,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Flexible(
                          child: Text(
                            pair.secondDrugName,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.medication_outlined, size: 15, color: AppColors.inkMuted),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // 3. Cân bằng chữ (2 cột: Label cố định bên trái + Nội dung thẳng hàng bên phải, không thụt thò)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: cardBorder.withValues(alpha: 0.6)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dòng 1: Nguy cơ
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 90,
                        child: Text(
                          '• Nguy cơ:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDanger ? const Color(0xFFBA1A1A) : subtitleColor,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          pair.description,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.ink,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (pair.recommendation != null && pair.recommendation!.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    // Dòng 2: Khuyến nghị
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(
                          width: 90,
                          child: Text(
                            '• Khuyến nghị:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.brand,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            pair.recommendation!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.ink,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

