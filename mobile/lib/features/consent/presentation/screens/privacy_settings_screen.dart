import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/profile_flow_widgets.dart';

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
          ..showSnackBar(
              SnackBar(content: Text(consentFailureMessage(failure))));
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
      backgroundColor: profileFlowCanvas,
      appBar: ProfileFlowHeader('Quyền riêng tư & Bảo mật',
          titleSize: 17,
          titleScale: MediaQuery.textScalerOf(context).scale(17) / 17,
          backgroundColor: profileFlowCanvas),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 34),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const _Section('Bảo mật đăng nhập', rows: [
              _Row('Mở khóa bằng vân tay hoặc Face ID',
                  icon: Icons.fingerprint, color: _securityIcon, toggle: true),
              _Row('Yêu cầu xác thực lại sau',
                  icon: Icons.schedule, color: _securityIcon),
              _Row('Thiết bị đang đăng nhập',
                  icon: Icons.smartphone, color: _securityIcon),
              _Row('Đăng xuất khỏi tất cả thiết bị khác',
                  icon: Icons.logout, color: _securityIcon),
            ]),
            const SizedBox(height: 16),
            _Section('Quyền riêng tư dữ liệu', rows: [
              _Row('Ai có thể xem hồ sơ của tôi',
                  icon: Icons.people_outline,
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.caregivers)),
              const _Row('Chia sẻ dữ liệu ẩn danh để cải thiện ứng dụng',
                  icon: Icons.bar_chart, toggle: true),
              const _Row('Tải xuống dữ liệu của tôi',
                  icon: Icons.download_outlined),
            ]),
            const SizedBox(height: 16),
            const _PrivacyNote(
              'Mỗi mục đích được đồng ý hoặc rút riêng. Rút một mục đích không ảnh hưởng các '
              'mục đích khác và có hiệu lực ngay.',
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
              OutlinedButton(
                  onPressed: consents.load, child: const Text('Thử lại')),
            ] else
              for (final purpose in ConsentPurpose.toggleable) ...[
                ConsentPurposeCard(
                  purpose: purpose,
                  value: consents.isGranted(purpose),
                  onChanged: _pending.contains(purpose)
                      ? null
                      : (v) => _toggle(purpose, v),
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
          ]),
        ),
      ),
    );
  }
}

// Figma S08-6 values, local to this screen so other profile screens stay as-is.
const _securityIcon = Color(0xFF4D5FAD);
const _dataIcon = Color(0xFF0A7468);
const _label = TextStyle(fontSize: 14, height: 20 / 14, color: AppColors.ink);
const _cardShadow = [
  BoxShadow(color: Color(0x08113632), offset: Offset(0, 1), blurRadius: 4),
  BoxShadow(color: Color(0x10113632), offset: Offset(0, 5), blurRadius: 14),
];

class _Section extends StatelessWidget {
  const _Section(this.title, {required this.rows});
  final String title;
  final List<_Row> rows;

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(title,
            style: const TextStyle(
                fontSize: 15,
                height: 20 / 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF213F3C))),
        const SizedBox(height: 8),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: _cardShadow),
          child: Column(children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const Divider(height: 1, color: Color(0xFFEBF0EF)),
              rows[i],
            ],
          ]),
        ),
      ]);
}

/// Row without [onTap] is a feature not built yet: it says so and never shows
/// a fake value or an "on" toggle.
class _Row extends StatelessWidget {
  const _Row(this.title,
      {required this.icon,
      this.color = _dataIcon,
      this.onTap,
      this.toggle = false});
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool toggle;

  @override
  Widget build(BuildContext context) {
    final available = onTap != null;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Row(children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: _label)),
            const SizedBox(width: 10),
            if (toggle)
              Semantics(label: 'Chưa khả dụng', child: const _OffToggle())
            else if (!available)
              Flexible(
                  child: Text('Chưa khả dụng',
                      textAlign: TextAlign.end,
                      style: _label.copyWith(color: AppColors.inkMuted)))
            else
              const Icon(Icons.chevron_right,
                  size: 15, color: Color(0xFFA6A6A6)),
          ]),
        ),
      ),
    );
  }
}

class _OffToggle extends StatelessWidget {
  const _OffToggle();

  @override
  Widget build(BuildContext context) => Container(
        width: 40,
        height: 24,
        padding: const EdgeInsets.all(2),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
            color: const Color(0xFFE4E4E1),
            borderRadius: BorderRadius.circular(12)),
        child: Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
                color: Colors.white, shape: BoxShape.circle)),
      );
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
            color: const Color(0xFFE6F5F1),
            border: Border.all(color: const Color(0xFFD7EBE6)),
            borderRadius: BorderRadius.circular(14)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Icons.verified_user_outlined,
                  size: 15, color: _dataIcon)),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text,
                  style: _label.copyWith(color: const Color(0xFF2F534E)))),
        ]),
      );
}

class _LegalLink extends StatelessWidget {
  const _LegalLink({super.key, required this.title, required this.route});

  final String title;
  final String route;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        minTileHeight: AppSizes.tapTarget,
        leading:
            const Icon(Icons.description_outlined, color: AppColors.inkMuted),
        title: Text(title, style: AppTextStyles.body),
        trailing: const Icon(Icons.chevron_right, color: AppColors.inkMuted),
        onTap: () => Navigator.of(context).pushNamed(route),
      );
}
