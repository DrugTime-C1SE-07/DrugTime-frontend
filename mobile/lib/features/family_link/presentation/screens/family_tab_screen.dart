import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../family/presentation/state/family_alert_scope.dart';

/// Tab "Người thân": chia sẻ mã của mình (màn QR của 3.11, link mời) và theo dõi người thân mới.
/// Danh sách người thân sẽ được task khác thêm vào màn này.
class FamilyTabScreen extends StatelessWidget {
  const FamilyTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // null là chưa có count được server xác nhận, không đồng nghĩa 0 chưa đọc.
    final unread = FamilyAlertScope.maybeOf(context)?.unreadCount;
    return Scaffold(
      appBar: AppBar(title: const Text('Người thân')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.page),
          children: [
            _EntryCard(
                key: const Key('family-alerts'),
                icon: Icons.notifications_outlined,
                title: 'Cảnh báo người thân',
                subtitle:
                    unread == null ? 'Mở hộp thư cảnh báo' : '$unread chưa đọc',
                onTap: () =>
                    Navigator.of(context).pushNamed(AppRoutes.familyAlerts)),
            const SizedBox(height: AppSpacing.md),
            _EntryCard(
              key: const Key('family-my-code'),
              icon: Icons.qr_code_2,
              title: 'Mã liên kết của tôi',
              subtitle: 'Cho người thân quét hoặc nhập để theo dõi bạn',
              onTap: () =>
                  Navigator.of(context).pushNamed(AppRoutes.familyMyCode),
            ),
            const SizedBox(height: AppSpacing.md),
            _EntryCard(
              key: const Key('family-share-link'),
              icon: Icons.share_outlined,
              title: 'Gửi link mời',
              subtitle:
                  'Gửi qua Zalo, tin nhắn hoặc email để người thân theo dõi bạn',
              onTap: () =>
                  Navigator.of(context).pushNamed(AppRoutes.familyShareLink),
            ),
            const SizedBox(height: AppSpacing.md),
            _EntryCard(
              key: const Key('family-follow'),
              icon: Icons.person_add_alt_1_outlined,
              title: 'Theo dõi người thân',
              subtitle: 'Quét mã QR hoặc nhập mã của người thân',
              onTap: () => unawaited(showFollowMethodSheet(context)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chọn cách đưa mã của người thân vào app.
Future<void> showFollowMethodSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.page, 0, AppSpacing.page, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Theo dõi người thân', style: AppTextStyles.heading),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Người thân cần chấp thuận thì bạn mới xem được thông tin của họ.',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: AppSpacing.lg),
            ListTile(
              key: const Key('follow-method-scan'),
              leading:
                  const Icon(Icons.qr_code_scanner, color: AppColors.brand),
              title: const Text('Quét mã QR', style: AppTextStyles.bodyStrong),
              onTap: () {
                Navigator.of(sheetContext).pop();
                unawaited(
                    Navigator.of(context).pushNamed(AppRoutes.familyScanCode));
              },
            ),
            ListTile(
              key: const Key('follow-method-enter'),
              leading:
                  const Icon(Icons.keyboard_outlined, color: AppColors.brand),
              title: const Text('Nhập mã', style: AppTextStyles.bodyStrong),
              onTap: () {
                Navigator.of(sheetContext).pop();
                unawaited(
                    Navigator.of(context).pushNamed(AppRoutes.familyEnterCode));
              },
            ),
          ],
        ),
      ),
    ),
  );
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: const BorderSide(color: AppColors.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        leading: CircleAvatar(
          backgroundColor: AppColors.brandTint,
          child: Icon(icon, color: AppColors.brand),
        ),
        title: Text(title, style: AppTextStyles.bodyStrong),
        subtitle: Text(subtitle, style: AppTextStyles.caption),
        trailing: const Icon(Icons.chevron_right, color: AppColors.inkMuted),
        onTap: onTap,
      ),
    );
  }
}
