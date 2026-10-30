import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/caregiver_failure.dart';
import '../../domain/entities/incoming_link_request.dart';
import '../screens/link_consent_confirmation_screen.dart';
import '../state/incoming_requests_controller.dart';
import 'caregiver_messages.dart';

/// Mục "Yêu cầu theo dõi bạn" trên tab Người thân.
///
/// Hỗ trợ các trạng thái: loading, offline, lỗi, rỗng và danh sách các yêu cầu pending.
class IncomingRequestsSection extends StatelessWidget {
  const IncomingRequestsSection({
    super.key,
    required this.controller,
    required this.sharingConsentGranted,
    this.showWhenEmpty = false,
  });

  final IncomingRequestsController controller;

  /// Người dùng đã bật `family_sharing`; chưa bật thì hiện dải nhắc (chấp thuận sẽ bị từ chối).
  final bool sharingConsentGranted;

  /// Hiển thị trạng thái rỗng khi không có yêu cầu nào (mặc định false để ẩn trên Tab Người thân).
  final bool showWhenEmpty;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.isLoading && !controller.isLoaded) {
          return const Center(
            key: Key('incoming-requests-loading'),
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (controller.isOffline && controller.items.isEmpty) {
          return Container(
            key: const Key('incoming-requests-offline'),
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.cautionBg,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.wifi_off, color: AppColors.cautionText, size: 20),
                    SizedBox(width: AppSpacing.xs),
                    Text('Không có kết nối mạng', style: AppTextStyles.bodyStrong),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                const Text(
                  'Cần kết nối mạng để xem và xử lý các yêu cầu liên kết.',
                  style: AppTextStyles.caption,
                ),
                TextButton(
                  key: const Key('incoming-retry-offline'),
                  onPressed: controller.load,
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          );
        }

        if (controller.loadError != null && controller.items.isEmpty) {
          return Container(
            key: const Key('incoming-requests-error'),
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.cautionBg,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  caregiverFailureMessage(controller.loadError!) ?? 'Đã có lỗi xảy ra.',
                  style: AppTextStyles.body,
                ),
                TextButton(
                  key: const Key('incoming-retry-error'),
                  onPressed: controller.load,
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          );
        }

        final items = controller.items;
        if (items.isEmpty) {
          if (showWhenEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Center(
                key: Key('incoming-requests-empty'),
                child: Text(
                  'Không có yêu cầu liên kết nào đang chờ duyệt.',
                  style: AppTextStyles.caption,
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        }

        return Column(
          key: const Key('incoming-requests'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Yêu cầu theo dõi bạn (${items.length})', style: AppTextStyles.heading),
            const SizedBox(height: AppSpacing.sm),
            if (!sharingConsentGranted) ...[
              const SharingConsentBanner(key: Key('incoming-consent-banner')),
              const SizedBox(height: AppSpacing.sm),
            ],
            for (final request in items) ...[
              _RequestCard(controller: controller, request: request, actionContext: context),
              const SizedBox(height: AppSpacing.sm),
            ],
            const SizedBox(height: AppSpacing.md),
          ],
        );
      },
    );
  }
}

/// Dải nhắc bật `family_sharing`, có nút mở màn Quyền riêng tư.
class SharingConsentBanner extends StatelessWidget {
  const SharingConsentBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cautionBg,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            familySharingConsentHint,
            style: TextStyle(color: AppColors.cautionText),
          ),
          TextButton(
            key: const Key('open-privacy-settings'),
            onPressed: () => unawaited(Navigator.of(context).pushNamed(AppRoutes.privacySettings)),
            child: const Text('Mở Quyền riêng tư'),
          ),
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.controller,
    required this.request,
    required this.actionContext,
  });

  final IncomingRequestsController controller;
  final IncomingLinkRequest request;
  final BuildContext actionContext;

  @override
  Widget build(BuildContext context) {
    final busy = controller.isBusy(request.linkId);
    final name = familyDisplayName(request.familyName);
    return Card(
      key: Key('incoming-request-${request.linkId}'),
      elevation: 0,
      margin: EdgeInsets.zero,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: busy ? null : () => unawaited(_openConfirmation(actionContext)),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(name, style: AppTextStyles.bodyStrong),
              if (request.familyPhone != null && request.familyPhone!.trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  'SĐT: ${request.familyPhone}',
                  key: Key('incoming-request-phone-${request.linkId}'),
                  style: AppTextStyles.caption,
                ),
              ],
              if (request.familyEmail != null && request.familyEmail!.trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  'Email: ${request.familyEmail}',
                  key: Key('incoming-request-email-${request.linkId}'),
                  style: AppTextStyles.caption,
                ),
              ],
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Gửi lúc ${formatVietnamDateTime(request.requestedAt)}',
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        key: Key('reject-${request.linkId}'),
                        onPressed: busy ? null : () => unawaited(_reject(actionContext, name)),
                        child: const Text('Từ chối'),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: FilledButton(
                        key: Key('approve-${request.linkId}'),
                        onPressed: busy ? null : () => unawaited(_openConfirmation(actionContext)),
                        child: const Text('Chấp thuận'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openConfirmation(BuildContext context) async {
    final approved = await LinkConsentConfirmationScreen.show(
      context,
      request: request,
      controller: controller,
    );
    if (approved != true || !context.mounted) return;
    final name = familyDisplayName(request.familyName);
    final enable = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const Key('enable-sharing-dialog'),
        title: Text('Đã liên kết với $name'),
        content: const Text(
          'Bật chia sẻ dữ liệu ngay? Người thân chỉ xem được thuốc, lịch sử uống thuốc và nhận '
          'cảnh báo bỏ liều khi chia sẻ đang bật.',
        ),
        actions: [
          TextButton(
            key: const Key('enable-sharing-later'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Để sau'),
          ),
          FilledButton(
            key: const Key('enable-sharing-now'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Bật chia sẻ'),
          ),
        ],
      ),
    );
    if (enable != true || !context.mounted) return;
    final sharingError = await controller.enableSharing(request.linkId);
    if (!context.mounted) return;
    if (sharingError != null) return _showError(context, sharingError);
    _showMessage(context, 'Đã bật chia sẻ với $name.');
  }

  Future<void> _reject(BuildContext context, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const Key('reject-dialog'),
        title: Text('Từ chối $name?'),
        content: const Text('Người này sẽ không theo dõi được bạn. Họ có thể gửi lại yêu cầu.'),
        actions: [
          TextButton(
            key: const Key('reject-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            key: const Key('reject-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Từ chối'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final error = await controller.reject(request);
    if (!context.mounted) return;
    if (error != null) return _showError(context, error);
    _showMessage(context, 'Đã từ chối yêu cầu của $name.');
  }
}

void _showError(BuildContext context, CaregiverFailureKind kind) {
  final message = caregiverFailureMessage(kind);
  if (message != null) _showMessage(context, message);
}

void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
