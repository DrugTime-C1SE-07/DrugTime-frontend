import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/caregiver_failure.dart';
import '../../domain/entities/incoming_link_request.dart';
import '../state/family_link_scope.dart';
import '../state/incoming_requests_controller.dart';
import '../widgets/caregiver_messages.dart';

class LinkConsentConfirmationArgs {
  const LinkConsentConfirmationArgs({
    required this.request,
    this.controller,
  });

  final IncomingLinkRequest request;
  final IncomingRequestsController? controller;
}

/// Màn xác nhận chi tiết yêu cầu liên kết của người thân (PB16, Task 3.17).
///
/// Hiển thị thông tin người xin liên kết, mục đích, danh sách dữ liệu chia sẻ
/// và quyền kiểm soát (tắt chia sẻ tạm thời vs gỡ liên kết QD-30).
/// Hai nút "Đồng ý" và "Từ chối" ngang hàng, không checkbox tick sẵn, không đồng ý ngầm.
/// Đóng màn hoặc back = không đồng ý (yêu cầu vẫn pending).
class LinkConsentConfirmationScreen extends StatefulWidget {
  const LinkConsentConfirmationScreen({
    super.key,
    required this.args,
  });

  final LinkConsentConfirmationArgs args;

  static Future<bool?> show(
    BuildContext context, {
    required IncomingLinkRequest request,
    IncomingRequestsController? controller,
  }) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LinkConsentConfirmationScreen(
          args: LinkConsentConfirmationArgs(
            request: request,
            controller: controller,
          ),
        ),
      ),
    );
  }

  @override
  State<LinkConsentConfirmationScreen> createState() =>
      _LinkConsentConfirmationScreenState();
}

class _LinkConsentConfirmationScreenState
    extends State<LinkConsentConfirmationScreen> {
  bool _submitting = false;

  IncomingRequestsController get _controller =>
      widget.args.controller ??
      FamilyLinkScope.maybeOf(context)?.incomingRequests ??
      IncomingRequestsController(FamilyLinkScope.read(context).caregivers);

  IncomingLinkRequest get _request => widget.args.request;

  @override
  Widget build(BuildContext context) {
    final name = familyDisplayName(_request.familyName);
    final phone = _request.familyPhone;
    final email = _request.familyEmail;

    return PopScope(
      canPop: !_submitting,
      // Back/đóng màn hình không bao giờ tự đồng ý (yêu cầu vẫn pending).
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (!_submitting) Navigator.of(context).pop(false);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Xác nhận chia sẻ dữ liệu'),
          leading: IconButton(
            key: const Key('consent-confirm-close'),
            icon: const Icon(Icons.close),
            tooltip: 'Đóng',
            onPressed: _submitting ? null : () => Navigator.of(context).pop(false),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.page),
                  children: [
                    _buildRequesterCard(context, name, phone, email),
                    const SizedBox(height: AppSpacing.md),
                    _buildPurposeCard(),
                    const SizedBox(height: AppSpacing.md),
                    _buildSharedDataCard(),
                    const SizedBox(height: AppSpacing.md),
                    _buildPrivacyAndRevocationCard(),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
              _buildBottomActionButtons(name),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequesterCard(
    BuildContext context,
    String name,
    String? phone,
    String? email,
  ) {
    return Card(
      key: const Key('consent-requester-card'),
      elevation: 0,
      margin: EdgeInsets.zero,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: AppColors.brandTint,
                  child: Icon(Icons.person_outline, color: AppColors.brand),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        key: const Key('consent-requester-name'),
                        style: AppTextStyles.heading,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      const Text(
                        'Yêu cầu liên kết để theo dõi việc dùng thuốc',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.sm),
            if (phone != null && phone.trim().isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    const Icon(Icons.phone_outlined,
                        size: 18, color: AppColors.inkMuted),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'SĐT: $phone',
                        key: const Key('consent-requester-phone'),
                        style: AppTextStyles.body,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (email != null && email.trim().isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    const Icon(Icons.email_outlined,
                        size: 18, color: AppColors.inkMuted),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Email: $email',
                        key: const Key('consent-requester-email'),
                        style: AppTextStyles.body,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  const Icon(Icons.access_time_outlined,
                      size: 18, color: AppColors.inkMuted),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Gửi lúc ${formatVietnamDateTime(_request.requestedAt)}',
                      key: const Key('consent-requester-time'),
                      style: AppTextStyles.caption,
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

  Widget _buildPurposeCard() {
    return Card(
      key: const Key('consent-purpose-card'),
      elevation: 0,
      margin: EdgeInsets.zero,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: const BorderSide(color: AppColors.border),
      ),
      child: const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mục đích chia sẻ', style: AppTextStyles.bodyStrong),
            SizedBox(height: AppSpacing.xs),
            Text(
              'Cho phép người thân đồng hành, theo dõi tình trạng dùng thuốc và nhận cảnh báo '
              'khi bạn cần hỗ trợ để đảm bảo an toàn dùng thuốc.',
              style: AppTextStyles.body,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSharedDataCard() {
    return Card(
      key: const Key('consent-shared-data-card'),
      elevation: 0,
      margin: EdgeInsets.zero,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: const BorderSide(color: AppColors.border),
      ),
      child: const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dữ liệu sẽ được chia sẻ', style: AppTextStyles.bodyStrong),
            SizedBox(height: AppSpacing.sm),
            _DataItemRow(
              icon: Icons.history,
              title: 'Lịch sử tuân thủ',
              description: 'Xem kết quả uống thuốc đúng giờ, uống trễ hoặc bỏ lỡ của bạn.',
            ),
            SizedBox(height: AppSpacing.sm),
            _DataItemRow(
              icon: Icons.medication_outlined,
              title: 'Danh sách thuốc',
              description: 'Xem tên thuốc, liều dùng, hướng dẫn và lịch uống hàng ngày.',
            ),
            SizedBox(height: AppSpacing.sm),
            _DataItemRow(
              icon: Icons.notifications_active_outlined,
              title: 'Cảnh báo bỏ lỡ liều',
              description: 'Nhận thông báo khi bạn bỏ lỡ liều thuốc để kịp thời nhắc nhở.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyAndRevocationCard() {
    return Card(
      key: const Key('consent-revocation-card'),
      elevation: 0,
      margin: EdgeInsets.zero,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: const BorderSide(color: AppColors.border),
      ),
      child: const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.security, size: 20, color: AppColors.brand),
                SizedBox(width: AppSpacing.xs),
                Text('Quyền kiểm soát của bạn', style: AppTextStyles.bodyStrong),
              ],
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              '• Tắt chia sẻ tạm thời: Bạn có thể tắt công tắc chia sẻ trong Hồ sơ > Người giám sát '
              'bất cứ lúc nào để tạm dừng người thân xem dữ liệu mà vẫn giữ liên kết.\n\n'
              '• Gỡ liên kết: Gỡ liên kết trong Hồ sơ > Người giám sát sẽ chấm dứt hoàn toàn quyền truy cập. '
              'Nếu muốn xem lại sau này, người thân phải gửi yêu cầu liên kết mới (QD-30).\n\n'
              '• Lưu ý: Các thông báo và cảnh báo đã gửi tới thiết bị người thân trước thời điểm rút quyền '
              'không thể thu hồi lại.',
              style: AppTextStyles.caption,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActionButtons(String name) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.page),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                key: const Key('consent-confirm-reject'),
                onPressed: _submitting ? null : () => unawaited(_handleReject(name)),
                icon: const Icon(Icons.close, size: 20),
                label: const Text('Từ chối', style: AppTextStyles.bodyStrong),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: SizedBox(
              height: 48,
              child: FilledButton.icon(
                key: const Key('consent-confirm-approve'),
                onPressed: _submitting ? null : () => unawaited(_handleApprove(name)),
                icon: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.surface,
                        ),
                      )
                    : const Icon(Icons.check, size: 20),
                label: const Text('Đồng ý', style: AppTextStyles.bodyStrong),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleApprove(String name) async {
    setState(() => _submitting = true);
    final error = await _controller.approve(_request);
    if (!mounted) return;
    setState(() => _submitting = false);

    if (error != null) {
      _showError(error);
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(false);
      }
      return;
    }

    _showMessage('Đã đồng ý yêu cầu liên kết của $name.');
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _handleReject(String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const Key('reject-confirm-dialog'),
        title: Text('Từ chối $name?'),
        content: const Text(
          'Người này sẽ không thể theo dõi thông tin thuốc của bạn. '
          'Họ có thể gửi lại yêu cầu liên kết sau.',
        ),
        actions: [
          TextButton(
            key: const Key('reject-dialog-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            key: const Key('reject-dialog-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Từ chối'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _submitting = true);
    final error = await _controller.reject(_request);
    if (!mounted) return;
    setState(() => _submitting = false);

    if (error != null) {
      _showError(error);
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(false);
      }
      return;
    }

    _showMessage('Đã từ chối yêu cầu của $name.');
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(false);
    }
  }

  void _showError(CaregiverFailureKind kind) {
    final message = caregiverFailureMessage(kind);
    if (message != null) _showMessage(message);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _DataItemRow extends StatelessWidget {
  const _DataItemRow({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.brand),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.bodyStrong),
              const SizedBox(height: 2),
              Text(description, style: AppTextStyles.caption),
            ],
          ),
        ),
      ],
    );
  }
}
