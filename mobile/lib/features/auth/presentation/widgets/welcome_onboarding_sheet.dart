import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/app_assets.dart';

/// Shows the welcome popup. The caller owns navigation to profile setup.
Future<void> showWelcomeOnboardingSheet(
  BuildContext context, {
  required VoidCallback onSetup,
  String? setupRoute,
}) async {
  final setup = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    enableDrag: false,
    showDragHandle: false,
    isDismissible: false,
    sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
        ? AnimationStyle.noAnimation
        : null,
    barrierColor: const Color(0x800B1F1C),
    backgroundColor: Colors.transparent,
    elevation: 0,
    builder: (sheetContext) => _WelcomeOnboardingSheet(
      onSetup: setupRoute == null
          ? null
          : () => Navigator.of(sheetContext)
              .pushReplacementNamed<void, bool>(setupRoute),
    ),
  );
  if (setup == true && context.mounted) onSetup();
}

const _titleStyle = TextStyle(
  inherit: false,
  fontFamily: 'WelcomeInter',
  fontSize: 22,
  fontWeight: FontWeight.w700,
  height: 24 / 22,
  color: AppColors.ink,
);
const _featureStyle = TextStyle(
  inherit: false,
  fontFamily: 'WelcomeInter',
  fontSize: 17,
  fontWeight: FontWeight.w600,
  height: 20 / 17,
  color: AppColors.ink,
);
const _descriptionStyle = TextStyle(
  inherit: false,
  fontFamily: 'WelcomeInter',
  fontSize: 14,
  height: 20 / 14,
  color: AppColors.inkMuted,
);
const _buttonStyle = TextStyle(
  letterSpacing: 0,
  fontFamily: 'WelcomeInter',
  fontSize: 17,
  fontWeight: FontWeight.w700,
  height: 24 / 17,
);

class _WelcomeOnboardingSheet extends StatefulWidget {
  const _WelcomeOnboardingSheet({this.onSetup});

  final VoidCallback? onSetup;

  @override
  State<_WelcomeOnboardingSheet> createState() =>
      _WelcomeOnboardingSheetState();
}

class _WelcomeOnboardingSheetState extends State<_WelcomeOnboardingSheet>
    with SingleTickerProviderStateMixin {
  static const _flingThreshold = 700.0;
  final _sheetKey = GlobalKey();
  late final _offset = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );

  double get _sheetHeight => _sheetKey.currentContext!.size!.height;

  @override
  void dispose() {
    _offset.dispose();
    super.dispose();
  }

  void _move(DragUpdateDetails details) {
    _offset.value =
        (_offset.value + details.delta.dy / _sheetHeight).clamp(0.0, 1.0);
  }

  void _settle([double velocity = 0]) {
    final close = velocity > _flingThreshold ||
        (velocity >= -_flingThreshold && _offset.value >= 0.5);
    final target = close ? 1.0 : 0.0;
    if (MediaQuery.disableAnimationsOf(context)) {
      _offset.value = target;
      if (close) _dismiss();
      return;
    }

    final completion = velocity.abs() > _flingThreshold
        ? _offset.fling(velocity: velocity / _sheetHeight)
        : _offset.animateTo(target, curve: Curves.easeOutCubic);
    if (close) completion.then((_) => _dismiss());
  }

  void _dismiss([bool? setup]) {
    if (mounted && ModalRoute.of(context)?.isCurrent == true) {
      final replace = widget.onSetup;
      if (setup == true && replace != null) {
        replace();
      } else {
        Navigator.of(context).pop(setup);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _offset,
      builder: (context, child) => FractionalTranslation(
        translation: Offset(0, _offset.value),
        child: child,
      ),
      child: Material(
        key: _sheetKey,
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final bottomPadding = math.max(
      30.0,
      MediaQuery.viewPaddingOf(context).bottom - 4,
    );
    return SizedBox(
      key: const Key('welcome-sheet'),
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            dragStartBehavior: DragStartBehavior.down,
            onVerticalDragDown: (_) => _offset.stop(),
            onVerticalDragUpdate: _move,
            onVerticalDragEnd: (details) =>
                _settle(details.velocity.pixelsPerSecond.dy),
            onVerticalDragCancel: () => _settle(),
            child: Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 18),
              child: Container(
                key: const Key('welcome-drag-handle'),
                width: 36,
                height: 4,
                decoration: const BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.all(Radius.circular(2)),
                ),
              ),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(bottom: bottomPadding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Image.asset(
                            AppAssets.mascotHappy,
                            key: const Key('welcome-mascot'),
                            width: 76,
                            height: 70,
                            fit: BoxFit.fill,
                            excludeFromSemantics: true,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Semantics(
                          header: true,
                          // Align Flutter's Inter baseline with the Figma
                          // reference while preserving the title's line box.
                          child: Transform.translate(
                            offset: const Offset(0, 2),
                            child: const Text(
                              'Chào mừng đến với DrugTime!',
                              style: _titleStyle,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        const _WelcomeFeature(
                          icon: 'bell',
                          title: 'Nhắc uống đúng giờ',
                          description: 'Theo lịch uống bạn đặt',
                        ),
                        const SizedBox(height: 14),
                        const _WelcomeFeature(
                          icon: 'alert-triangle',
                          title: 'Cảnh báo tương tác',
                          description: 'Phát hiện thuốc kỵ nhau',
                        ),
                        const SizedBox(height: 14),
                        const _WelcomeFeature(
                          icon: 'users',
                          title: 'Người thân cùng theo dõi',
                          description: 'Cả nhà yên tâm hơn',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DecoratedBox(
                          decoration: const BoxDecoration(
                            borderRadius: BorderRadius.all(
                              Radius.circular(AppRadius.card),
                            ),
                            boxShadow: [
                              BoxShadow(
                                // Compensate for Flutter's lighter blurred
                                // edge at the reference CTA size.
                                color: Color(0x6B013D39),
                                offset: Offset(0, 5),
                                blurRadius: 7,
                                spreadRadius: -2,
                              ),
                              BoxShadow(
                                color: Color(0x26013D39),
                                offset: Offset(0, 1),
                                blurRadius: 1,
                              ),
                            ],
                          ),
                          child: FilledButton(
                            key: const Key('welcome-setup'),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(
                                0,
                                AppSizes.primaryButton,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.lg,
                                vertical: AppSpacing.sm,
                              ),
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(AppRadius.card),
                                ),
                              ),
                              backgroundColor: AppColors.brand,
                              foregroundColor: AppColors.onBrand,
                              textStyle: _buttonStyle,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.standard,
                            ),
                            onPressed: () => _dismiss(true),
                            child: const Text(
                              'Thiết lập hồ sơ sức khỏe',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        TextButton(
                          key: const Key('welcome-later'),
                          style: TextButton.styleFrom(
                            minimumSize: const Size(0, AppSizes.tapTarget),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                              vertical: AppSpacing.sm,
                            ),
                            foregroundColor: AppColors.inkMuted,
                            textStyle: _buttonStyle.copyWith(
                              fontWeight: FontWeight.w600,
                              height: 26 / 17,
                            ),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.standard,
                          ),
                          onPressed: () => _dismiss(),
                          child: const Text('Để sau'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeFeature extends StatelessWidget {
  const _WelcomeFeature({
    required this.icon,
    required this.title,
    required this.description,
  });

  final String icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Row(
        key: ValueKey('welcome-feature-$icon'),
        children: [
          Container(
            width: AppSizes.iconTile,
            height: AppSizes.iconTile,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.brandTint,
              shape: BoxShape.circle,
            ),
            child: SvgPicture.asset(
              'assets/icons/welcome/$icon.svg',
              width: 20,
              height: 20,
              excludeFromSemantics: true,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _featureStyle),
                const SizedBox(height: 2),
                Text(description, style: _descriptionStyle),
              ],
            ),
          ),
        ],
      );
}
