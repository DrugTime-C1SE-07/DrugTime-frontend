import 'dart:async';

import 'package:flutter/material.dart';

import '../features/family_link/presentation/screens/enter_link_code_screen.dart';
import '../features/adherence_history/presentation/screens/adherence_history_screen.dart';
import '../features/family_link/presentation/screens/family_tab_screen.dart';
import '../features/family_link/presentation/state/family_link_scope.dart';
import '../features/family_link/presentation/state/incoming_requests_controller.dart';
import '../features/family_link/presentation/state/invite_link_controller.dart';
import '../features/medication/presentation/screens/my_medications_screen.dart';
import '../features/profile/presentation/screens/profile_screen.dart';
import '../shared/widgets/coming_soon_view.dart';
import '../shared/widgets/pill_icon.dart';
import 'router.dart';
import '../core/preview/app_preview_scope.dart';
import 'theme/app_theme.dart';

enum AppTab { home, medications, reminders, family, profile }

/// Khung chính với thanh điều hướng dưới 5 tab.
class AppShell extends StatefulWidget {
  const AppShell({super.key, this.initialTab = AppTab.medications});

  final AppTab initialTab;

  /// Chuyển sang [tab] từ một màn nằm trong shell. Không có shell phía trên (màn mở bằng route
  /// riêng) thì không làm gì.
  static void showTab(BuildContext context, AppTab tab) =>
      context.findAncestorStateOfType<_AppShellState>()?._select(tab);

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  late AppTab _tab = widget.initialTab;
  InviteLinkController? _invites;
  IncomingRequestsController? _incomingRequests;
  final ChangeNotifier _emptyNotifier = ChangeNotifier();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Shell chỉ dựng khi đã đăng nhập và qua cổng consent: link mời mở app trước đó (kể cả
    // trước khi đăng nhập) được xử lý tại đây.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _invites = FamilyLinkScope.read(context).invites
        ..addListener(_openPendingInvite);
      _openPendingInvite();
      _refreshPendingRequests();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final requests = FamilyLinkScope.maybeOf(context)?.incomingRequests;
    if (requests != _incomingRequests) {
      _incomingRequests = requests;
      _refreshPendingRequests();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshPendingRequests();
    }
  }

  void _refreshPendingRequests() {
    if (!mounted) return;
    final requests = _incomingRequests ?? FamilyLinkScope.maybeOf(context)?.incomingRequests;
    if (requests != null) {
      _incomingRequests = requests;
      unawaited(requests.load());
    }
  }

  /// Mở màn nhập mã đã điền sẵn; link mời không bao giờ tự gửi yêu cầu.
  void _openPendingInvite() {
    final invite = _invites?.take();
    if (invite == null || !mounted) return;
    setState(() => _tab = AppTab.family);
    unawaited(Navigator.of(context).pushNamed(
      AppRoutes.familyEnterCode,
      arguments: EnterLinkCodeArgs(
        initialCode: invite.code,
        invalidLink: invite.code == null,
      ),
    ));
  }

  void _select(AppTab tab) {
    if (mounted) setState(() => _tab = tab);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _invites?.removeListener(_openPendingInvite);
    _emptyNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          AppPreviewScope.maybeOf(context) != null && _tab != AppTab.reminders
              ? const PreferredSize(
                  preferredSize: Size.fromHeight(28),
                  child: SafeArea(
                      bottom: false,
                      child: Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                              padding: EdgeInsets.only(right: 16),
                              child: AppPreviewBadge()))))
              : null,
      body: IndexedStack(
        index: _tab.index,
        children: [
          const ComingSoonView(title: 'Trang chủ', icon: Icons.home_outlined),
          const MyMedicationsScreen(),
          AdherenceHistoryScreen(active: _tab == AppTab.reminders),
          FamilyTabScreen(active: _tab == AppTab.family),
          ProfileScreen(active: _tab == AppTab.profile),
        ],
      ),
      bottomNavigationBar: ListenableBuilder(
        listenable: _incomingRequests ?? _emptyNotifier,
        builder: (context, _) {
          final pendingCount = _incomingRequests?.pendingCount ?? 0;
          return DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: NavigationBar(
              selectedIndex: _tab.index,
              onDestinationSelected: (i) => _select(AppTab.values[i]),
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Trang chủ',
                ),
                const NavigationDestination(
                  icon: PillIcon(color: AppColors.inkMuted),
                  selectedIcon: PillIcon(color: AppColors.brand),
                  label: 'Thuốc',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.calendar_month_outlined),
                  selectedIcon: Icon(Icons.calendar_month),
                  label: 'Lịch nhắc',
                ),
                NavigationDestination(
                  icon: Badge(
                    isLabelVisible: pendingCount > 0,
                    label: Text('$pendingCount'),
                    child: const Icon(Icons.people_outline),
                  ),
                  selectedIcon: Badge(
                    isLabelVisible: pendingCount > 0,
                    label: Text('$pendingCount'),
                    child: const Icon(Icons.people),
                  ),
                  label: 'Người thân',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Hồ sơ',
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
