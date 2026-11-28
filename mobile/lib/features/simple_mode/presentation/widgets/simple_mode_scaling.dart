import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/simple_mode_theme.dart';

/// Font-scaling helpers that respect the system [TextScaler] while preserving
/// minimum 48dp touch targets and preventing layout overflow.
abstract final class SimpleModeScaling {
  static const double largeScaleThreshold = 1.3;
  static const double narrowViewportWidth = 340.0;

  /// Returns the effective scale ratio relative to 18sp base body text.
  static double effectiveScale(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    return scaler.scale(18.0) / 18.0;
  }

  /// Returns true when system text scaling is enlarged enough that horizontal
  /// rows should stack vertically to avoid overflow.
  static bool isLargeTextScale(BuildContext context) =>
      effectiveScale(context) >= largeScaleThreshold;

  /// Computes a touch-target dimension that is always at least [SimpleModeSizes.minTapTarget] (48dp).
  static double scaledTapTarget(
    BuildContext context, {
    double base = SimpleModeSizes.minTapTarget,
  }) {
    final scale = math.max(1.0, effectiveScale(context));
    return math.max(SimpleModeSizes.minTapTarget, base * math.min(scale, 1.5));
  }
}

/// High-contrast accessible action button for Simple Mode.
///
/// Enforces >= 48dp touch targets, >= 18sp wrapping text, and zero clipping
/// under system [TextScaler] 1.0x–2.0x on narrow viewports.
class SimpleModeActionButton extends StatelessWidget {
  const SimpleModeActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.backgroundColor = SimpleModeColors.brand,
    this.foregroundColor = SimpleModeColors.onBrand,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    final minHeight = SimpleModeScaling.scaledTapTarget(
      context,
      base: SimpleModeSizes.primaryButtonHeight,
    );

    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: SimpleModeSizes.minTapTarget,
        minHeight: minHeight,
      ),
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          minimumSize: Size(SimpleModeSizes.minTapTarget, minHeight),
          padding: const EdgeInsets.symmetric(
            horizontal: SimpleModeSizes.spacingLg,
            vertical: SimpleModeSizes.spacingMd,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: SimpleModeSizes.iconSize, color: foregroundColor),
              const SizedBox(width: SimpleModeSizes.spacingSm),
            ],
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                softWrap: true,
                style: SimpleModeTextStyles.buttonLabel.copyWith(
                  color: foregroundColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Responsive two-slot layout that renders as a [Row] at standard scale and
/// automatically stacks as a [Column] when text is enlarged or viewport is narrow.
class SimpleModeScalableRow extends StatelessWidget {
  const SimpleModeScalableRow({
    super.key,
    required this.leading,
    required this.trailing,
    this.spacing = SimpleModeSizes.spacingSm,
  });

  final Widget leading;
  final Widget trailing;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final shouldStack = SimpleModeScaling.isLargeTextScale(context) ||
            constraints.maxWidth < SimpleModeScaling.narrowViewportWidth;

        if (shouldStack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              leading,
              SizedBox(height: spacing),
              trailing,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: leading),
            SizedBox(width: spacing),
            Flexible(child: trailing),
          ],
        );
      },
    );
  }
}

/// High-contrast bordered container for Simple Mode content blocks.
class SimpleModeContrastCard extends StatelessWidget {
  const SimpleModeContrastCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(SimpleModeSizes.spacingLg),
    this.backgroundColor = SimpleModeColors.surface,
    this.borderColor = SimpleModeColors.border,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color backgroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: borderColor,
          width: SimpleModeSizes.borderWidth,
        ),
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}
