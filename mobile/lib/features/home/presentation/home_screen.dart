import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/utils/app_assets.dart';
import '../../profile/presentation/state/profile_controller.dart';
import '../../profile/presentation/widgets/profile_notices.dart';
import '../../adherence_history/domain/entities/adherence_history.dart';
import '../../adherence_history/presentation/utils/adherence_history_format.dart';
import 'home_schedule_controller.dart';

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
    final hour = HistoryFormat.vietnam(now).hour;
    final morning = hour < 11;
    final night = hour >= 18;
    final sky = night
        ? const Color(0xFF292357)
        : morning
            ? const Color(0xFFFFDDB7)
            : const Color(0xFFCEEAFB);
    final halo = night
        ? const Color(0xFF403B70)
        : morning
            ? const Color(0xFFFFD89B)
            : const Color(0xFFE6EED6);
    final celestial = night
        ? const Color(0xFFFFEDA8)
        : morning
            ? const Color(0xFFFFB33E)
            : const Color(0xFFFFDE69);
    final hill = night ? const Color(0xFF307971) : const Color(0xFFA1DDCB);
    final ink = night ? Colors.white : const Color(0xFF19231F);
    final greeting = morning
        ? 'Chào buổi sáng'
        : night
            ? 'Chào buổi tối'
            : 'Chào buổi trưa';
    final summary = schedule?.day?.summary;
    return ColoredBox(
      color: hill,
      child: ListView(padding: EdgeInsets.zero, children: [
        Container(
          height: 220 + MediaQuery.paddingOf(context).top,
          decoration: BoxDecoration(color: sky),
          child: Stack(children: [
            Positioned(
                right: 85,
                top: 6,
                child: Container(
                    width: 140,
                    height: 140,
                    decoration:
                        BoxDecoration(shape: BoxShape.circle, color: halo),
                    child: Center(
                        child: Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: night ? Colors.transparent : celestial),
                            child: night
                                ? Icon(LucideIcons.moon,
                                    size: 70, color: celestial)
                                : null)))),
            Positioned(
                left: -30,
                right: -30,
                bottom: -72,
                child: Container(
                    height: 115,
                    decoration: BoxDecoration(
                        color: hill,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.elliptical(250, 70))))),
            Positioned(
                left: 20,
                right: 20,
                top: MediaQuery.paddingOf(context).top + 18,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(night ? LucideIcons.moon : LucideIcons.sun,
                            color: ink),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(greeting,
                                style: TextStyle(
                                    color: ink,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600))),
                        Material(
                            color: Colors.white,
                            shape: const CircleBorder(),
                            child: IconButton(
                                tooltip: 'Thông báo',
                                onPressed: () => ScaffoldMessenger.of(context)
                                    .showSnackBar(const SnackBar(
                                        content: Text(
                                            'Thông báo đang được phát triển'))),
                                icon: const Icon(LucideIcons.bell,
                                    color: AppColors.brand)))
                      ]),
                      if (loading)
                        const _Placeholder(width: 130, height: 24)
                      else
                        Text(name == null || name.isEmpty ? 'Xin chào' : name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: ink,
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                                height: 1.15)),
                      if (loading)
                        const Padding(
                            padding: EdgeInsets.only(top: 18),
                            child: Row(children: [
                              _Placeholder(width: 90, height: 30),
                              SizedBox(width: 8),
                              _Placeholder(width: 140, height: 30)
                            ]))
                      else if (schedule != null && !schedule.failed)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Wrap(spacing: 8, runSpacing: 4, children: [
                            if (summary != null)
                              _BannerChip(
                                  '✓ ${summary.taken + summary.late}/${summary.total} liều')
                            else if (!schedule.loading)
                              const _BannerChip('Bắt đầu nào!'),
                            if ((schedule.streak ?? 0) > 0)
                              _BannerChip('${schedule.streak} ngày liên tục'),
                          ]),
                        ),
                    ])),
            if (!loading && profile.error == null)
              Positioned(
                  right: 18,
                  bottom: 4,
                  child: Image.asset(AppAssets.mascotHappy,
                      width: 88, height: 88, fit: BoxFit.contain)),
          ]),
        ),
        Container(
          constraints: BoxConstraints(
              minHeight: (MediaQuery.sizeOf(context).height -
                      MediaQuery.paddingOf(context).top -
                      310)
                  .clamp(0, double.infinity)),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          decoration: const BoxDecoration(
              color: Color(0xFFF6F7F5),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
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
                      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Dumi AI đang được phát triển'))))),
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
                  onPressed: widget.onSchedule, child: const Text('Xem lịch ›'))
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
              _TodaySchedule(
                controller: schedule,
                now: now,
                onAdd: () => _openMedication(AppRoutes.addMedication),
                onScan: () => _openMedication(AppRoutes.scanMedication),
              ),
          ]),
        ),
      ]),
    );
  }

  Future<void> _openMedication(String route) async {
    await Navigator.pushNamed(context, route);
    if (mounted && widget.active) _load();
  }
}

class _BannerChip extends StatelessWidget {
  const _BannerChip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600))),
      );
}

class _TodaySchedule extends StatelessWidget {
  const _TodaySchedule(
      {required this.controller,
      required this.now,
      required this.onAdd,
      required this.onScan});
  final HomeScheduleController controller;
  final DateTime now;
  final VoidCallback onAdd, onScan;

  @override
  Widget build(BuildContext context) {
    if (controller.failed) {
      return Card(
          child: ListTile(
              title: const Text('Không tải được lịch hôm nay'),
              trailing: TextButton(
                  onPressed: controller.load, child: const Text('Thử lại'))));
    }
    final doses = controller.day?.doses ?? const <HistoryDose>[];
    if (doses.isEmpty) {
      return Card(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(
                      child: CircleAvatar(
                          radius: 30,
                          backgroundColor: Color(0xFFE6F3EF),
                          child: _OrangePill())),
                  const SizedBox(height: 12),
                  const Text('Chưa có lịch uống thuốc',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const Text(
                      'Thêm thuốc đầu tiên để DrugTime nhắc bạn đúng giờ mỗi ngày.',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(
                      onPressed: onAdd, child: const Text('Thêm thuốc')),
                  OutlinedButton.icon(
                      onPressed: onScan,
                      icon: const Icon(LucideIcons.scanLine),
                      label: const Text('Quét vỏ hộp')),
                ]),
          ));
    }
    final next = doses
        .where((dose) =>
            HomeScheduleController.canConfirm(dose, now) ||
            (dose.status == HistoryDoseStatus.pending &&
                dose.scheduledAt.isAfter(now)))
        .firstOrNull;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (controller.message != null)
        Text(controller.message!, semanticsLabel: controller.message),
      for (final dose in doses)
        IntrinsicHeight(
            child:
                Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
              width: 28,
              child: Stack(alignment: Alignment.topCenter, children: [
                Container(width: 2, color: const Color(0xFFE0E5E2)),
                Padding(
                    padding: EdgeInsets.only(top: dose == next ? 23 : 15),
                    child: _DoseTimelineMarker(dose: dose, next: dose == next)),
              ])),
          Expanded(
              child: Card(
            elevation: 0,
            color: dose == next ? const Color(0xFFE5F3EF) : Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      const _OrangePill(),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            if (dose == next)
                              const Text('Liều tiếp theo',
                                  style: TextStyle(color: AppColors.brand)),
                            Text(HistoryFormat.time(dose.scheduledAt),
                                style: TextStyle(
                                    fontSize: dose == next ? 24 : 13,
                                    fontWeight: FontWeight.bold)),
                            Text(dose.medicationName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                          ])),
                      if (dose != next)
                        Flexible(
                            child: Text(dose.status.label,
                                style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        dose.status == HistoryDoseStatus.missed
                                            ? Colors.red.shade700
                                            : AppColors.brand))),
                    ]),
                    if (dose == next)
                      FilledButton(
                        onPressed: controller.saving ||
                                controller.isPending(dose) ||
                                !HomeScheduleController.canConfirm(dose, now)
                            ? null
                            : () => controller.confirm(dose),
                        child: Text(controller.isPending(dose)
                            ? 'Đang chờ đồng bộ'
                            : controller.saving
                                ? 'Đang ghi nhận…'
                                : 'Đã uống'),
                      ),
                  ]),
            ),
          )),
        ])),
    ]);
  }
}

class _DoseTimelineMarker extends StatelessWidget {
  const _DoseTimelineMarker({required this.dose, required this.next});

  final HistoryDose dose;
  final bool next;

  @override
  Widget build(BuildContext context) {
    final missed = dose.status == HistoryDoseStatus.missed;
    final taken = dose.status == HistoryDoseStatus.taken ||
        dose.status == HistoryDoseStatus.late;
    const green = Color(0xFF16A052);
    return Container(
      width: missed ? 20 : 24,
      height: missed ? 20 : 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: missed
            ? const Color(0xFFE52429)
            : next
                ? AppColors.brand
                : taken
                    ? const Color(0xFFF0FAF2)
                    : const Color(0xFFF6F7F5),
        border: missed
            ? null
            : Border.all(
                color: next
                    ? const Color(0xFFB3DDD4)
                    : taken
                        ? green
                        : const Color(0xFFCCD8D3),
                width: next ? 2.5 : 2),
      ),
      child: missed
          ? const Icon(Icons.priority_high, size: 12, color: Colors.white)
          : taken
              ? const Icon(LucideIcons.check, size: 13, color: green)
              : next
                  ? const DecoratedBox(
                      decoration: BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle),
                      child: SizedBox.square(dimension: 6))
                  : null,
    );
  }
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
