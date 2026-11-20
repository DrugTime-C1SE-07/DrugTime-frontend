import 'package:flutter/material.dart';
import '../../../../app/router.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/profile_flow_widgets.dart';

class ProfileSettingsArgs {
  const ProfileSettingsArgs({required this.logout});
  final Future<void> Function() logout;
}

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key, this.args});
  final ProfileSettingsArgs? args;
  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  bool _busy = false;
  Future<void> _logout() async {
    if (_busy || widget.args == null) return;
    setState(() => _busy = true);
    try {
      await widget.args!.logout();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_busy,
        child: Scaffold(
          backgroundColor: profileFlowCanvas,
          appBar: ProfileFlowHeader('Cài đặt',
              titleScale: MediaQuery.textScalerOf(context).scale(18) / 18,
              leading: _busy ? const SizedBox.shrink() : null),
          body: SafeArea(
              child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  children: [
                const ProfileFlowSection('Chung', children: [
                  ProfileFlowRow('Ngôn ngữ',
                      icon: Icons.translate, unavailable: true),
                  ProfileFlowRow('Đơn vị đo',
                      icon: Icons.straighten, unavailable: true),
                ]),
                const ProfileFlowSection('Giao diện', children: [
                  ProfileFlowRow('Chế độ tối',
                      icon: Icons.dark_mode_outlined,
                      unavailable: true,
                      trailing: Switch(value: false, onChanged: null)),
                ]),
                ProfileFlowSection('Về DrugTime', children: [
                  const ProfileFlowRow('Phiên bản ứng dụng',
                      icon: Icons.info_outline, unavailable: true),
                  ProfileFlowRow('Điều khoản sử dụng',
                      icon: Icons.description_outlined,
                      onTap: _busy
                          ? null
                          : () => Navigator.pushNamed(
                              context, AppRoutes.termsOfService)),
                  ProfileFlowRow('Chính sách bảo mật',
                      icon: Icons.shield_outlined,
                      onTap: _busy
                          ? null
                          : () => Navigator.pushNamed(
                              context, AppRoutes.privacyPolicy)),
                ]),
                ProfileFlowSection('Tài khoản', children: [
                  ProfileFlowRow(_busy ? 'Đang đăng xuất…' : 'Đăng xuất',
                      key: const Key('settings-logout'),
                      icon: Icons.logout,
                      color: AppColors.danger,
                      unavailable: widget.args == null,
                      onTap: _busy ? null : _logout,
                      trailing: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : null),
                  ProfileFlowRow('Xóa tài khoản',
                      key: const Key('settings-delete-account'),
                      icon: Icons.delete_outline,
                      color: AppColors.danger,
                      onTap: _busy
                          ? null
                          : () => Navigator.pushNamed(
                              context, AppRoutes.accountDeletion)),
                ]),
              ])),
        ),
      );
}
