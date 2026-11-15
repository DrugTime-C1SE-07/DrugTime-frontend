import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/utils/app_assets.dart';
import '../../profile/presentation/state/profile_controller.dart';
import '../../profile/presentation/widgets/profile_notices.dart';

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
    });
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        widget.active &&
        ModalRoute.of(context)?.isCurrent == true) _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ProfileScope.of(context);
    final loading = !_started || profile.loading;
    final name =
        profile.error == null ? profile.profile?.fullName?.trim() : null;
    final hour = DateTime.now().toUtc().add(const Duration(hours: 7)).hour;
    final greeting = hour < 12
        ? 'Chào buổi sáng'
        : hour < 18
            ? 'Chào buổi chiều'
            : 'Chào buổi tối';
    return ColoredBox(
      color: const Color(0xFFA1DDCB),
      child: ListView(padding: EdgeInsets.zero, children: [
        Container(
          height: 220 + MediaQuery.paddingOf(context).top,
          decoration: const BoxDecoration(color: Color(0xFFFFDDB7)),
          child: Stack(children: [
            Positioned(
                right: 85,
                top: 6,
                child: Container(
                    width: 140,
                    height: 140,
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle, color: Color(0xFFFFD89B)),
                    child: Center(
                        child: Container(
                            width: 70,
                            height: 70,
                            decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFFFFB33E)))))),
            Positioned(
                left: -30,
                right: -30,
                bottom: -72,
                child: Container(
                    height: 115,
                    decoration: const BoxDecoration(
                        color: Color(0xFFA1DDCB),
                        borderRadius: BorderRadius.vertical(
                            top: Radius.elliptical(250, 70))))),
            Positioned(
                left: 20,
                right: 20,
                top: MediaQuery.paddingOf(context).top + 18,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(LucideIcons.sun, color: Color(0xFFB45608)),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(greeting,
                                style: const TextStyle(
                                    color: Color(0xFF9E3512),
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
                            style: const TextStyle(
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
                            ])),
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
                      onTap: () => Navigator.pushNamed(
                          context, AppRoutes.scanMedication))),
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
            if (loading)
              Semantics(
                  label: 'Đang tải trang chủ',
                  child: const Column(children: [
                    SizedBox(height: 12),
                    _SkeletonCard(),
                    SizedBox(height: 12),
                    _SkeletonCard(),
                    SizedBox(height: 12),
                    _SkeletonCard(tall: true)
                  ])),
          ]),
        ),
      ]),
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
