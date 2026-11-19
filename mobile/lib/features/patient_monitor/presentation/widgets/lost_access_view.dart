import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../family_link/presentation/garden/care_garden.dart';
import '../../../family_link/presentation/garden/garden_mood.dart';

/// R8 · Không còn xem được (gộp R7). API trả 403 như nhau cho "tắt chia sẻ" và "hủy liên
/// kết", nên chữ trung tính và không hứa tự khôi phục (QD-30: liên kết lại cần yêu cầu mới).
class LostAccessView extends StatelessWidget {
  const LostAccessView(
      {super.key,
      required this.name,
      required this.signedIn,
      required this.onBack});

  /// Tên đã biết trước khi mất quyền; rỗng thì dùng "Người thân".
  final String name;

  /// false: mất phiên / mất mạng chứ không phải bị thu hồi.
  final bool signedIn;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final who = name.isEmpty ? 'Người thân' : name;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: const CareGarden(
              key: Key('lost-garden'), height: 190, mood: GardenMood.lost),
        ),
        const SizedBox(height: 20),
        Text(signedIn ? 'Không còn xem được' : 'Cần kết nối lại',
            key: const Key('lost-title'),
            style: AppTextStyles.title,
            textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(
            signedIn
                ? '$who đã dừng chia sẻ hoặc hủy liên kết.'
                : 'Cần kết nối và phiên đăng nhập để xem thông tin.',
            style: AppTextStyles.body,
            textAlign: TextAlign.center),
        if (signedIn) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(16)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.info_outline, color: AppColors.inkMuted),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                    'Dữ liệu đã xem trước đây cũng được ẩn. Nếu cần, hãy nói chuyện với $who.',
                    style: AppTextStyles.caption),
              ),
            ]),
          ),
        ],
        const SizedBox(height: 24),
        FilledButton(
          key: const Key('lost-back'),
          onPressed: onBack,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: const Text('Về Người thân'),
        ),
      ],
    );
  }
}
