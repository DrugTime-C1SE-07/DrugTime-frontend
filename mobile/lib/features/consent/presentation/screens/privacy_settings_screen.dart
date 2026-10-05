import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../medication/presentation/state/medication_controller.dart';
import '../../domain/entities/consent.dart';
import '../../domain/entities/consent_failure.dart';
import '../state/consent_controller.dart';
import '../widgets/consent_purpose_card.dart';
import '../widgets/consent_texts.dart';

/// Xem và đổi consent từng mục đích. Bật là đồng ý ngay; tắt phải xác nhận vì có hệ quả.
/// Điều khoản không có công tắc (không rút được); chỉ có link đọc lại hai văn bản.
class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  /// Mục đang gửi request: công tắc của mục đó bị khóa.
  final Set<ConsentPurpose> _pending = {};

  @override
  void initState() {
    super.initState();
    // Luôn đọc lại từ server khi mở màn; sau frame đầu vì load() báo thay đổi ngay.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(ConsentScope.read(context).load());
    });
  }

  Future<void> _toggle(ConsentPurpose purpose, bool value) async {
    if (!value && !await _confirmWithdraw(purpose)) return;
    if (!mounted) return;
    final consents = ConsentScope.read(context);
    final medications = MedicationScope.read(context);
    setState(() => _pending.add(purpose));
    try {
      if (value) {
        await consents.grant(purpose);
      } else {
        await consents.withdraw(purpose);
      }
      // Danh sách thuốc phụ thuộc health_data: tải lại để hiện đúng (dữ liệu hoặc lời mời).
      if (purpose == ConsentPurpose.healthData) unawaited(medications.load());
    } on ConsentFailure catch (failure) {
      // Controller giữ trạng thái cũ nên công tắc tự trở lại vị trí trước.
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(consentFailureMessage(failure))));
      }
    } finally {
      if (mounted) setState(() => _pending.remove(purpose));
    }
  }

  Future<bool> _confirmWithdraw(ConsentPurpose purpose) async {
    final text = consentTexts[purpose]!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(text.withdrawTitle),
        content: Text(text.withdrawConsequence),
        actions: [
          TextButton(
            key: const Key('consent-withdraw-cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            key: const Key('consent-withdraw-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Rút đồng ý'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final consents = ConsentScope.of(context);
    final loading = consents.isLoading && !consents.isLoaded;
    final loadError = consents.loadError;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('Quyền riêng tư'), backgroundColor: AppColors.canvas),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.page),
          children: [
            const Text(
              'Mỗi mục đích được đồng ý hoặc rút riêng. Rút một mục đích không ảnh hưởng các '
              'mục đích khác và có hiệu lực ngay.',
              style: AppTextStyles.body,
            ),
            const SizedBox(height: AppSpacing.lg),
            if (loading)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.xxl),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (!consents.isLoaded && loadError != null) ...[
              Text(
                consentFailureMessage(loadError),
                key: const Key('privacy-load-error'),
                style: AppTextStyles.body.copyWith(color: AppColors.danger),
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton(onPressed: consents.load, child: const Text('Thử lại')),
            ] else
              for (final purpose in ConsentPurpose.toggleable) ...[
                ConsentPurposeCard(
                  purpose: purpose,
                  value: consents.isGranted(purpose),
                  onChanged: _pending.contains(purpose) ? null : (v) => _toggle(purpose, v),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            const SizedBox(height: AppSpacing.md),
            const _LegalLink(
              key: Key('privacy-link-terms'),
              title: 'Điều khoản dịch vụ',
              route: AppRoutes.termsOfService,
            ),
            const _LegalLink(
              key: Key('privacy-link-privacy'),
              title: 'Chính sách quyền riêng tư',
              route: AppRoutes.privacyPolicy,
            ),
          ],
        ),
      ),
    );
  }
}

class _LegalLink extends StatelessWidget {
  const _LegalLink({super.key, required this.title, required this.route});

  final String title;
  final String route;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        minTileHeight: AppSizes.tapTarget,
        leading: const Icon(Icons.description_outlined, color: AppColors.inkMuted),
        title: Text(title, style: AppTextStyles.body),
        trailing: const Icon(Icons.chevron_right, color: AppColors.inkMuted),
        onTap: () => Navigator.of(context).pushNamed(route),
      );
}
