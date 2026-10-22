import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../family/presentation/state/family_alert_scope.dart';
import '../../../consent/domain/entities/consent.dart';
import '../../../consent/presentation/state/consent_controller.dart';
import '../state/family_link_scope.dart';
import '../state/incoming_requests_controller.dart';
import '../widgets/incoming_requests_section.dart';

/// Tab "Người thân": yêu cầu theo dõi đang chờ người dùng duyệt, chia sẻ mã của mình (màn QR
/// của 3.11, link mời) và theo dõi người thân mới.
///
/// Người giám sát đã chấp thuận được quản lý ở Hồ sơ > Người giám sát.
class FamilyTabScreen extends StatefulWidget {
  const FamilyTabScreen({super.key, this.active = true});

  /// Tab đang hiển thị. Chuyển sang `true` thì tải lại yêu cầu đang chờ (không cache).
  final bool active;

  @override
  State<FamilyTabScreen> createState() => _FamilyTabScreenState();
}

class _FamilyTabScreenState extends State<FamilyTabScreen> {
  IncomingRequestsController? _requests;

  IncomingRequestsController get _controller =>
      _requests ??= IncomingRequestsController(FamilyLinkScope.read(context).caregivers);

  @override
  void initState() {
    super.initState();
    if (widget.active) _queueLoad();
  }

  @override
  void didUpdateWidget(FamilyTabScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _queueLoad();
  }

  void _queueLoad() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_controller.load());
      });

  @override
  void dispose() {
    _requests?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
 final unread = FamilyAlertScope.maybeOf(context)?.unreadCount;
    final sharingGranted =
        ConsentScope.of(context).isGranted(ConsentPurpose.familySharing);
    return Scaffold(
      appBar: AppBar(title: const Text('Người thân')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _controller.load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.page),
            children: [
              IncomingRequestsSection(
                controller: _controller,
                sharingConsentGranted: sharingGranted,
              ),
              _EntryCard(
                key: const Key('family-alerts'),
                icon: Icons.notifications_outlined,
                title: 'Cảnh báo người thân',
                subtitle:
                    unread == null ? 'Mở hộp thư cảnh báo' : '$unread chưa đọc',
                onTap: () =>
                    Navigator.of(context).pushNamed(AppRoutes.familyAlerts),
              ),
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
