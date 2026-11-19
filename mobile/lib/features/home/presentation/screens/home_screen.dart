import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../app/router.dart';
import '../../../profile/presentation/state/profile_controller.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/app_assets.dart';
import '../../../auth/presentation/widgets/welcome_onboarding_sheet.dart';
import '../../../medication/presentation/state/medication_controller.dart';
import '../../../medication/presentation/widgets/medication_error_messages.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../scene/banner_chip.dart';
import '../scene/greeting_name.dart';
import '../scene/home_pet_signals.dart';
import '../scene/living_banner.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.onFamily,
    required this.onMedications,
    this.displayName,
  });

  final VoidCallback onFamily;
  final VoidCallback onMedications;
  final String? displayName;

  static const _ink = TextStyle(
    fontFamily: 'WelcomeInter',
    color: AppColors.ink,
  );

  static void _add(BuildContext context, {bool scan = false}) =>
      Navigator.of(context)
          .pushNamed(scan ? AppRoutes.scanMedication : AppRoutes.addMedication);

  @override
  Widget build(BuildContext context) {
    final medications =
        context.dependOnInheritedWidgetOfExactType<MedicationScope>()?.notifier;
    final error = medications?.loadError;
    final loading = (context
                .dependOnInheritedWidgetOfExactType<ProfileScope>()
                ?.notifier
                ?.loading ??
            false) ||
        medications == null ||
        medications.isLoading ||
        (!medications.hasLoaded && error == null);
    final emptyHome =
        !loading && error == null && medications.medications.isEmpty;
    final name = displayName?.trim();
    return ColoredBox(
      color: const Color(0xFFF7F8F6),
      child: SingleChildScrollView(
        padding:
            EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LivingBanner(
              signals:
                  HomePetSignals.from(null, DateTime.now(), empty: emptyHome),
              showPet: !loading,
              sheetColor: const Color(0xFFF7F8F6),
              title: (context, ink, at) {
                final greeting = homeGreeting(at);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(children: [
                      Icon(greeting.night ? LucideIcons.moon : LucideIcons.sun,
                          size: 22, color: ink),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          greeting.text,
                          style: _ink.copyWith(
                            color: ink,
                            fontSize: 14,
                            height: 20 / 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 2),
                    GreetingName(
                      name == null || name.isEmpty ? 'Bạn' : name,
                      ink: ink,
                    ),
                  ],
                );
              },
              trailing: IconButton.filled(
                tooltip: 'Thông báo',
                style: IconButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.brand,
                ),
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRoutes.familyAlerts),
                icon: SvgPicture.asset(
                  'assets/icons/welcome/bell.svg',
                  width: 24,
                  height: 24,
                ),
              ),
              chips: [
                if (loading) ...const [
                  _Bone(width: 80, height: 28),
                  _Bone(width: 140, height: 28),
                ] else if (emptyHome)
                  BannerCtaButton(
                    label: 'Bắt đầu nào!',
                    bounce: LivingBanner.autoplay,
                    onPressed: () => showWelcomeOnboardingSheet(
                      context,
                      setupRoute: AppRoutes.healthProfileIntro,
                      onSetup: () => Navigator.of(context)
                          .pushNamed<void>(AppRoutes.healthProfileIntro),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Shortcut(
                          'Thêm thuốc',
                          () => _add(context),
                          SvgPicture.asset('assets/icons/home/capsule.svg',
                              width: 48, height: 48)),
                      const SizedBox(width: 12),
                      _Shortcut(
                          'Dumi AI',
                          () => Navigator.of(context)
                              .pushNamed(AppRoutes.mealSuggestion),
                          Image.asset(AppAssets.mascotCooking,
                              width: 48, height: 48)),
                      const SizedBox(width: 12),
                      _Shortcut(
                          'Người thân',
                          onFamily,
                          SvgPicture.asset('assets/icons/welcome/users.svg',
                              width: 20, height: 20)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('Lịch hôm nay',
                      style: _ink.copyWith(
                          fontSize: 17,
                          height: 24 / 17,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  if (loading)
                    const _HomeSkeleton()
                  else if (error != null) ...[
                    Text(medicationErrorMessage(error)),
                    TextButton(
                      onPressed: medications.load,
                      child: const Text('Thử lại'),
                    ),
                  ] else if (medications.medications.isNotEmpty)
                    OutlinedButton(
                      onPressed: onMedications,
                      child: const Text('Xem danh sách thuốc'),
                    )
                  else
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                                child: SvgPicture.asset(
                              'assets/icons/home/empty-art.svg',
                              width: 96,
                              height: 96,
                            )),
                            const SizedBox(height: 12),
                            Text('Chưa có lịch uống thuốc',
                                textAlign: TextAlign.center,
                                style: _ink.copyWith(
                                    fontSize: 20,
                                    height: 1.4,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 12),
                            Text(
                                'Thêm thuốc đầu tiên để DrugTime nhắc bạn đúng giờ mỗi ngày.',
                                textAlign: TextAlign.center,
                                style: _ink.copyWith(
                                    fontSize: 17,
                                    height: 24 / 17,
                                    color: AppColors.inkMuted)),
                            const SizedBox(height: 12),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 56),
                                elevation: 3,
                                shadowColor: const Color(0x66013D39),
                              ),
                              onPressed: () => _add(context),
                              child: const Text('Thêm thuốc',
                                  style: TextStyle(fontFamily: 'WelcomeInter')),
                            ),
                            const SizedBox(height: 12),
                            FilledButton.tonalIcon(
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 56),
                                backgroundColor: AppColors.brandTint,
                                foregroundColor: AppColors.brand,
                                elevation: 2,
                                shadowColor: const Color(0x40013D39),
                              ),
                              onPressed: () => _add(context, scan: true),
                              icon: SvgPicture.asset(
                                'assets/icons/home/scan.svg',
                                width: 24,
                                height: 24,
                                excludeFromSemantics: true,
                                colorFilter: const ColorFilter.mode(
                                  AppColors.brand,
                                  BlendMode.srcIn,
                                ),
                              ),
                              label: const Text('Quét vỏ hộp',
                                  style: TextStyle(fontFamily: 'WelcomeInter')),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut(this.label, this.onPressed, this.icon);
  final String label;
  final VoidCallback onPressed;
  final Widget icon;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Material(
          color: Colors.white,
          elevation: 1,
          shadowColor: const Color(0x591C2024),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 84),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 7),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDF0E1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: icon,
                    ),
                    const SizedBox(height: 3),
                    Text(label,
                        textAlign: TextAlign.center,
                        style: HomeScreen._ink
                            .copyWith(fontSize: 15, height: 20 / 15)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

class _Bone extends StatelessWidget {
  const _Bone({this.width, required this.height});
  final double? width;
  final double height;
  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFE4E8E6),
          borderRadius: BorderRadius.circular(12),
        ),
      );
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();
  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Đang tải lịch uống thuốc',
        child: Column(children: [
          for (final tall in [false, false, true])
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                    width: 30,
                    child: Column(children: [
                      Container(
                          width: 2, height: 20, color: const Color(0xFFE4E8E6)),
                      Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                              color: Color(0xFFE4E8E6),
                              shape: BoxShape.circle)),
                      Container(
                          width: 2,
                          height: tall ? 134 : 32,
                          color: const Color(0xFFE4E8E6)),
                    ])),
                Expanded(
                    child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16)),
                  child: Column(children: [
                    Row(children: [
                      const _Bone(width: 48, height: 48),
                      const SizedBox(width: 12),
                      const Expanded(
                          child: Column(children: [
                        _Bone(height: 14),
                        SizedBox(height: 8),
                        _Bone(height: 16),
                      ])),
                      if (!tall) ...[
                        const SizedBox(width: 8),
                        const Flexible(child: _Bone(width: 96, height: 48)),
                      ],
                    ]),
                    if (tall) ...[
                      const SizedBox(height: 12),
                      const _Bone(height: 16, width: 140),
                      const SizedBox(height: 12),
                      const _Bone(height: 56, width: double.infinity),
                    ],
                  ]),
                )),
              ]),
            ),
        ]),
      );
}
