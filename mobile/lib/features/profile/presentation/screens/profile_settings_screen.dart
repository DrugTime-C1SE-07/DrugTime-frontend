import 'package:flutter/material.dart';
import '../../../../app/router.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/security/app_lock_controller.dart';
import '../../../../core/security/app_lock_gate.dart';
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
                if (AppLockScope.maybeOf(context) case final lock?)
                  ProfileFlowSection('Bảo mật',
                      children: [_AppLockRow(lock: lock, busy: _busy)]),
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

/// Công tắc "Khóa ứng dụng"; chỉ bật được khi máy đã đặt khóa màn hình.
class _AppLockRow extends StatefulWidget {
  const _AppLockRow({required this.lock, required this.busy});
  final AppLockController lock;
  final bool busy;
  @override
  State<_AppLockRow> createState() => _AppLockRowState();
}

class _AppLockRowState extends State<_AppLockRow> {
  late final Future<bool> _supported = widget.lock.isDeviceSupported();
  bool _changing = false;

  Future<void> _toggle(bool on) async {
    if (_changing) return;
    setState(() => _changing = true);
    try {
      if (!on) {
        await widget.lock.disable();
      } else if (!await widget.lock.enable() && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Chưa xác thực được nên chưa bật khóa ứng dụng')));
      }
    } finally {
      if (mounted) setState(() => _changing = false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
      future: _supported,
      builder: (context, snapshot) {
        final supported = snapshot.data ?? false;
        final enabled = widget.lock.enabled;
        final canChange = supported && !_changing && !widget.busy;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ProfileFlowRow('Khóa ứng dụng',
              key: const Key('settings-app-lock'),
              icon: Icons.lock_outline,
              onTap: canChange ? () => _toggle(!enabled) : null,
              trailing: Switch(
                  key: const Key('settings-app-lock-switch'),
                  value: enabled,
                  onChanged: canChange ? _toggle : null)),
          Padding(
            padding: const EdgeInsets.fromLTRB(44, 0, 14, 10),
            child: Text(
                snapshot.connectionState == ConnectionState.done && !supported
                    ? 'Hãy đặt khóa màn hình cho điện thoại trước'
                    : 'Mở DrugTime bằng Face ID, vân tay hoặc mã khóa màn hình',
                key: const Key('settings-app-lock-hint'),
                style: const TextStyle(
                    fontSize: 12, height: 1.5, color: AppColors.inkMuted)),
          ),
        ]);
      });
}
