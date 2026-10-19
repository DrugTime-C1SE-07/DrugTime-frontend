import 'package:flutter/material.dart';
import '../../../../app/theme/app_theme.dart';

class ProfileFieldPair extends StatelessWidget {
  const ProfileFieldPair({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        if (box.maxWidth < 330 ||
            MediaQuery.textScalerOf(context).scale(16) > 21) {
          return Column(children: children);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: children[0]),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: children[1]),
        ]);
      });
}

class ProfileField extends StatelessWidget {
  const ProfileField({super.key, required this.label, required this.child});
  final String label;
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(label,
            style: AppTextStyles.captionStrong.copyWith(color: AppColors.ink)),
        const SizedBox(height: AppSpacing.sm),
        child,
      ]));
}
