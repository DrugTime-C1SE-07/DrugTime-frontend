import 'package:flutter/material.dart';

/// Colors for the compact, prototype-led Reminder surfaces.
abstract final class ReminderPalette {
  static const canvas = Color(0xFFFFF9F2);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceTint = Color(0xFFE8F4F1);
  static const header = Color(0xFFFFF0DD);
  static const outline = Color(0xFFFFE2C5);
  static const teal = Color(0xFF01554F);
  static const tealDark = Color(0xFF003D38);
  static const success = Color(0xFF1E7A45);
  static const successBackground = Color(0xFFDDF3E4);
  static const missed = Color(0xFFC2410C);
  static const missedBackground = Color(0xFFFFE1DC);
  static const pending = Color(0xFF687579);
  static const pendingBackground = Color(0xFFF1F1EE);

  static const morningBackground = Color(0xFFFFE7CE);
  static const morningInk = Color(0xFFB94712);
  static const noonBackground = Color(0xFFFFF1BE);
  static const noonInk = Color(0xFF8B6500);
  static const afternoonBackground = Color(0xFFFFEAD4);
  static const afternoonInk = Color(0xFFB35B1E);
  static const eveningBackground = Color(0xFFEDE7FF);
  static const eveningInk = Color(0xFF6941C6);

  /// A restrained time-of-day tint; the Reminder page does not reuse Home's
  /// landscape scene or its large hero composition.
  static Color headerFor(DateTime instant) {
    final hour = instant.toUtc().add(const Duration(hours: 7)).hour;
    return switch (hour) {
      < 10 => const Color(0xFFFFF0DD),
      < 16 => const Color(0xFFFFF3D8),
      < 19 => const Color(0xFFFFEBDD),
      _ => const Color(0xFFF1ECFA),
    };
  }

  static ({Color background, Color foreground, IconData icon}) period(
      String section) {
    if (section == 'BUỔI SÁNG') {
      return (
        background: morningBackground,
        foreground: morningInk,
        icon: Icons.wb_sunny_outlined
      );
    }
    if (section == 'BUỔI TRƯA') {
      return (
        background: noonBackground,
        foreground: noonInk,
        icon: Icons.wb_sunny_rounded
      );
    }
    if (section == 'BUỔI CHIỀU') {
      return (
        background: afternoonBackground,
        foreground: afternoonInk,
        icon: Icons.wb_twilight_outlined
      );
    }
    return (
      background: eveningBackground,
      foreground: eveningInk,
      icon: Icons.nightlight_round
    );
  }
}
