import 'dart:convert';

import 'package:drugtime_mobile/core/notification/reminder_occurrence_generator.dart';

// FNV-1a 32-bit constants
const int _fnvOffsetBasis = 0x811c9dc5;
const int _fnvPrime = 0x01000193;
const int _mask32 = 0xFFFFFFFF;
const int _mask31 = 0x7FFFFFFF;

/// Tính ID thông báo Android/iOS (số nguyên 31-bit) từ [medicationScheduleId] và [scheduledAt].
///
/// Chuỗi canonical: `"$medicationScheduleId:$epochSeconds"` với epoch tính theo UTC.
/// Trả về số nguyên trong khoảng `[0, 2^31 - 1]`.
/// Ném [ArgumentError] nếu [scheduledAt] không phải UTC.
int notificationIdFor(int medicationScheduleId, DateTime scheduledAt) {
  if (!scheduledAt.isUtc) {
    throw ArgumentError.value(
      scheduledAt,
      'scheduledAt',
      'scheduledAt must be UTC',
    );
  }

  final epochSeconds = scheduledAt.millisecondsSinceEpoch ~/ 1000;
  final canonical = '$medicationScheduleId:$epochSeconds';
  final bytes = utf8.encode(canonical);

  var hash = _fnvOffsetBasis;
  for (final byte in bytes) {
    hash = ((hash ^ byte) * _fnvPrime) & _mask32;
  }

  // ponytail: 31-bit FNV-1a collision probability is ~9.4e-7 for n=64; if active reminders exceed 500, consider 64-bit ID or store lookup table.
  return hash & _mask31;
}

/// Dữ liệu đóng gói đính kèm trong thông báo để xử lý khi người dùng tương tác.
class NotificationPayload {
  NotificationPayload({
    required this.medicationScheduleId,
    required this.scheduledAt,
  }) {
    if (!scheduledAt.isUtc) {
      throw ArgumentError.value(
        scheduledAt,
        'scheduledAt',
        'scheduledAt must be UTC',
      );
    }
  }

  final int medicationScheduleId;
  final DateTime scheduledAt;

  /// Chuyển đổi payload thành chuỗi JSON.
  String serialize() {
    return jsonEncode({
      'schedule_id': medicationScheduleId,
      'scheduled_at': scheduledAt.toIso8601String(),
    });
  }

  /// Phân tích chuỗi JSON thành [NotificationPayload].
  ///
  /// Trả về `null` nếu chuỗi rỗng, không hợp lệ, thiếu trường hoặc mốc giờ không phải UTC.
  static NotificationPayload? tryParse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;

      final scheduleId = decoded['schedule_id'];
      final scheduledAtRaw = decoded['scheduled_at'];
      if (scheduleId is! int || scheduledAtRaw is! String) return null;

      final parsedTime = DateTime.tryParse(scheduledAtRaw);
      if (parsedTime == null || !parsedTime.isUtc) return null;

      return NotificationPayload(
        medicationScheduleId: scheduleId,
        scheduledAt: parsedTime,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NotificationPayload &&
        other.medicationScheduleId == medicationScheduleId &&
        other.scheduledAt.isAtSameMomentAs(scheduledAt);
  }

  @override
  int get hashCode => Object.hash(
        medicationScheduleId,
        scheduledAt.millisecondsSinceEpoch,
      );

  @override
  String toString() =>
      'NotificationPayload(scheduleId: $medicationScheduleId, scheduledAt: ${scheduledAt.toIso8601String()})';
}

/// Phát hiện các lượt nhắc bị trùng ID thông báo trong danh sách [occurrences].
///
/// Giữ lượt đầu tiên và bỏ qua lượt thứ hai, giữ nguyên [scheduledAt] (không tịnh tiến mốc giờ).
/// Có thể truyền [onCollision] để ghi nhận thông tin cảnh báo va chạm.
List<ReminderOccurrence> detectIdCollisions(
  Iterable<ReminderOccurrence> occurrences, {
  void Function(String message)? onCollision,
}) {
  final result = <ReminderOccurrence>[];
  final seenIds = <int, ReminderOccurrence>{};

  for (final occ in occurrences) {
    final id = notificationIdFor(occ.medicationScheduleId, occ.scheduledAt);
    final existing = seenIds[id];
    if (existing != null) {
      final msg =
          'Va chạm ID thông báo $id giữa lịch ${occ.medicationScheduleId} (${occ.scheduledAt.toIso8601String()}) và lịch ${existing.medicationScheduleId} (${existing.scheduledAt.toIso8601String()}). Bỏ qua lượt trùng.';
      onCollision?.call(msg);
      continue;
    }

    seenIds[id] = occ;
    result.add(occ);
  }

  return result;
}
