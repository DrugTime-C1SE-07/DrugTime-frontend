import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../app/router.dart';
import '../../../../core/utils/app_assets.dart';

class HealthProfileIntroScreen extends StatefulWidget {
  const HealthProfileIntroScreen({super.key});

  @override
  State<HealthProfileIntroScreen> createState() =>
      _HealthProfileIntroScreenState();
}

class _HealthProfileIntroScreenState extends State<HealthProfileIntroScreen> {
  bool _openingSetup = false;

  Future<void> _openSetup() async {
    if (_openingSetup) return;
    _openingSetup = true;
    final introRoute = ModalRoute.of(context);
    try {
      final completed = await Navigator.of(context).pushNamed<bool>(
        AppRoutes.healthSetup,
        arguments: introRoute,
      );
      if (mounted && completed == true && introRoute?.isCurrent == true) {
        Navigator.of(context).pop();
      }
    } finally {
      _openingSetup = false;
    }
  }

  static const _background = Color(0xFFF8F9F9);
  static const _border = Color(0xFFE0E2E4);
  static const _textStyle = TextStyle(
    fontFamily: 'WelcomeInter',
    color: AppColors.ink,
  );

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 720;
    final mascotFrame = compact ? 140.0 : 190.0;
    final mascotSize = compact ? 108.0 : 144.0;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFC9EAE3), _background, _background],
              stops: [0, 0.5, 1],
            ),
          ),
          child: SafeArea(
            minimum: const EdgeInsets.only(bottom: 12),
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                  sliver: SliverFillRemaining(
                    hasScrollBody: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => Navigator.maybePop(context),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(48, 48),
                              foregroundColor: AppColors.brand,
                              textStyle: _textStyle.copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            child: const Text('Bỏ qua'),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: Container(
                            width: mascotFrame,
                            height: mascotFrame,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: Color(0x99FFFFFF),
                              shape: BoxShape.circle,
                            ),
                            child: Image.asset(
                              AppAssets.mascotProtect,
                              width: mascotSize,
                              height: mascotSize,
                              fit: BoxFit.contain,
                              excludeFromSemantics: true,
                            ),
                          ),
                        ),
                        SizedBox(height: compact ? 28 : 78),
                        Text(
                          'Thiết lập hồ sơ sức khỏe',
                          textAlign: TextAlign.center,
                          style: _textStyle.copyWith(
                            fontSize: 28,
                            height: 36 / 28,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Khai báo dị ứng và bệnh nền để nhận cảnh báo phù hợp.',
                          textAlign: TextAlign.center,
                          style: _textStyle.copyWith(
                            fontSize: 17,
                            height: 25 / 17,
                            color: AppColors.inkMuted,
                          ),
                        ),
                        const SizedBox(height: 26),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: const Color(0x99FFFFFF),
                            border: Border.all(color: _border),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Column(
                            children: [
                              _ProfileTopic(
                                icon: Icons.warning_amber_rounded,
                                iconColor: Color(0xFFB65C14),
                                title: 'Dị ứng',
                                subtitle: 'Thuốc, thực phẩm',
                              ),
                              Divider(
                                color: _border,
                                height: 1,
                                indent: 52,
                                endIndent: 1,
                              ),
                              _ProfileTopic(
                                icon: Icons.favorite_border_rounded,
                                iconColor: Color(0xFF704EA3),
                                title: 'Bệnh nền',
                                subtitle: 'Bệnh đang điều trị',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Bạn có thể bổ sung hồ sơ sau.',
                          textAlign: TextAlign.center,
                          style: _textStyle.copyWith(
                            fontSize: 14,
                            height: 20 / 14,
                            color: AppColors.inkMuted,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Spacer(),
                        FilledButton(
                          onPressed: _openSetup,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 56),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            backgroundColor: AppColors.brand,
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            textStyle: _textStyle.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          child: const Text(
                            'Tiếp tục đến dị ứng',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileTopic extends StatelessWidget {
  const _ProfileTopic({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    const style = _HealthProfileIntroScreenState._textStyle;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: style.copyWith(
                    fontSize: 16,
                    height: 22 / 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: style.copyWith(
                    fontSize: 14,
                    height: 20 / 14,
                    color: AppColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
