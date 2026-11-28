import 'package:flutter/material.dart';
import '../../app/theme/app_theme.dart';

const profileFlowCanvas = Color(0xFFF7F9F8);

class ProfileFlowHeader extends StatelessWidget implements PreferredSizeWidget {
  const ProfileFlowHeader(this.title,
      {super.key,
      this.backgroundColor = profileFlowCanvas,
      this.leading,
      this.actions,
      this.titleScale = 1,
      this.titleSize = 18});
  final String title;
  final double titleScale;
  final double titleSize;
  final Color backgroundColor;
  final Widget? leading;
  final List<Widget>? actions;
  @override
  Size get preferredSize =>
      Size.fromHeight(titleScale > 1.4 ? 18 * titleScale * 3 * 1.2 + 8 : 56);
  @override
  Widget build(BuildContext context) => AppBar(
        backgroundColor: backgroundColor,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: preferredSize.height,
        centerTitle: true,
        titleSpacing: 0,
        leadingWidth: 72,
        title: Text(title,
            style: Theme.of(context).textTheme.titleMedium!.copyWith(
                fontSize: titleSize,
                fontWeight: FontWeight.w700,
                color: AppColors.ink),
            maxLines: 3,
            textAlign: TextAlign.center),
        leading: leading ??
            Padding(
                padding: const EdgeInsets.only(left: 20),
                child: Center(
                    child: ActionIconTheme(
                        data: ActionIconThemeData(
                            backButtonIconBuilder: (context) => const Icon(
                                Icons.chevron_left,
                                color: AppColors.brand)),
                        child: BackButton(
                            color: AppColors.brand,
                            onPressed: () => Navigator.maybePop(context),
                            style: IconButton.styleFrom(
                                backgroundColor: AppColors.brandTint,
                                minimumSize: const Size(48, 48)))))),
        actions: actions,
      );
}

class ProfileFlowCard extends StatelessWidget {
  const ProfileFlowCard(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(16),
      this.color = AppColors.surface,
      this.shadow = true});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final bool shadow;
  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
            boxShadow: shadow ? AppShadows.cardElevation : null),
        child: child,
      );
}

class ProfileFlowSection extends StatelessWidget {
  const ProfileFlowSection(this.title, {super.key, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF254A45))),
          const SizedBox(height: 8),
          ProfileFlowCard(
              padding: EdgeInsets.zero,
              shadow: false,
              child: Column(children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0)
                    const Divider(height: 1, color: AppColors.dividerSoft),
                  children[i],
                ],
              ])),
        ]),
      );
}

class ProfileFlowRow extends StatelessWidget {
  const ProfileFlowRow(this.title,
      {super.key,
      this.icon,
      this.subtitle,
      this.subtitleStyle,
      this.unavailableStyle,
      this.onTap,
      this.trailing,
      this.unavailable = false,
      this.color = AppColors.brand});
  final String title;
  final IconData? icon;
  final String? subtitle;
  final TextStyle? subtitleStyle;
  final TextStyle? unavailableStyle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool unavailable;
  final Color color;
  @override
  Widget build(BuildContext context) => Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: unavailable ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(children: [
                if (icon != null) ...[
                  Icon(icon,
                      size: 18,
                      color: unavailable ? AppColors.inkMuted : color),
                  const SizedBox(width: 12)
                ],
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(title,
                          style: const TextStyle(fontSize: 15, height: 1.45)),
                      if (subtitle != null)
                        Text(subtitle!,
                            style: subtitleStyle ?? AppTextStyles.caption),
                      if (unavailable)
                        Text('Chưa khả dụng',
                            style: unavailableStyle ?? AppTextStyles.caption),
                    ])),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  trailing!
                ] else if (onTap != null && !unavailable)
                  const Icon(Icons.chevron_right,
                      size: 18, color: AppColors.inkMuted),
              ]),
            )),
      ));
}

class ProfileUnavailable extends StatelessWidget {
  const ProfileUnavailable(
      {super.key, this.message = 'Tính năng này chưa khả dụng.'});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(12)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.info_outline, size: 18, color: AppColors.inkMuted),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: AppTextStyles.caption)),
        ]),
      );
}

class ProfileFlowButton extends StatelessWidget {
  const ProfileFlowButton(
      {super.key, required this.label, this.onPressed, this.icon});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: onPressed == null
                ? null
                : const [
                    BoxShadow(
                        color: Color(0x3301554F),
                        offset: Offset(0, 4),
                        blurRadius: 9),
                  ]),
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
          child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18),
                  const SizedBox(width: 8)
                ],
                Flexible(child: Text(label, textAlign: TextAlign.center)),
              ]),
        ),
      );
}
