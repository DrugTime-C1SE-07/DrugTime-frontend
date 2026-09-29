import 'package:flutter/material.dart';

import '../features/medication/presentation/screens/my_medications_screen.dart';
import '../shared/widgets/coming_soon_view.dart';
import '../shared/widgets/pill_icon.dart';
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
        children: const [
          ComingSoonView(title: 'Trang chủ', icon: Icons.home_outlined),
          MyMedicationsScreen(),
          ComingSoonView(title: 'Lịch nhắc', icon: Icons.calendar_month_outlined),
          ComingSoonView(title: 'Người thân', icon: Icons.people_outline),
          ComingSoonView(title: 'Hồ sơ', icon: Icons.person_outline),
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
}
