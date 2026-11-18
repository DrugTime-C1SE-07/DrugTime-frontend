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
    final top = MediaQuery.paddingOf(context).top;
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
    Widget banner(double shrink) => LivingBanner(
          now: now,
          signals: signals,
          active: widget.active,
          shrink: shrink,
          showPet: !loading && profile.error == null,
          sheetColor: _sheet,
          title: (context, ink, at) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Icon(
                      homeGreeting(at).night
                          ? LucideIcons.moon
                          : LucideIcons.sun,
                      color: ink),
                  const SizedBox(width: 8),
                  Flexible(
                      child: Text(homeGreeting(at).text,
                          style: TextStyle(
                              color: ink,
                              fontSize: 17,
                              fontWeight: FontWeight.w600))),
                ]),
                if (loading)
                  const _Placeholder(width: 130, height: 24)
                else
                  GreetingName(name == null || name.isEmpty ? 'Xin chào' : name,
                      ink: ink),
              ]),
          trailing: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              child: IconButton(
                  tooltip: 'Thông báo',
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Thông báo đang được phát triển'))),
                  icon: const Icon(LucideIcons.bell, color: AppColors.brand))),
          chips: chips,
        );
    return ColoredBox(
      color: _sheet,
      child: CustomScrollView(slivers: [
        SliverPersistentHeader(
            delegate: _BannerHeader(top: top, builder: banner)),
        SliverToBoxAdapter(
          child: Container(
            constraints: BoxConstraints(
                minHeight: (MediaQuery.sizeOf(context).height - top - 310)
                    .clamp(0, double.infinity)),
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
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
              const SizedBox(height: 18),
              Row(children: [
                const Expanded(
                    child: Text('Lịch hôm nay',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold))),
                TextButton(
                    onPressed: widget.onSchedule,
                    child: const Text('Xem lịch ›'))
              ]),
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
            ]),
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

/// Header banner thu từ 260 xuống 140 dp (cộng safe area) khi cuộn.
class _BannerHeader extends SliverPersistentHeaderDelegate {
  _BannerHeader({required this.top, required this.builder});
  final double top;
  final Widget Function(double shrink) builder;

  @override
  double get maxExtent => 260 + top;

  @override
  double get minExtent => 140 + top;

  @override
  Widget build(
          BuildContext context, double shrinkOffset, bool overlapsContent) =>
      builder(math.min(shrinkOffset, maxExtent - minExtent));

  @override
  bool shouldRebuild(_BannerHeader old) => true;
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
