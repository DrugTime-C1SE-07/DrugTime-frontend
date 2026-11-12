import 'package:flutter/material.dart';
import '../../../../app/app_shell.dart';
import '../../../../app/router.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/coming_soon_view.dart';
import '../../../auth/presentation/state/auth_controller.dart';
import '../../../family_link/presentation/screens/caregivers_screen.dart';
import '../state/profile_controller.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/profile_form_fields.dart';
import '../widgets/profile_icons.dart';
import '../widgets/profile_notices.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.active = true});
  final bool active;
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with WidgetsBindingObserver {
  bool _loggingOut = false;
  // Chờ cleanup token, khóa thao tác lặp và cho thử lại nếu đăng xuất thất bại.
  Future<void> _logout() async {
    if (_loggingOut) return;
    setState(() => _loggingOut = true);
    try {
      await AuthScope.read(context).signOut();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Chưa hoàn tất đăng xuất. Vui lòng thử lại'),
            action: SnackBarAction(label: 'Thử lại', onPressed: _logout)));
      }
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.active) _queueLoad();
  }

  void _queueLoad() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.active) ProfileScope.read(context).load();
      });

  @override
  void didUpdateWidget(ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _queueLoad();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        widget.active &&
        ModalRoute.of(context)?.isCurrent == true) {
      _queueLoad();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _open(String route) async {
    await Navigator.pushNamed(context, route);
    if (mounted && widget.active) await ProfileScope.read(context).load();
  }

  /// Màn Người giám sát trống có nút "Mở tab Người thân": khi đó chuyển tab của shell.
  Future<void> _openCaregivers() async {
    final result =
        await Navigator.pushNamed<CaregiversScreenResult>(context, AppRoutes.caregivers);
    if (!mounted) return;
    if (result == CaregiversScreen.openFamilyTab) {
      AppShell.showTab(context, AppTab.family);
      return;
    }
    if (widget.active) await ProfileScope.read(context).load();
  }

  void _openComingSoon(String title, IconData icon) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => Scaffold(body: ComingSoonView(title: title, icon: icon)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = ProfileScope.of(context);
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: c.load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          children: [
            Row(children: [
              const Expanded(
                  child: Text('Hồ sơ', style: AppTextStyles.display)),
              PopupMenuButton<String>(
                tooltip: 'Cài đặt hồ sơ',
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.brandTint,
                  fixedSize: const Size(AppSizes.tapTarget, AppSizes.tapTarget),
                  padding: EdgeInsets.zero,
                ),
                icon: const SizedBox(
                    width: 20, height: 20, child: ProfileIcon('h-settings')),
                onSelected: (value) {
                  if (value == 'logout') _logout();
                },
                enabled: !_loggingOut,
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'logout', child: Text('Đăng xuất')),
                ],
              ),
            ]),
            const SizedBox(height: 16),
            const ProfileNotices(),
            _ProfileCard(
              name: c.profile?.fullName ?? 'Chưa cung cấp',
              phone: c.profile?.phone == null
                  ? 'Chưa có số điện thoại'
                  : profilePhoneLabel(c.profile!.phone),
              onEdit: () => _open(AppRoutes.personalProfile),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(children: [
                _menu(
                  'Thông tin cá nhân',
                  'Họ tên, ngày sinh, giới tính',
                  'h-user',
                  () => _open(AppRoutes.personalProfile),
                  key: const Key('personal-profile-tile'),
                ),
                _divider(),
                _menu(
                  'Thông tin y tế',
                  c.profile == null
                      ? 'Thông tin bệnh nền'
                      : '${c.profile!.conditions.length} bệnh nền',
                  'h-heart',
                  () => _open(AppRoutes.medicalProfile),
                  key: const Key('medical-profile-tile'),
                ),
                _divider(),
                _menu(
                  'Người giám sát',
                  'Quản lý người giám sát',
                  'h-users',
                  _openCaregivers,
                  key: const Key('supervisors-tile'),
                ),
                _divider(),
                _menu(
                  'Thông báo & Nhắc nhở',
                  'Âm thanh, giờ nhắc, nhắc lại',
                  'h-bell',
                  () => _openComingSoon(
                      'Thông báo & Nhắc nhở', Icons.notifications_none),
                  key: const Key('notifications-tile'),
                ),
                _divider(),
                _menu(
                  'Quyền riêng tư & Bảo mật',
                  'Dữ liệu và quyền truy cập',
                  'h-shield',
                  () => _open(AppRoutes.privacySettings),
                  key: const Key('privacy-settings-tile'),
                ),
                _divider(),
                _menu(
                  'Trợ giúp',
                  'Câu hỏi thường gặp, liên hệ',
                  'h-help-circle',
                  () => _openComingSoon('Trợ giúp', Icons.help_outline),
                  key: const Key('profile-help-tile'),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() =>
      const Divider(height: 1, thickness: 1, color: AppColors.dividerSoft);

  Widget _menu(
    String title,
    String? subtitle,
    String icon,
    VoidCallback onTap, {
    Key? key,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: key,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsets.only(left: 16, right: 12),
            child: Row(children: [
              Container(
                width: AppSizes.iconTile,
                height: AppSizes.iconTile,
                decoration: BoxDecoration(
                  color: AppColors.brandTint,
                  borderRadius: BorderRadius.circular(AppRadius.field),
                ),
                child: Center(child: ProfileIcon(icon)),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title,
                        style: AppTextStyles.heading,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppTextStyles.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const SizedBox(
                  width: 24, height: 24, child: ProfileIcon('h-chevron-right')),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Thẻ hồ sơ của Figma S08: nền `#E7F3F1`, bo 16, cao 88, nút sửa 48 trắng.
class _ProfileCard extends StatelessWidget {
  const _ProfileCard(
      {required this.name, required this.phone, required this.onEdit});
  final String name;
  final String phone;
  final VoidCallback onEdit;
  @override
  Widget build(BuildContext context) => Container(
        key: const Key('profile-card'),
        constraints: const BoxConstraints(minHeight: 88),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.brandTint,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Row(children: [
          const ProfileAvatar(size: 56),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(name,
                      style: AppTextStyles.heading,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(phone,
                      style: AppTextStyles.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ]),
          ),
          Container(
            decoration: const BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                boxShadow: AppShadows.cardElevation),
            child: IconButton(
              tooltip: 'Sửa thông tin cá nhân',
              onPressed: onEdit,
              icon: const ProfileIcon('h-pencil'),
              style: IconButton.styleFrom(
                fixedSize: const Size(AppSizes.tapTarget, AppSizes.tapTarget),
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ]),
      );
}
