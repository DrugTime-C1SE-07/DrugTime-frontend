import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/widgets/vector_icons.dart';

/// Trust card theo thiết kế `trust-card`. Câu chữ chỉ nêu điều hệ thống thực sự làm (HTTPS,
/// người thân chỉ xem khi được cho phép):
/// - Rộng 327px, Cao 118px, Padding 16px, Gap 12px
/// - Nền [AppColors.brandTint] (#E7F3F1), Bo góc 12px
/// - Dòng 1: ShieldCheckIcon (16x16) + nhãn 12.5px
/// - Dòng 2: LockIcon (16x16) + nhãn 12.5px
class TrustCard extends StatelessWidget {
  const TrustCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 327.0,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.brandTint,
        borderRadius: BorderRadius.circular(AppRadius.field),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Trust row 1: Shield-check
          _TrustRow(
            icon: ShieldCheckIcon(size: 16.0),
            text: 'Chỉ người thân bạn cho phép mới xem được dữ liệu của bạn.',
          ),
          SizedBox(height: AppSpacing.md),

          // Trust row 2: Lock
          _TrustRow(
            icon: LockIcon(size: 16.0),
            text: 'Dữ liệu được truyền qua kết nối mã hóa.',
          ),
        ],
      ),
    );
  }
}

class _TrustRow extends StatelessWidget {
  const _TrustRow({
    required this.icon,
    required this.text,
  });

  final Widget icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1.0),
          child: icon,
        ),
        const SizedBox(width: 10.0),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w400,
              height: 18.0 / 12.5,
              color: AppColors.ink,
            ),
          ),
        ),
      ],
    );
  }
}
