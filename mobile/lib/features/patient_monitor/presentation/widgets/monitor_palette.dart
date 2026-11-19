import 'package:flutter/material.dart';

import '../../../family_link/presentation/garden/garden_mood.dart';
import '../../domain/monitor_digest.dart';

/// Màu và ánh xạ dùng chung cho các màn người thân (hub, hôm nay, chi tiết liều, lịch sử).
abstract final class MonitorColors {
  static const purple = Color(0xFF5B3FA8);
  static const purpleTint = Color(0xFFECE7FB);
  static const canvas = Color(0xFFF7F6F3);

  static const taken = Color(0xFF1E7A4C);
  static const takenTint = Color(0xFFE3F4EA);
  static const late = Color(0xFFD9822B);
  static const lateTint = Color(0xFFFFF0DF);
  static const missed = Color(0xFFD64545);
  static const missedTint = Color(0xFFFCE9E9);
  static const upcoming = Color(0xFFD5D9DE);
  static const upcomingTint = Color(0xFFEFF1F3);
  static const nudged = Color(0xFF9A5B13);
  static const nudgedTint = Color(0xFFFFF3DD);

  static Color segment(DoseSegment s) => switch (s) {
        DoseSegment.taken => taken,
        DoseSegment.late => late,
        DoseSegment.missed || DoseSegment.overdue => missed,
        DoseSegment.upcoming => upcoming,
      };

  static Color strip(StripMark m) => switch (m) {
        StripMark.onTime => taken,
        StripMark.late => late,
        StripMark.missed => missed,
        StripMark.pending => upcoming,
        StripMark.none => upcomingTint,
      };

  /// Cặp màu nền/chữ cho avatar chữ cái, ổn định theo id.
  static const _avatars = [
    (Color(0xFFFCE8D5), Color(0xFFB4561E)),
    (Color(0xFFDDEBFA), Color(0xFF1F5E9E)),
    (Color(0xFFE6E0F8), Color(0xFF5B3FA8)),
    (Color(0xFFDDF2E6), Color(0xFF1E7A4C)),
    (Color(0xFFFBE0E8), Color(0xFFB0365E)),
  ];

  static (Color, Color) avatar(String id) {
    var h = 0;
    for (final c in id.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return _avatars[h % _avatars.length];
  }
}

/// Chữ cái đầu của tên (chữ đầu của từ đầu và từ cuối), vd. "Mẹ Hoa" → "MH".
String nameInitials(String name) {
  final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  if (words.isEmpty) return '?';
  final first = words.first.characters.first.toUpperCase();
  if (words.length == 1) return first;
  return first + words.last.characters.first.toUpperCase();
}

/// Trạng thái chăm sóc → trạng thái cảnh khu vườn.
GardenMood gardenMoodFor(CareMood mood) => switch (mood) {
      CareMood.ok => GardenMood.ok,
      // quá giờ chưa xác nhận dùng cùng cảnh nhẹ nhàng (bạn ngủ gật được mang thuốc tới)
      CareMood.missed || CareMood.overdue => GardenMood.missed,
      CareMood.nudged => GardenMood.nudged,
      CareMood.recovered => GardenMood.recovered,
    };

/// Trạng thái chăm sóc → dáng chậu cây của người đó.
PlantShape plantShapeFor(CareMood mood) => switch (mood) {
      CareMood.ok => PlantShape.bloom,
      CareMood.missed ||
      CareMood.overdue ||
      CareMood.nudged =>
        PlantShape.droop,
      CareMood.recovered => PlantShape.revive,
    };
