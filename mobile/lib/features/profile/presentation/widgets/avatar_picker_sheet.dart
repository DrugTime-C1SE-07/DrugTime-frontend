import 'package:flutter/material.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/app_assets.dart';
import '../../../../shared/widgets/two_column_grid.dart';
import '../state/profile_controller.dart';

Future<void> showAvatarPicker(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const AvatarPickerSheet(),
    );

class AvatarPickerSheet extends StatelessWidget {
  const AvatarPickerSheet({super.key});
  static const _labels = [
    'Bé trai',
    'Bé gái',
    'Ông',
    'Bà',
    'Cô gái',
    'Chàng trai'
  ];
  @override
  Widget build(BuildContext context) {
    final c = ProfileScope.of(context);
    return SingleChildScrollView(
        child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Chọn ảnh đại diện', style: AppTextStyles.heading),
        const SizedBox(height: AppSpacing.lg),
        TwoColumnGrid(children: [
          for (var i = 0; i < AppAssets.profileAvatars.length; i++)
            Semantics(
                selected: c.avatar == AppAssets.profileAvatars[i],
                child: OutlinedButton(
                  key: ValueKey('avatar-$i'),
                  onPressed: () {
                    c.selectAvatar(AppAssets.profileAvatars[i]);
                    Navigator.pop(context);
                  },
                  child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(children: [
                        ClipOval(
                            child: Image.asset(AppAssets.profileAvatars[i],
                                width: 64,
                                height: 64,
                                fit: BoxFit.cover,
                                excludeFromSemantics: true)),
                        Text(_labels[i]),
                      ])),
                )),
        ]),
        FilledButton.tonal(
            key: const Key('close-avatar-picker'),
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.brandTint,
                foregroundColor: AppColors.brand),
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng')),
      ]),
    ));
  }
}
