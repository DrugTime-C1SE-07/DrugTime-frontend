import 'package:flutter/material.dart';
import '../../../../app/router.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/coming_soon_view.dart';
import '../../../auth/presentation/state/auth_controller.dart';
import '../state/profile_controller.dart';
import '../widgets/profile_avatar.dart';
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
              const Expanded(child: Text('Hồ sơ', style: AppTextStyles.title)),
              PopupMenuButton<String>(
                tooltip: 'Cài đặt hồ sơ',
                icon: const ProfileIcon('h-settings'),
                iconSize: 18,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surfaceMuted,
                  fixedSize: const Size(36, 36),
                  padding: EdgeInsets.zero,
                ),
                onSelected: (value) {
                  if (value == 'catalog') {
                    _open(AppRoutes.devCatalog);
                  } else if (value == 'logout') {
                    AuthScope.read(context).signOut();
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'catalog', child: Text('UI Catalog')),
                  PopupMenuItem(value: 'logout', child: Text('Đăng xuất')),
                ],
              ),
            ]),
            const SizedBox(height: 16),
            const ProfileNotices(),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.brandTint,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(children: [
                const ProfileAvatar(size: 56),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    c.profile?.fullName ?? 'Chưa cung cấp',
                    style: AppTextStyles.bodyStrong,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: 'Sửa thông tin cá nhân',
                  onPressed: () => _open(AppRoutes.personalProfile),
                  icon: const ProfileIcon('h-pencil'),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.surface,
                    fixedSize: const Size(36, 36),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(children: [
                _menu(
                  'Thông tin cá nhân',
                  'Ngày sinh, giới tính',
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
                  () => _openComingSoon('Người giám sát', Icons.people_outline),
                  key: const Key('supervisors-tile'),
                ),
                _divider(),
                _menu(
                  'Thông báo & Nhắc nhở',
                  null,
                  'h-bell',
                  () => _openComingSoon(
                      'Thông báo & Nhắc nhở', Icons.notifications_none),
                  key: const Key('notifications-tile'),
                ),
                _divider(),
                _menu(
                  'Quyền riêng tư & Bảo mật',
                  null,
                  'h-shield',
                  () => _open(AppRoutes.privacySettings),
                  key: const Key('privacy-settings-tile'),
                ),
                _divider(),
                _menu(
                  'Trợ giúp',
                  null,
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

  Widget _divider() => const Divider(height: 1, indent: 0, endIndent: 0);

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
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: 16, vertical: subtitle == null ? 12 : 10),
          child: Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: AppColors.brandTint,
                shape: BoxShape.circle,
              ),
              child: Center(child: ProfileIcon(icon)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: AppTextStyles.body.copyWith(fontSize: 14)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTextStyles.caption.copyWith(fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            const ProfileIcon('h-chevron-right'),
          ]),
        ),
      ),
    );
  }
}
