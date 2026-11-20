import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/utils/app_assets.dart';
import '../../profile/presentation/state/profile_controller.dart';
import '../../profile/presentation/widgets/profile_notices.dart';
import '../../adherence_history/presentation/utils/adherence_history_format.dart';
import 'home_schedule_controller.dart';
import 'scene/banner_chip.dart';
import 'scene/greeting_name.dart';
import 'scene/home_pet_signals.dart';
import 'scene/living_banner.dart';
import 'widgets/home_dose_timeline.dart';
import '../../meal_suggestion/presentation/widgets/today_menu_row.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen(
      {super.key,
      required this.active,
      required this.onFamily,
      required this.onSchedule});
  final bool active;
  final VoidCallback onFamily;
  final VoidCallback onSchedule;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  bool _started = false;
  Timer? _clockTick;
  DateTime? _day;
  int? _accessRevision;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final revision = HomeScheduleScope.maybeOf(context)?.accessRevision;
    if (_accessRevision != null &&
        _accessRevision != revision &&
        widget.active) {
      _load();
    }
    _accessRevision = revision;
  }

  DateTime _now() =>
      HomeScheduleScope.maybeOf(context)?.clock() ?? DateTime.now();

  void _scheduleTick() {
    _clockTick?.cancel();
    if (!widget.active) return;
    final now = _now();
    _day = HistoryFormat.today(now);
    _clockTick = Timer(
        Duration(milliseconds: 60000 - now.millisecondsSinceEpoch % 60000), () {
      if (!mounted || !widget.active) return;
      final changedDay = _day != HistoryFormat.today(_now());
      setState(() {});
      if (changedDay) _load();
      _scheduleTick();
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.active) _load();
  }

  void _load() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.active) return;
      setState(() => _started = true);
      ProfileScope.read(context).load();
      unawaited(HomeScheduleScope.maybeOf(context)?.load());
      _scheduleTick();
    });
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _load();
    if (!widget.active) _clockTick?.cancel();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        widget.active &&
        ModalRoute.of(context)?.isCurrent == true) {
      _load();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clockTick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ProfileScope.of(context);
    final loading = !_started || profile.loading;
    final name =
        profile.error == null ? profile.profile?.fullName?.trim() : null;
    final schedule = HomeScheduleScope.maybeOf(context);
    final now = _now();
    final signals = HomePetSignals.from(schedule, now);
    final summary = schedule?.day?.summary;
    final chips = <Widget>[
      if (loading) ...const [
        _Placeholder(width: 90, height: 30),
        _Placeholder(width: 140, height: 30),
      ] else if (schedule != null && !schedule.failed) ...[
        if (signals.pending)
          const BannerChip(
              icon: LucideIcons.cloud,
              label: 'Đang chờ đồng bộ',
              tint: Color(0xFF1B9AFC))
        else if (signals.allDone)
          const BannerChip(
              icon: LucideIcons.check, label: 'Xong hôm nay', progress: 1)
        else if (summary != null)
          BannerChip(
              icon: LucideIcons.check,
              label: '${summary.taken + summary.late}/${summary.total} liều',
              progress: summary.total == 0
                  ? 0
                  : (summary.taken + summary.late) / summary.total)
        else if (!schedule.loading)
          const BannerChip(
              icon: LucideIcons.sparkles,
              label: 'Bắt đầu nào!',
              tint: Color(0xFFF57C00)),
        if ((schedule.streak ?? 0) > 0)
          BannerChip(
              icon: LucideIcons.flame,
              label: '${schedule.streak} ngày liên tục',
              tint: const Color(0xFFF57C00)),
      ],
    ];
    final banner = LivingBanner(
      now: now,
      signals: signals,
      active: widget.active,
      height: HomeLayout.bannerHeight,
      showPet: !loading && profile.error == null,
      sheetColor: _sheet,
      title: (context, ink, at) => loading
          ? const _Placeholder(width: 220, height: 30)
          : GreetingTitle(
              greetingLine(homeGreeting(at).text, name),
              ink: ink,
              night: homeGreeting(at).night,
            ),
      trailing: Material(
          color: Colors.white,
          shape: const CircleBorder(),
          child: IconButton(
              key: const Key('home-notification-bell'),
              tooltip: 'Thông báo',
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.profileNotifications),
              icon: const Icon(LucideIcons.bell, color: AppColors.brand))),
      chips: chips,
    );
    // Banner, shortcuts and the "Lịch hôm nay" header stay put; only the day's doses scroll
    // (N6, AC6). The banner no longer collapses, so its chips are never clipped (N9).
    return ColoredBox(
      color: _sheet,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        banner,
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: Row(children: [
            Expanded(
                child: _Shortcut(
                    label: 'Thêm thuốc',
                    icon: LucideIcons.pill,
                    onTap: () => _openMedication(AppRoutes.addMedication))),
            const SizedBox(width: 10),
            Expanded(
                child: _Shortcut(
                    label: 'Dumi AI',
                    image: AppAssets.mascotCooking,
                    onTap: () => Navigator.pushNamed(
                        context, AppRoutes.mealSuggestion))),
            const SizedBox(width: 10),
            Expanded(
                child: _Shortcut(
                    label: 'Người thân',
                    icon: LucideIcons.usersRound,
                    onTap: widget.onFamily)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 8, 0),
          child: Row(children: [
            const Expanded(
                child: Text('Lịch hôm nay',
                    key: Key('home-today-header'),
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
            TextButton(
                onPressed: widget.onSchedule, child: const Text('Xem lịch ›'))
          ]),
        ),
        Expanded(
          child: HomeScrollArea(
            color: _sheet,
            child: ListView(
              key: const Key('home-dose-list'),
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
              children: [
                if (profile.error != null) const ProfileNotices(),
                if (loading || schedule?.loading == true)
                  Semantics(
                      label: 'Đang tải trang chủ',
                      child: const Column(children: [
                        SizedBox(height: 12),
                        _SkeletonCard(),
                        SizedBox(height: 12),
                        _SkeletonCard(),
                        SizedBox(height: 12),
                        _SkeletonCard(tall: true)
                      ]))
                else if (schedule != null)
                  HomeDoseTimeline(
                    controller: schedule,
                    now: now,
                    onAdd: () => _openMedication(AppRoutes.addMedication),
                    onScan: () => _openMedication(AppRoutes.scanMedication),
                  ),
                // Món đã chọn hôm nay (Dumi AI); ẩn khi chưa chọn món nào.
                const TodayMenuRow(),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  static const _sheet = Color(0xFFF6F7F5);

  Future<void> _openMedication(String route) async {
    await Navigator.pushNamed(context, route);
    if (mounted && widget.active) _load();
  }
}

/// Fixed home layout constants shared by both home screens.
abstract final class HomeLayout {
  /// Banner height without the status bar (was 260 and collapsing; Q3: a little lower).
  static const bannerHeight = 236.0;
}

/// Scrolling area under the fixed header: a soft shadow appears on its top edge once the
/// list has scrolled, so the fixed header reads as lifted above the content.
class HomeScrollArea extends StatefulWidget {
  const HomeScrollArea({super.key, required this.child, required this.color});
  final Widget child;
  final Color color;

  @override
  State<HomeScrollArea> createState() => _HomeScrollAreaState();
}

class _HomeScrollAreaState extends State<HomeScrollArea> {
  bool _scrolled = false;

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollNotification>(
        onNotification: (n) {
          final scrolled = n.metrics.pixels > 0.5;
          if (n.depth == 0 && scrolled != _scrolled) {
            setState(() => _scrolled = scrolled);
          }
          return false;
        },
        child: Stack(children: [
          Positioned.fill(child: widget.child),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 14,
            child: IgnorePointer(
              child: AnimatedOpacity(
                key: const Key('home-scroll-shadow'),
                opacity: _scrolled ? 1 : 0,
                duration: const Duration(milliseconds: 150),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFF0B2A26).withValues(alpha: .10),
                        widget.color.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ]),
      );
}

class _Shortcut extends StatelessWidget {
  const _Shortcut(
      {required this.label, required this.onTap, this.icon, this.image});
  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final String? image;
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        elevation: 2,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
              child: Column(children: [
                Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                        color: const Color(0xFFFFF0DF),
                        borderRadius: BorderRadius.circular(12)),
                    child: image == null
                        ? icon == LucideIcons.pill
                            ? const _OrangePill()
                            : Icon(icon, color: AppColors.brand, size: 30)
                        : Image.asset(image!, fit: BoxFit.contain)),
                const SizedBox(height: 4),
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15))
              ]),
            )),
      );
}

class _OrangePill extends StatelessWidget {
  const _OrangePill();

  @override
  Widget build(BuildContext context) => Center(
        child: SizedBox.square(
          dimension: 30,
          child: Stack(alignment: Alignment.center, children: [
            Transform.rotate(
              angle: -math.pi / 4,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: const SizedBox(
                  width: 23,
                  height: 11,
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: ColoredBox(color: Color(0xFFFFAC56))),
                        Expanded(child: ColoredBox(color: Color(0xFFF9FAFA))),
                      ]),
                ),
              ),
            ),
            const Icon(LucideIcons.pill, size: 30, color: Color(0xFF17396F)),
          ]),
        ),
      );
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.width, required this.height});
  final double width;
  final double height;
  @override
  Widget build(BuildContext context) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
          color: const Color(0xFFE4E8E6),
          borderRadius: BorderRadius.circular(12)));
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({this.tall = false});
  final bool tall;
  @override
  Widget build(BuildContext context) => Container(
        height: tall ? 160 : 64,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(14)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _Placeholder(width: 45, height: 45),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Container(
                    height: 14,
                    width: double.infinity,
                    decoration: BoxDecoration(
                        color: const Color(0xFFE4E8E6),
                        borderRadius: BorderRadius.circular(8))),
                const SizedBox(height: 8),
                const _Placeholder(width: 120, height: 14)
              ]))
        ]),
      );
}
