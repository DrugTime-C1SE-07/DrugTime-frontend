import 'package:flutter/material.dart';

/// Design tokens for colors extracted directly from Figma CSS specifications:
/// S00c · Đăng nhập (Số điện thoại / Email)
class AppColors {
  AppColors._();

  // Primary Brand
  static const Color brandPrimary = Color(0xFF01554F);
  static const Color brandPrimaryLight = Color(0xFFE7F3F1); // Trust card background
  static const Color brandPrimaryDark = Color(0xFF003D38);

  // Backgrounds & Surface
  static const Color background = Color(0xFFFCFCFC); // Content & status bar bg
  static const Color cardBackground = Color(0xFFFFFFFF); // Container & active tab bg
  static const Color pickerBackground = Color(0xFFF2F1ED); // Segmented picker track

  // Borders & Dividers
  static const Color border = Color(0xFFE4E4E1); // Container & input border
  static const Color divider = Color(0xFFE4E4E1); // Prefix vertical divider

  // Typography Colors
  static const Color textPrimary = Color(0xFF211D1D); // Heading, active tab, prefix
  static const Color textSecondary = Color(0xFF5B6169); // Subheading, placeholder, legal
  static const Color textWhite = Color(0xFFFFFFFF); // Button text

  // Feedback & Validation
  static const Color error = Color(0xFFD32F2F);
  static const Color success = Color(0xFF2E7D32);

  // Home Indicator
  static const Color homeIndicator = Color(0xFF211D1D);

  // Shadows
  static const List<BoxShadow> activeTabElevation = [
    BoxShadow(
      color: Color.fromRGBO(28, 32, 36, 0.0588235),
      offset: Offset(0, 4),
      blurRadius: 12,
      spreadRadius: -2,
    ),
    BoxShadow(
      color: Color.fromRGBO(28, 32, 36, 0.0705882),
      offset: Offset(0, 1),
      blurRadius: 2,
    ),
  ];

  static const List<BoxShadow> frameElevation = [
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.04),
      offset: Offset(0, 8),
      blurRadius: 24,
    ),
  ];
}
