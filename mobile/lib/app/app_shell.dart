import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../features/family_link/presentation/screens/enter_link_code_screen.dart';
import '../features/adherence_history/presentation/screens/adherence_history_screen.dart';
import '../features/family_link/presentation/screens/family_tab_screen.dart';
import '../features/family_link/presentation/state/family_link_scope.dart';
import '../features/family_link/presentation/state/incoming_requests_controller.dart';
import '../features/family_link/presentation/state/invite_link_controller.dart';
import '../features/medication/presentation/screens/my_medications_screen.dart';
import '../features/medication/presentation/state/medication_controller.dart';
import '../features/profile/presentation/state/profile_controller.dart';
import '../features/profile/presentation/screens/profile_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/home/presentation/screens/home_screen.dart' as empty;
import '../features/auth/presentation/widgets/welcome_onboarding_sheet.dart';
import 'router.dart';
import '../core/preview/app_preview_scope.dart';
import 'theme/app_theme.dart';

enum AppTab { home, medications, reminders, family, profile }

/// Khung chính với thanh điều hướng dưới dùng chung.
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    this.initialTab = AppTab.home,
    this.showWelcome = false,
  });

  final AppTab initialTab;
  final bool showWelcome;

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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final profile =
          context.getInheritedWidgetOfExactType<ProfileScope>()?.notifier;
      if (profile != null) unawaited(profile.load());
      if (widget.showWelcome && _tab == AppTab.home) {
        _refreshPendingRequests();
        await showWelcomeOnboardingSheet(
          context,
          onSetup: () =>
              Navigator.of(context).pushNamed(AppRoutes.healthProfileIntro),
        );
      }
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && identical(requests, _incomingRequests)) {
          _refreshPendingRequests();
        }
      });
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
    final requests =
        _incomingRequests ?? FamilyLinkScope.maybeOf(context)?.incomingRequests;
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
    final medications =
        context.dependOnInheritedWidgetOfExactType<MedicationScope>()?.notifier;
    final profile =
        context.dependOnInheritedWidgetOfExactType<ProfileScope>()?.notifier;
    final useExistingHome = profile?.error != null ||
        (medications != null &&
            medications.hasLoaded &&
            medications.loadError == null &&
            medications.medications.isNotEmpty);
    return Scaffold(
      backgroundColor:
          _tab == AppTab.profile ? ProfileScreen.canvasColor : null,
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
          if (useExistingHome)
            HomeScreen(
              active: _tab == AppTab.home,
              onFamily: () => _select(AppTab.family),
              onSchedule: () => _select(AppTab.reminders),
            )
          else
            empty.HomeScreen(
              displayName: profile?.profile?.fullName,
              onFamily: () => _select(AppTab.family),
              onMedications: () => _select(AppTab.medications),
            ),
          const MyMedicationsScreen(),
          AdherenceHistoryScreen(active: _tab == AppTab.reminders),
          FamilyTabScreen(active: _tab == AppTab.family),
          ProfileScreen(active: _tab == AppTab.profile),
        ],
      ),
      bottomNavigationBar: ListenableBuilder(
        listenable: _incomingRequests ?? _emptyNotifier,
        builder: (context, _) {
          final navBar = Container(
            margin: EdgeInsets.fromLTRB(
                12, 0, 12, MediaQuery.paddingOf(context).bottom + 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x2401554F),
                    blurRadius: 24,
                    offset: Offset(0, 8))
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: NavigationBarTheme(
                data: NavigationBarThemeData(
                  backgroundColor: Colors.white,
                  indicatorColor: Colors.transparent,
                  iconTheme:
                      WidgetStateProperty.resolveWith((states) => IconThemeData(
                            color: states.contains(WidgetState.selected)
                                ? const Color(0xFF0B5A8A)
                                : AppColors.inkMuted,
                            size: 25,
                          )),
                  labelTextStyle:
                      WidgetStateProperty.resolveWith((states) => TextStyle(
                            color: states.contains(WidgetState.selected)
                                ? const Color(0xFF0B5A8A)
                                : AppColors.inkMuted,
                            fontSize: 12,
                            fontWeight: states.contains(WidgetState.selected)
                                ? FontWeight.w600
                                : FontWeight.w500,
                          )),
                ),
                // Lề dưới của container đã tính khoảng thanh cử chỉ hệ thống; bỏ phần đệm
                // đáy mà NavigationBar tự thêm (SafeArea bên trong), nếu không thanh bị
                // cộng hai lần và hở một khoảng dưới icon.
                child: MediaQuery.removePadding(
                  context: context,
                  removeBottom: true,
                  child: NavigationBar(
                    height: 68,
                    labelBehavior:
                        NavigationDestinationLabelBehavior.alwaysHide,
                    selectedIndex: switch (_tab) {
                      AppTab.home || AppTab.family => 0,
                      AppTab.medications => 1,
                      AppTab.reminders => 2,
                      AppTab.profile => 3,
                    },
                    onDestinationSelected: (i) => _select([
                      AppTab.home,
                      AppTab.medications,
                      AppTab.reminders,
                      AppTab.profile
                    ][i]),
                    destinations: const [
                      NavigationDestination(
                        icon: Icon(LucideIcons.house),
                        selectedIcon: _SelectedNavigationIcon(
                            icon: LucideIcons.house,
                            label: 'Trang chủ',
                            align: Alignment.centerLeft),
                        label: 'Trang chủ',
                      ),
                      NavigationDestination(
                        icon: Icon(LucideIcons.pill),
                        selectedIcon: _SelectedNavigationIcon(
                            icon: LucideIcons.pill, label: 'Thuốc'),
                        label: 'Thuốc',
                      ),
                      NavigationDestination(
                        icon: Icon(LucideIcons.calendarClock),
                        selectedIcon: _SelectedNavigationIcon(
                            icon: LucideIcons.calendarClock,
                            label: 'Lịch nhắc'),
                        label: 'Lịch nhắc',
                      ),
                      NavigationDestination(
                        icon: Icon(LucideIcons.userRound),
                        selectedIcon: _SelectedNavigationIcon(
                            icon: LucideIcons.userRound,
                            label: 'Hồ sơ',
                            align: Alignment.centerRight),
                        label: 'Hồ sơ',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          // The outer margin already accounts for the system inset on S08.
          return _tab == AppTab.profile
              ? MediaQuery.removePadding(
                  context: context, removeBottom: true, child: navBar)
              : navBar;
        },
      ),
    );
  }
}

/// Viên chọn của tab đang mở: co theo nội dung (icon + nhãn), không cắt chữ.
///
/// [align] giữ viên trong thanh ở hai đầu: tab đầu căn trái, tab cuối căn phải
/// so với ô icon, để phần tràn của viên đi vào trong thay vì ra ngoài thanh.
class _SelectedNavigationIcon extends StatelessWidget {
  const _SelectedNavigationIcon(
      {required this.icon, required this.label, this.align = Alignment.center});
  final IconData icon;
  final String label;
  final Alignment align;

  @override
  Widget build(BuildContext context) => OverflowBox(
        alignment: align,
        maxWidth: 150,
        maxHeight: 52,
        child: Container(
          key: ValueKey('selected-nav-$label'),
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFD9EEFC),
            borderRadius: BorderRadius.circular(26),
          ),
          // vừa chỗ thì giữ nguyên cỡ; thiếu chỗ (chữ hệ thống to) thì thu nhỏ cả cụm, không cắt chữ
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, color: const Color(0xFF0B5A8A), size: 24),
              const SizedBox(width: 8),
              Text(label,
                  key: ValueKey('selected-nav-label-$label'),
                  maxLines: 1,
                  softWrap: false,
                  style: const TextStyle(
                      color: Color(0xFF0B5A8A),
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      );
}
