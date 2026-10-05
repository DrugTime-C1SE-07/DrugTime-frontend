import 'package:flutter/material.dart';

import '../features/medication/presentation/screens/my_medications_screen.dart';
import '../shared/widgets/coming_soon_view.dart';
import '../shared/widgets/pill_icon.dart';
import '../features/auth/presentation/state/auth_controller.dart';
import 'router.dart';
import 'theme/app_theme.dart';

enum AppTab { home, medications, reminders, family, profile }

/// Khung chính với thanh điều hướng dưới 5 tab.
class AppShell extends StatefulWidget {
  const AppShell({super.key, this.initialTab = AppTab.medications});

  final AppTab initialTab;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late AppTab _tab = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab.index,
        children: [
          const ComingSoonView(title: 'Trang chủ', icon: Icons.home_outlined),
          const MyMedicationsScreen(),
          const ComingSoonView(title: 'Lịch nhắc', icon: Icons.calendar_month_outlined),
          const ComingSoonView(title: 'Người thân', icon: Icons.people_outline),
          _buildProfileTab(context),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: NavigationBar(
          selectedIndex: _tab.index,
          onDestinationSelected: (i) => setState(() => _tab = AppTab.values[i]),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Trang chủ',
            ),
            NavigationDestination(
              icon: PillIcon(color: AppColors.inkMuted),
              selectedIcon: PillIcon(color: AppColors.brand),
              label: 'Thuốc',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month),
              label: 'Lịch nhắc',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people),
              label: 'Người thân',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Hồ sơ',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileTab(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hồ sơ & Cài đặt'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.card),
              side: const BorderSide(color: AppColors.border),
            ),
            color: AppColors.brandTint,
            child: ListTile(
              leading: const Icon(Icons.developer_mode, color: AppColors.brand),
              title: const Text(
                'UI Catalog (Duyệt tất cả màn hình)',
                style: AppTextStyles.bodyStrong,
              ),
              subtitle: const Text(
                'Mở danh mục chọn màn hình để kiểm tra UI nhanh',
                style: AppTextStyles.caption,
              ),
              trailing: const Icon(Icons.chevron_right, color: AppColors.brand),
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.devCatalog),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.card),
              side: const BorderSide(color: AppColors.border),
            ),
            color: AppColors.surface,
            child: ListTile(
              leading: const Icon(Icons.login, color: AppColors.ink),
              title: const Text(
                'S00c · Màn hình Đăng nhập (OTP)',
                style: AppTextStyles.bodyStrong,
              ),
              subtitle: const Text(
                'Mở trực tiếp màn hình đăng nhập S00c',
                style: AppTextStyles.caption,
              ),
              trailing: const Icon(Icons.chevron_right, color: AppColors.inkMuted),
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.login),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.card),
              side: const BorderSide(color: AppColors.border),
            ),
            color: AppColors.surface,
            child: ListTile(
              key: const Key('privacy-settings-tile'),
              leading: const Icon(Icons.privacy_tip_outlined, color: AppColors.ink),
              title: const Text('Quyền riêng tư', style: AppTextStyles.bodyStrong),
              subtitle: const Text(
                'Xem và thay đổi đồng ý xử lý dữ liệu theo từng mục đích',
                style: AppTextStyles.caption,
              ),
              trailing: const Icon(Icons.chevron_right, color: AppColors.inkMuted),
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.privacySettings),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.card),
              side: const BorderSide(color: AppColors.border),
            ),
            color: AppColors.surface,
            child: ListTile(
              key: const Key('logout-tile'),
              leading: const Icon(Icons.logout, color: AppColors.danger),
              title: const Text('Đăng xuất', style: AppTextStyles.bodyStrong),
              subtitle: const Text(
                'Xóa phiên đăng nhập trên thiết bị này',
                style: AppTextStyles.caption,
              ),
              // App lắng nghe trạng thái đăng nhập và tự chuyển về màn Đăng nhập.
              onTap: () => AuthScope.read(context).signOut(),
            ),
          ),
        ],
      ),
    );
  }
}
