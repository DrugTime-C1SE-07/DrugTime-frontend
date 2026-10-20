import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../consent/domain/entities/consent.dart';
import '../../../consent/presentation/state/consent_controller.dart';
import '../../../family/presentation/state/family_link_code_controller.dart';
import '../../domain/entities/link_code.dart';
import '../state/family_link_scope.dart';

/// Câu mời gửi kèm link: không có tên hay thông tin hồ sơ của người gửi.
String inviteShareText(String link) =>
    'Mời bạn theo dõi việc uống thuốc của tôi trên DrugTime. '
    'Mở link, rồi gửi yêu cầu để tôi chấp thuận: $link';

/// Patient chia sẻ link mời cố định `https://<host>/link#code=<mã>` (Figma S08-3g, bỏ thời hạn
/// vì QD-04). Mã lấy từ `GET /family/link-code` qua controller của 3.11.
class ShareInviteLinkScreen extends StatefulWidget {
  const ShareInviteLinkScreen({super.key});

  @override
  State<ShareInviteLinkScreen> createState() => _ShareInviteLinkScreenState();
}

class _ShareInviteLinkScreenState extends State<ShareInviteLinkScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final codes = FamilyLinkCodeScope.read(context);
      if (codes.code == null && !codes.isLoading) unawaited(codes.load());
    });
  }

  Future<void> _copy(String link) async {
    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Đã sao chép link')));
  }

  @override
  Widget build(BuildContext context) {
    final scope = FamilyLinkScope.read(context);
    final codes = FamilyLinkCodeScope.of(context);
    final consents = ConsentScope.of(context);
    final code = codes.code?.code;
    final link = code == null ? null : inviteLinkFor(code, host: scope.inviteLinkHost);
    final sharingOff = consents.isLoaded && !consents.isGranted(ConsentPurpose.familySharing);

    return Scaffold(
      appBar: AppBar(title: const Text('Gửi link mời')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.page),
          children: [
            const Text(
              'Gửi link này cho người thân qua Zalo, tin nhắn hoặc email. Người thân mở link, '
              'gửi yêu cầu theo dõi, và chỉ xem được thông tin của bạn sau khi bạn chấp thuận.',
              style: AppTextStyles.body,
            ),
            if (sharingOff) ...[
              const SizedBox(height: AppSpacing.lg),
              _SharingOffWarning(
                onOpenPrivacy: () =>
                    Navigator.of(context).pushNamed(AppRoutes.privacySettings),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            if (link != null)
              ..._buildLink(context, scope, link)
            else if (codes.failure != null)
              _LoadError(onRetry: () => unawaited(FamilyLinkCodeScope.read(context).load()))
            else
              const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildLink(BuildContext context, FamilyLinkScope scope, String link) => [
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.border),
          ),
          child: SelectableText(
            link,
            key: const Key('invite-link'),
            style: AppTextStyles.bodyStrong,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'Link không hết hạn. Ai có link cũng gửi được yêu cầu, nhưng chỉ người bạn chấp thuận '
          'mới theo dõi được bạn.',
          style: AppTextStyles.caption,
        ),
        const SizedBox(height: AppSpacing.xl),
        SizedBox(
          height: AppSizes.primaryButton,
          child: FilledButton.icon(
            key: const Key('invite-share'),
            onPressed: () => unawaited(scope.sharer.share(inviteShareText(link))),
            icon: const Icon(Icons.share_outlined),
            label: const Text('Chia sẻ'),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: AppSizes.primaryButton,
          child: OutlinedButton.icon(
            key: const Key('invite-copy'),
            onPressed: () => unawaited(_copy(link)),
            icon: const Icon(Icons.copy_outlined),
            label: const Text('Sao chép link'),
          ),
        ),
      ];
}

class _SharingOffWarning extends StatelessWidget {
  const _SharingOffWarning({required this.onOpenPrivacy});

  final VoidCallback onOpenPrivacy;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('invite-sharing-off'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cautionBg,
        borderRadius: BorderRadius.circular(AppRadius.field),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bạn chưa bật chia sẻ với gia đình, nên người thân sẽ chưa gửi được yêu cầu bằng link '
            'này. Bật trong Quyền riêng tư.',
            style: AppTextStyles.body.copyWith(color: AppColors.cautionText),
          ),
          TextButton(
            key: const Key('invite-open-privacy'),
            onPressed: onOpenPrivacy,
            child: const Text('Mở Quyền riêng tư'),
          ),
        ],
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('invite-load-error'),
      children: [
        const Icon(Icons.cloud_off_outlined, size: 48, color: AppColors.inkMuted),
        const SizedBox(height: AppSpacing.md),
        const Text(
          'Chưa thể tải link mời. Vui lòng thử lại.',
          style: AppTextStyles.body,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton.icon(
          key: const Key('invite-retry'),
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Thử lại'),
        ),
      ],
    );
  }
}
