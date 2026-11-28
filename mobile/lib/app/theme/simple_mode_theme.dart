import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/motion/shared_axis.dart';

/// High-contrast color tokens for Simple Mode (QA.03: text contrast >= 7:1).
///
/// Clinical semantic colors (safe / caution / danger / info) must always be
/// paired with an icon and text label rather than conveying meaning by color alone.
abstract final class SimpleModeColors {
  static const canvas = Color(0xFFFFFFFF);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF3F4F6);

  static const ink = Color(0xFF0A0A0A);
  static const inkMuted = Color(0xFF374151);
  static const border = Color(0xFF1F2937);

  static const brand = Color(0xFF004D47);
  static const brandStrong = Color(0xFF00332E);
  static const brandTint = Color(0xFFE6F4F2);
  static const onBrand = Color(0xFFFFFFFF);

  static const safe = Color(0xFF0D5C2B);
  static const safeBg = Color(0xFFE6F7ED);
  static const caution = Color(0xFF7C2D12);
  static const cautionBg = Color(0xFFFEF3E2);
  static const danger = Color(0xFF8B1515);
  static const dangerBg = Color(0xFFFDECEC);
  static const info = Color(0xFF1E3A8A);
  static const infoBg = Color(0xFFEAF1FD);
}

/// Accessible sizing and spacing tokens for Simple Mode (QA.03: >= 48dp touch targets).
abstract final class SimpleModeSizes {
  static const minTapTarget = 48.0;
  static const primaryButtonHeight = 64.0;
  static const fieldHeight = 60.0;
  static const iconSize = 28.0;
  static const borderWidth = 2.0;

  static const spacingSm = 12.0;
  static const spacingMd = 16.0;
  static const spacingLg = 24.0;
  static const spacingXl = 32.0;
}

/// High-contrast typography scale for Simple Mode (QA.03: primary text >= 18sp).
abstract final class SimpleModeTextStyles {
  static const _tabular = [FontFeature.tabularFigures()];

  static const display = TextStyle(
    fontSize: 28.0,
    fontWeight: FontWeight.w700,
    height: 1.25,
    color: SimpleModeColors.ink,
  );

  static const title = TextStyle(
    fontSize: 24.0,
    fontWeight: FontWeight.w700,
    height: 1.3,
    color: SimpleModeColors.ink,
  );

  static const heading = TextStyle(
    fontSize: 20.0,
    fontWeight: FontWeight.w600,
    height: 1.35,
    color: SimpleModeColors.ink,
  );

  static const body = TextStyle(
    fontSize: 18.0,
    fontWeight: FontWeight.w400,
    height: 1.45,
    color: SimpleModeColors.ink,
  );

  static const bodyStrong = TextStyle(
    fontSize: 18.0,
    fontWeight: FontWeight.w600,
    height: 1.45,
    color: SimpleModeColors.ink,
  );

  static const buttonLabel = TextStyle(
    fontSize: 18.0,
    fontWeight: FontWeight.w700,
    height: 1.3,
    color: SimpleModeColors.onBrand,
  );

  static const caption = TextStyle(
    fontSize: 18.0,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: SimpleModeColors.inkMuted,
  );

  static const figure = TextStyle(
    fontSize: 22.0,
    fontWeight: FontWeight.w700,
    height: 1.3,
    color: SimpleModeColors.ink,
    fontFeatures: _tabular,
  );
}

/// Pure WCAG 2.1 contrast calculation helpers for verifying >= 7:1 compliance.
abstract final class WcagContrast {
  static const double aaaNormalTextMinimum = 7.0;

  static double _linearize(int channel) {
    final srgb = channel / 255.0;
    if (srgb <= 0.04045) {
      return srgb / 12.92;
    }
    return math.pow((srgb + 0.055) / 1.055, 2.4).toDouble();
  }

  /// Computes relative luminance in `[0.0, 1.0]` per WCAG 2.1.
  static double relativeLuminance(Color color) {
    final r = _linearize(color.red);
    final g = _linearize(color.green);
    final b = _linearize(color.blue);
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  /// Computes contrast ratio in `[1.0, 21.0]` between [foreground] and [background].
  static double contrastRatio(Color foreground, Color background) {
    final l1 = relativeLuminance(foreground);
    final l2 = relativeLuminance(background);
    final lighter = math.max(l1, l2);
    final darker = math.min(l1, l2);
    return (lighter + 0.05) / (darker + 0.05);
  }

  /// Returns true if [foreground] on [background] meets WCAG AAA (>= 7:1).
  static bool meetsAaaNormalText(Color foreground, Color background) =>
      contrastRatio(foreground, background) >= aaaNormalTextMinimum;
}

/// Builds the high-contrast [ThemeData] for Simple Mode.
ThemeData buildSimpleModeTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: SimpleModeColors.brand,
    primary: SimpleModeColors.brand,
    onPrimary: SimpleModeColors.onBrand,
    surface: SimpleModeColors.surface,
    onSurface: SimpleModeColors.ink,
    error: SimpleModeColors.danger,
    onError: SimpleModeColors.onBrand,
  );

  const fieldBorder = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(12.0)),
    borderSide: BorderSide(
      color: SimpleModeColors.border,
      width: SimpleModeSizes.borderWidth,
    ),
  );

  return ThemeData(
    useMaterial3: true,
    pageTransitionsTheme: sharedAxisPageTransitionsTheme,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: SimpleModeColors.canvas,
    dividerColor: SimpleModeColors.border,
    textTheme: const TextTheme(
      headlineSmall: SimpleModeTextStyles.title,
      titleMedium: SimpleModeTextStyles.heading,
      bodyLarge: SimpleModeTextStyles.body,
      bodyMedium: SimpleModeTextStyles.body,
      bodySmall: SimpleModeTextStyles.caption,
      labelLarge: SimpleModeTextStyles.buttonLabel,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: SimpleModeColors.canvas,
      foregroundColor: SimpleModeColors.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: SimpleModeTextStyles.title,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: SimpleModeColors.surface,
      contentPadding: EdgeInsets.symmetric(
        horizontal: SimpleModeSizes.spacingMd,
        vertical: SimpleModeSizes.spacingMd,
      ),
      hintStyle: SimpleModeTextStyles.caption,
      border: fieldBorder,
      enabledBorder: fieldBorder,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12.0)),
        borderSide: BorderSide(
          color: SimpleModeColors.brandStrong,
          width: 3.0,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: SimpleModeColors.brand,
        foregroundColor: SimpleModeColors.onBrand,
        minimumSize: const Size(
          SimpleModeSizes.minTapTarget,
          SimpleModeSizes.primaryButtonHeight,
        ),
        textStyle: SimpleModeTextStyles.buttonLabel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: SimpleModeColors.brand,
        foregroundColor: SimpleModeColors.onBrand,
        minimumSize: const Size(
          SimpleModeSizes.minTapTarget,
          SimpleModeSizes.primaryButtonHeight,
        ),
        textStyle: SimpleModeTextStyles.buttonLabel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: SimpleModeColors.ink,
        backgroundColor: SimpleModeColors.surface,
        minimumSize: const Size(
          SimpleModeSizes.minTapTarget,
          SimpleModeSizes.minTapTarget,
        ),
        side: const BorderSide(
          color: SimpleModeColors.border,
          width: SimpleModeSizes.borderWidth,
        ),
        textStyle: SimpleModeTextStyles.bodyStrong,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: SimpleModeColors.brandStrong,
        minimumSize: const Size(
          SimpleModeSizes.minTapTarget,
          SimpleModeSizes.minTapTarget,
        ),
        textStyle: SimpleModeTextStyles.bodyStrong,
      ),
    ),
    cardTheme: CardThemeData(
      color: SimpleModeColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
        side: const BorderSide(
          color: SimpleModeColors.border,
          width: SimpleModeSizes.borderWidth,
        ),
      ),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: SimpleModeColors.surface,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: SimpleModeTextStyles.title,
      contentTextStyle: SimpleModeTextStyles.body,
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: SimpleModeColors.ink,
      contentTextStyle: TextStyle(
        fontSize: 18.0,
        fontWeight: FontWeight.w600,
        color: SimpleModeColors.onBrand,
      ),
    ),
  );
}
