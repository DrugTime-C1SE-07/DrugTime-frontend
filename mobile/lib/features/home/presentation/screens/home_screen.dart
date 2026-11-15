import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/app_assets.dart';
import '../../../auth/presentation/widgets/welcome_onboarding_sheet.dart';
import '../../../medication/presentation/state/medication_controller.dart';
import '../../../medication/presentation/widgets/medication_error_messages.dart';

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

  static void _message(BuildContext context, String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  static void _add(BuildContext context, {bool scan = false}) =>
      Navigator.of(context).pushNamed(AppRoutes.addMedication, arguments: scan);

  @override
  Widget build(BuildContext context) {
    final medications =
        context.dependOnInheritedWidgetOfExactType<MedicationScope>()?.notifier;
    final error = medications?.loadError;
    final loading = medications == null ||
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
            Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 236,
                  child: SvgPicture.asset(
                    'assets/icons/home/banner.svg',
                    fit: BoxFit.fill,
                    excludeFromSemantics: true,
                  ),
                ),
                const Positioned(
                  top: 212,
                  left: 0,
                  right: 0,
                  height: 48,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0xFFF7F8F6),
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                  ),
                ),
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 8, right: 96),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        SvgPicture.asset(
                                          'assets/icons/home/sun.svg',
                                          width: 24,
                                          height: 24,
                                        ),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            'Chào buổi sáng',
                                            style: _ink.copyWith(
                                              color: const Color(0xFF9A3412),
                                              fontSize: 14,
                                              height: 20 / 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      name == null || name.isEmpty
                                          ? 'Bạn'
                                          : name,
                                      style: _ink.copyWith(
                                        fontSize: 28,
                                        height: 34 / 28,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    if (emptyHome) ...[
                                      const SizedBox(height: 4),
                                      TextButton(
                                        style: TextButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          foregroundColor: AppColors.ink,
                                          minimumSize: const Size(0, 32),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 4),
                                          tapTargetSize:
                                              MaterialTapTargetSize.padded,
                                        ),
                                        onPressed: () =>
                                            showWelcomeOnboardingSheet(
                                          context,
                                          setupRoute:
                                              AppRoutes.healthProfileIntro,
                                          onSetup: () => Navigator.of(context)
                                              .pushNamed<void>(
                                                  AppRoutes.healthProfileIntro),
                                        ),
                                        child: Text(
                                          'Bắt đầu nào!',
                                          style: _ink.copyWith(
                                            fontSize: 14,
                                            height: 20 / 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Align(
                          alignment: Alignment.topRight,
                          child: IconButton.filled(
                            tooltip: 'Thông báo',
                            style: IconButton.styleFrom(
                              minimumSize: const Size(48, 48),
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.brand,
                            ),
                            onPressed: () => Navigator.of(context)
                                .pushNamed(AppRoutes.familyAlerts),
                            icon: SvgPicture.asset(
                              'assets/icons/welcome/bell.svg',
                              width: 24,
                              height: 24,
                            ),
                          ),
                        ),
                        const SizedBox(height: 172),
                        Positioned(
                          right: -5,
                          top: 66,
                          child: IgnorePointer(
                            child: Image.asset(
                              AppAssets.mascotHappy,
                              width: 92,
                              height: 85,
                              excludeFromSemantics: true,
                            ),
                          ),
                        ),
                      ],
                    ),
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
                          () => _message(context, 'Dumi AI chưa khả dụng.'),
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
                    const Center(child: CircularProgressIndicator())
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
