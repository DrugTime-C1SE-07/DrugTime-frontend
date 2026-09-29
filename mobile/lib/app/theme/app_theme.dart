import 'package:flutter/material.dart';

/// Màu dùng chung — đồng bộ với landing/app/tokens.css (Figma Foundation Sheet).
///
/// Nhóm màu lâm sàng (safe / caution / danger) chỉ dùng đúng nghĩa lâm sàng,
/// luôn đi kèm icon + chữ, không bao giờ truyền đạt trạng thái bằng màu đơn thuần.
abstract final class AppColors {
  // Nền & chữ
  static const canvas = Color(0xFFFCFCFC);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF2F1ED);
  static const ink = Color(0xFF211D1D);
  static const inkMuted = Color(0xFF5B6169);
  static const inkDisabled = Color(0xFF9CA3AF);
  static const border = Color(0xFFE4E4E1);

  // Thương hiệu — hành động chính, không dùng cho trạng thái lâm sàng
  static const brand = Color(0xFF01554F);
  static const brandStrong = Color(0xFF013D39);
  static const brandTint = Color(0xFFE7F3F1);
  static const onBrand = Color(0xFFFFFFFF);

  // Lâm sàng
  static const safe = Color(0xFF15803D);
  static const safeBg = Color(0xFFE8F7EE);
  static const caution = Color(0xFFD97706);
  static const cautionText = Color(0xFF92400E);
  static const cautionBg = Color(0xFFFEF3E2);
  static const danger = Color(0xFFB91C1C);
  static const dangerBg = Color(0xFFFDECEC);
  static const info = Color(0xFF2563EB);
  static const infoBg = Color(0xFFEAF1FD);
}

/// Lưới 4/8pt.
abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;

  /// Lề ngang màn hình.
  static const page = 16.0;
}

abstract final class AppRadius {
  static const field = 12.0;
  static const card = 16.0;
}

/// Kích thước chạm tối thiểu (người lớn tuổi): 48dp, nút chính 56dp.
abstract final class AppSizes {
  static const tapTarget = 48.0;
  static const field = 56.0;
  static const primaryButton = 56.0;
}

/// Thang chữ: 4 cỡ (24 · 18 · 16 · 14), 2 độ đậm (400 · 600).
/// Cỡ nhỏ nhất 14 để người lớn tuổi vẫn đọc được.
abstract final class AppTextStyles {
  static const _tabular = [FontFeature.tabularFigures()];

  static const title = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.25,
    color: AppColors.ink,
  );

  static const heading = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.3,
    color: AppColors.ink,
  );

  static const body = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.45,
    color: AppColors.ink,
  );

  static const bodyStrong = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.45,
    color: AppColors.ink,
  );

  static const caption = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: AppColors.inkMuted,
  );

  static const captionStrong = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: AppColors.inkMuted,
  );

  /// Số liều, giờ uống: chữ số đều độ rộng để khó đọc nhầm.
  static const figure = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.3,
    color: AppColors.ink,
    fontFeatures: _tabular,
  );

  static const figureSmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: AppColors.ink,
    fontFeatures: _tabular,
  );
}

ThemeData buildAppTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.brand,
    primary: AppColors.brand,
    onPrimary: AppColors.onBrand,
    surface: AppColors.surface,
    onSurface: AppColors.ink,
    error: AppColors.danger,
  );

  const fieldBorder = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(AppRadius.field)),
    borderSide: BorderSide(color: AppColors.border),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.canvas,
    dividerColor: AppColors.border,
    textTheme: const TextTheme(
      headlineSmall: AppTextStyles.title,
      titleMedium: AppTextStyles.heading,
      bodyLarge: AppTextStyles.body,
      bodyMedium: AppTextStyles.body,
      bodySmall: AppTextStyles.caption,
      labelLarge: AppTextStyles.bodyStrong,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.canvas,
      foregroundColor: AppColors.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: false,
      titleTextStyle: AppTextStyles.heading,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      hintStyle: TextStyle(fontSize: 16, color: AppColors.inkMuted),
      border: fieldBorder,
      enabledBorder: fieldBorder,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.field)),
        borderSide: BorderSide(color: AppColors.brand, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.brand,
        foregroundColor: AppColors.onBrand,
        minimumSize: const Size(AppSizes.tapTarget, AppSizes.tapTarget),
        textStyle: AppTextStyles.bodyStrong,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.brand,
        minimumSize: const Size(AppSizes.tapTarget, AppSizes.tapTarget),
        textStyle: AppTextStyles.bodyStrong,
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
      contentTextStyle: TextStyle(fontSize: 16, color: AppColors.onBrand),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.canvas,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: AppTextStyles.heading,
      contentTextStyle: AppTextStyles.body,
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.brandTint,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppTextStyles.captionStrong.copyWith(color: AppColors.brand)
            : AppTextStyles.caption,
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 24,
          color: states.contains(WidgetState.selected)
              ? AppColors.brand
              : AppColors.inkMuted,
        ),
      ),
    ),
  );
}
