import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../consent/domain/entities/consent.dart';
import '../../../consent/presentation/state/consent_controller.dart';
import '../../domain/entities/caregiver.dart';
import '../../domain/entities/caregiver_failure.dart';
import '../state/caregivers_controller.dart';
import '../state/family_link_scope.dart';
import '../widgets/caregiver_messages.dart';
import '../widgets/incoming_requests_section.dart';

/// Kết quả màn trả về khi đóng (`Navigator.pop`).
enum CaregiversScreenResult {
  /// Người dùng muốn sang tab Người thân (xem yêu cầu đang chờ); màn mở nó chuyển tab.
  openFamilyTab,
}

/// Hồ sơ > Người giám sát: người thân đã được chấp thuận, công tắc chia sẻ và hủy liên kết.
class CaregiversScreen extends StatefulWidget {
  const CaregiversScreen({super.key});

  static const openFamilyTab = CaregiversScreenResult.openFamilyTab;

  @override
  State<CaregiversScreen> createState() => _CaregiversScreenState();
}

class _CaregiversScreenState extends State<CaregiversScreen> {
  late final CaregiversController _controller =
      CaregiversController(FamilyLinkScope.read(context).caregivers);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_controller.load());
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sharingGranted = ConsentScope.of(context).isGranted(ConsentPurpose.familySharing);
    return Scaffold(
      appBar: AppBar(title: const Text('Người giám sát')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => RefreshIndicator(
            onRefresh: _controller.load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.page),
              children: [
                if (!sharingGranted) ...[
                  const SharingConsentBanner(key: Key('caregivers-consent-banner')),
                  const SizedBox(height: AppSpacing.md),
                ],
                // Intro text chuẩn Figma S08-3
                const Text(
                  'Người thân được mời sẽ nhận cảnh báo khi bạn bỏ lỡ liều thuốc và có thể xem lịch uống thuốc của bạn.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF5B6169),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                // Tiêu đề section: ĐANG GIÁM SÁT
                if (_controller.items.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'ĐANG GIÁM SÁT',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF5B6169),
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        '${_controller.items.length} người',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF5B6169),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                ..._body(context, sharingGranted),
                // Nút mời người thân giám sát & Thẻ lưu ý bảo mật dữ liệu chuẩn Figma S08-3
                if (_controller.isLoaded && _controller.items.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      key: const Key('caregivers-invite-button'),
                      onPressed: () => Navigator.of(context).pushNamed(AppRoutes.familyShareLink),
                      icon: const Icon(Icons.person_add_outlined, size: 20),
                      label: const Text(
                        'Mời người thân giám sát',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.shield_outlined, size: 18, color: Color(0xFF5B6169)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Người giám sát chỉ thấy lịch uống thuốc và cảnh báo — không xem được chi tiết dị ứng, bệnh nền hay hồ sơ y tế của bạn.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF5B6169),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _body(BuildContext context, bool sharingGranted) {
    if (!_controller.isLoaded) {
      if (_controller.loadError case final error?) {
        return [
          Text(caregiverFailureMessage(error) ?? '', key: const Key('caregivers-load-error')),
          TextButton(onPressed: _controller.load, child: const Text('Thử lại')),
        ];
      }
      return const [Center(child: CircularProgressIndicator())];
    }
    if (_controller.items.isEmpty) return const [_EmptyCaregivers()];
    return [
      for (final caregiver in _controller.items) ...[
        _CaregiverCard(
          key: Key('caregiver-${caregiver.linkId}'),
          caregiver: caregiver,
          busy: _controller.isBusy(caregiver.linkId),
          sharingGranted: sharingGranted,
          onSharingChanged: (enabled) => unawaited(_setSharing(caregiver, enabled)),
          onRevoke: () => unawaited(_revoke(caregiver)),
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    ];
  }

  Future<void> _setSharing(Caregiver caregiver, bool enabled) async {
    final error = await _controller.setSharing(caregiver, enabled: enabled);
    if (!mounted) return;
    final name = familyDisplayName(caregiver.familyName);
    if (error != null) return _showError(error);
    _showMessage(enabled ? 'Đã bật chia sẻ với $name.' : 'Đã tắt chia sẻ với $name.');
  }

  Future<void> _revoke(Caregiver caregiver) async {
    final name = familyDisplayName(caregiver.familyName);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const Key('revoke-dialog'),
        title: const Text('Gỡ liên kết với người thân?'),
        content: const Text(
          'Người thân này sẽ mất quyền xem thông tin của bạn ngay sau khi liên kết bị gỡ. '
          'Bạn có chắc chắn muốn tiếp tục?',
        ),
        actions: [
          TextButton(
            key: const Key('revoke-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            key: const Key('revoke-confirm'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Gỡ liên kết'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final error = await _controller.revoke(caregiver);
    if (!mounted) return;
    if (error != null) return _showError(error);
    _showMessage('Đã gỡ liên kết với $name.');
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

class _EmptyCaregivers extends StatelessWidget {
  const _EmptyCaregivers();

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('caregivers-empty'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.xl),
        const Icon(Icons.people_outline, size: 48, color: AppColors.inkMuted),
        const SizedBox(height: AppSpacing.md),
        const Text(
          'Chưa có người giám sát',
          textAlign: TextAlign.center,
          style: AppTextStyles.heading,
        ),
        const SizedBox(height: AppSpacing.xs),
        const Text(
          'Yêu cầu theo dõi từ người thân hiện ở tab Người thân. Sau khi bạn chấp thuận, họ sẽ '
          'xuất hiện ở đây.',
          textAlign: TextAlign.center,
          style: AppTextStyles.caption,
        ),
        const SizedBox(height: AppSpacing.lg),
        OutlinedButton(
          key: const Key('caregivers-open-family-tab'),
          onPressed: () => Navigator.of(context).pop(CaregiversScreen.openFamilyTab),
          child: const Text('Mở tab Người thân'),
        ),
      ],
    );
  }
}

class _CaregiverCard extends StatelessWidget {
  const _CaregiverCard({
    super.key,
    required this.caregiver,
    required this.busy,
    required this.sharingGranted,
    required this.onSharingChanged,
    required this.onRevoke,
  });

  final Caregiver caregiver;
  final bool busy;
  final bool sharingGranted;
  final ValueChanged<bool> onSharingChanged;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final approvedAt = caregiver.approvedAt;
    // Tắt luôn được (rút quyền); bật cần đã đồng ý family_sharing.
    final canToggle = !busy && (caregiver.sharingEnabled || sharingGranted);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(familyDisplayName(caregiver.familyName), style: AppTextStyles.bodyStrong),
            const SizedBox(height: AppSpacing.xs),
            Text(
              approvedAt == null
                  ? 'Liên kết trước khi có bước xác nhận đồng ý'
                  : 'Chấp thuận ngày ${formatVietnamDate(approvedAt)}',
              style: AppTextStyles.caption,
            ),
            SwitchListTile(
              key: Key('sharing-${caregiver.linkId}'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Chia sẻ dữ liệu', style: AppTextStyles.body),
              subtitle: const Text(
                'Xem thuốc, lịch sử uống thuốc và nhận cảnh báo bỏ liều',
                style: AppTextStyles.caption,
              ),
              value: caregiver.sharingEnabled,
              onChanged: canToggle ? onSharingChanged : null,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: Key('revoke-${caregiver.linkId}'),
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                onPressed: busy ? null : onRevoke,
                child: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Gỡ liên kết'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
