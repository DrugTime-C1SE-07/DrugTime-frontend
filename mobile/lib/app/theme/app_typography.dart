import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Typography tokens based on Figma design specification:
/// Font family: 'Inter', fallbacks to system sans-serif.
class AppTypography {
  AppTypography._();

  static const String fontFamily = 'Inter';

  // Heading: 22px / line-height: 30px / 700 bold
  static const TextStyle heading = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22.0,
    fontWeight: FontWeight.w700,
    height: 30.0 / 22.0, // 1.36
    color: AppColors.textPrimary,
    letterSpacing: -0.2,
  );

  // Subheading: 13px / line-height: 19px / 400 regular
  static const TextStyle subheading = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13.0,
    fontWeight: FontWeight.w400,
    height: 19.0 / 13.0, // 1.46
    color: AppColors.textSecondary,
  );

  // Field Label: 13px / line-height: 19px / 400 regular
  static const TextStyle fieldLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13.0,
    fontWeight: FontWeight.w400,
    height: 19.0 / 13.0,
    color: AppColors.textPrimary,
  );

  // Input Text & Prefix: 15px / line-height: 22px / 400 regular
  static const TextStyle inputText = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15.0,
    fontWeight: FontWeight.w400,
    height: 22.0 / 15.0,
    color: AppColors.textPrimary,
  );

  static const TextStyle inputPlaceholder = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15.0,
    fontWeight: FontWeight.w400,
    height: 22.0 / 15.0,
    color: AppColors.textSecondary,
  );

  static const TextStyle prefix = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15.0,
    fontWeight: FontWeight.w400,
    height: 22.0 / 15.0,
    color: AppColors.textPrimary,
  );

  // Segmented tab active: 14px / line-height: 20px / 400 regular / #211D1D
  static const TextStyle tabActive = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14.0,
    fontWeight: FontWeight.w500,
    height: 20.0 / 14.0,
    color: AppColors.textPrimary,
  );

  // Segmented tab inactive: 14px / line-height: 20px / 400 regular / #5B6169
  static const TextStyle tabInactive = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14.0,
    fontWeight: FontWeight.w400,
    height: 20.0 / 14.0,
    color: AppColors.textSecondary,
  );

  // Primary Button Label: 15px / line-height: 22px / 400 regular / #FFFFFF
  static const TextStyle buttonLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15.0,
    fontWeight: FontWeight.w500,
    height: 22.0 / 15.0,
    color: AppColors.textWhite,
  );

  // Helper text: 11.5px / line-height: 17px / 400 regular / #5B6169
  static const TextStyle helperText = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11.5,
    fontWeight: FontWeight.w400,
    height: 17.0 / 11.5,
    color: AppColors.textSecondary,
  );

  // Trust Card Label: 12.5px / line-height: 18px / 400 regular / #211D1D
  static const TextStyle trustLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12.5,
    fontWeight: FontWeight.w400,
    height: 18.0 / 12.5,
    color: AppColors.textPrimary,
  );

  // Legal text: 11.5px / line-height: 17px / 400 regular / #5B6169
  static const TextStyle legal = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11.5,
    fontWeight: FontWeight.w400,
    height: 17.0 / 11.5,
    color: AppColors.textSecondary,
  );

  // Status bar time: 14px / line-height: 20px / 600 semi-bold / #211D1D
  static const TextStyle statusBarTime = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14.0,
    fontWeight: FontWeight.w600,
    height: 20.0 / 14.0,
    color: AppColors.textPrimary,
  );
}
