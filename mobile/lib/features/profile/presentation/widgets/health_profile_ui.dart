import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/mascot/mascot_controller.dart';
import '../../../../shared/widgets/mascot/mascot_view.dart';

/// Shared look of the health screens (health profile, physiological state): friendly mascot,
/// soft cards on a 4/8 dp grid, 48 dp touch targets, auto-save status.
abstract final class HealthProfileStyle {
  static const canvas = Color(0xFFF5F8F7);
  static const heroTop = Color(0xFFDDF1EC);
  static const heroBottom = Color(0xFFF7FBFA);
  static const pink = Color(0xFFFFE4EC);
  static const pinkInk = Color(0xFFB4235A);
}

/// Mascot reacts to what the user just did, then settles back to idle.
class MascotReactions {
  MascotReactions(this.controller);
  final MascotController controller;
  Timer? _back;

  void react(MascotMood mood,
      {Duration hold = const Duration(milliseconds: 2500)}) {
    controller.play(mood);
    _back?.cancel();
    _back = Timer(hold, () => controller.play(MascotMood.idle));
  }

  void dispose() => _back?.cancel();
}

enum HealthSaveStatus { idle, saving, saved, failed, unsaved }

/// "Đang lưu… / Đã lưu / Lưu lỗi – Thử lại / Chưa lưu"; announced to screen readers.
class SaveStatusChip extends StatelessWidget {
  const SaveStatusChip({super.key, required this.status, this.onRetry});
  final HealthSaveStatus status;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final (icon, label, fg, bg) = switch (status) {
      HealthSaveStatus.idle => (
          Icons.cloud_done_outlined,
          'Tự động lưu',
          AppColors.inkMuted,
          Colors.white
        ),
      HealthSaveStatus.saving => (
          Icons.sync,
          'Đang lưu…',
          AppColors.brand,
          AppColors.brandTint
        ),
      HealthSaveStatus.saved => (
          Icons.check_circle,
          'Đã lưu',
          AppColors.safe,
          AppColors.safeBg
        ),
      HealthSaveStatus.failed => (
          Icons.error_outline,
          'Lưu lỗi – Thử lại',
          AppColors.danger,
          AppColors.dangerBg
        ),
      HealthSaveStatus.unsaved => (
          Icons.edit_note,
          'Chưa lưu',
          AppColors.cautionText,
          AppColors.cautionBg
        ),
    };
    final chip = AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Container(
        key: ValueKey(status),
        constraints: const BoxConstraints(minHeight: 32),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 6),
          Flexible(
            child: Text(label,
                key: const Key('health-save-status'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: fg)),
          ),
        ]),
      ),
    );
    return Semantics(
      liveRegion: true,
      button: status == HealthSaveStatus.failed,
      label: label,
      child: status == HealthSaveStatus.failed && onRetry != null
          ? InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: onRetry,
              child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Center(widthFactor: 1, child: chip)))
          : ExcludeSemantics(child: chip),
    );
  }
}

/// Top card: mascot in medic outfit beside a short, warm explanation and the save status.
class HealthHeroCard extends StatelessWidget {
  const HealthHeroCard({
    super.key,
    required this.mascot,
    required this.title,
    required this.subtitle,
    required this.status,
    this.onRetry,
  });
  final MascotController mascot;
  final String title;
  final String subtitle;
  final HealthSaveStatus status;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [HealthProfileStyle.heroTop, HealthProfileStyle.heroBottom],
          ),
          border: Border.all(color: const Color(0xFFCFE8E2)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Semantics(
            label: 'Linh vật Dumi',
            image: true,
            child: SizedBox.square(
              dimension: 104,
              child: MascotView(
                  controller: mascot, size: 104, outfit: MascotOutfit.medic),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: AppTextStyles.heading
                      .copyWith(color: AppColors.brandStrong)),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.inkMuted, height: 1.45)),
              // Saving is silent (feedback 20/11); only a problem is shown.
              if (status == HealthSaveStatus.failed ||
                  status == HealthSaveStatus.unsaved) ...[
                const SizedBox(height: 12),
                SaveStatusChip(status: status, onRetry: onRetry),
              ],
            ]),
          ),
        ]),
      );
}

/// White section card with an icon tile and a title.
class HealthSectionCard extends StatelessWidget {
  const HealthSectionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
    this.subtitle,
    this.tint = AppColors.brandTint,
    this.iconColor = AppColors.brand,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;
  final Color tint;
  final Color iconColor;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppShadows.cardElevation,
        ),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: tint, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                        header: true,
                        child: Text(title, style: AppTextStyles.bodyStrong)),
                    if (subtitle != null)
                      Text(subtitle!,
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.inkMuted)),
                  ]),
            ),
          ]),
          const SizedBox(height: 12),
          child,
        ]),
      );
}

/// Pill chip with a press "squish" and a light haptic. [selected] fills it; [onRemove] adds a
/// remove affordance (the whole chip removes, the × is a visual hint).
class HealthTag extends StatefulWidget {
  const HealthTag({
    super.key,
    required this.label,
    this.onTap,
    this.selected = true,
    this.removable = false,
    this.icon,
  });
  final String label;
  final VoidCallback? onTap;
  final bool selected;
  final bool removable;
  final IconData? icon;

  @override
  State<HealthTag> createState() => _HealthTagState();
}

class _HealthTagState extends State<HealthTag> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final enabled = widget.onTap != null;
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: widget.removable ? '${widget.label}, bỏ chọn' : widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: enabled
            ? () {
                HapticFeedback.selectionClick();
                widget.onTap!();
              }
            : null,
        child: AnimatedScale(
          scale: _down ? .94 : 1,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? AppColors.brandTint : Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                  color: selected ? AppColors.brand : AppColors.border,
                  width: selected ? 1.4 : 1),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                  widget.icon ??
                      (selected ? Icons.check_rounded : Icons.add_rounded),
                  size: 18,
                  color: selected ? AppColors.brand : AppColors.inkMuted),
              const SizedBox(width: 6),
              Flexible(
                child: Text(widget.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 15,
                        height: 1.3,
                        fontWeight: FontWeight.w500,
                        color:
                            selected ? AppColors.brandStrong : AppColors.ink)),
              ),
              if (widget.removable) ...[
                const SizedBox(width: 6),
                const Icon(Icons.close_rounded,
                    size: 16, color: AppColors.inkMuted),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

/// "Không có … đã biết" as a full-width row with a round check.
class HealthNoneToggle extends StatelessWidget {
  const HealthNoneToggle(
      {super.key, required this.label, required this.value, this.onChanged});
  final String label;
  final bool value;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        toggled: value,
        enabled: onChanged != null,
        label: label,
        excludeSemantics: true,
        child: Material(
          color: value ? AppColors.brandTint : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onChanged == null
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    onChanged!();
                  },
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 160),
                    child: Icon(
                        key: ValueKey(value),
                        value
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked,
                        color: value ? AppColors.brand : AppColors.inkMuted),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(label,
                          style: TextStyle(
                              fontSize: 15,
                              color: onChanged == null
                                  ? AppColors.inkDisabled
                                  : AppColors.ink))),
                ]),
              ),
            ),
          ),
        ),
      );
}

/// Friendly empty / loading / error block with the mascot's mood carried by the hero card.
class HealthStateMessage extends StatelessWidget {
  const HealthStateMessage(
      {super.key, required this.text, this.action, this.onAction});
  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(children: [
          Text(text,
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(color: AppColors.inkMuted)),
          if (action != null) ...[
            const SizedBox(height: 8),
            TextButton(onPressed: onAction, child: Text(action!)),
          ],
        ]),
      );
}
