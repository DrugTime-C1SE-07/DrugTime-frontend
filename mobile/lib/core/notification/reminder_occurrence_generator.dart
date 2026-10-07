import 'package:drugtime_mobile/core/storage/local_db/local_models.dart';

/// Độ lệch múi giờ cố định của Việt Nam (Asia/Ho_Chi_Minh = UTC+7).
/// Không dùng múi giờ thiết bị, không đổi theo mùa (không có daylight saving time).
const Duration _vietnamOffset = Duration(hours: 7);

/// Đại diện cho một lượt nhắc uống thuốc cụ thể trong thời gian thực tế.
class ReminderOccurrence implements Comparable<ReminderOccurrence> {
  const ReminderOccurrence({
    required this.medicationScheduleId,
    required this.scheduledAt,
  });

  /// ID của dòng lịch uống thuốc trong cơ sở dữ liệu cục bộ ([LocalMedicationSchedule.id]).
  final int medicationScheduleId;

  /// Mốc thời gian nhắc uống thuốc theo chuẩn UTC ([DateTime.isUtc] == true).
  final DateTime scheduledAt;

  @override
  int compareTo(ReminderOccurrence other) {
    final timeComparison = scheduledAt.compareTo(other.scheduledAt);
    if (timeComparison != 0) {
      return timeComparison;
    }
    return medicationScheduleId.compareTo(other.medicationScheduleId);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReminderOccurrence &&
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
      'ReminderOccurrence(scheduleId: $medicationScheduleId, scheduledAt: ${scheduledAt.toIso8601String()})';
}

/// BQ-013 (Giả định, chờ xác nhận từ Tech Lead):
/// Kiểm tra xem lượt uống tại [scheduledAt] có nằm trong khoảng thời gian hiệu lực
/// của lịch [schedule] hay không.
///
/// Quy tắc:
/// - So sánh tức thời (instant comparison) theo mốc UTC:
///   `effective_from <= scheduled_at < ended_at`.
/// - `effective_from`: bao gồm (inclusive).
/// - `ended_at`: loại trừ (exclusive).
/// - `ended_at == null`: không giới hạn kết thúc.
bool _isScheduleEffective(
  LocalMedicationSchedule schedule,
  DateTime scheduledAt,
) {
  if (scheduledAt.isBefore(schedule.effectiveFrom)) {
    return false;
  }
  if (schedule.endedAt != null && !scheduledAt.isBefore(schedule.endedAt!)) {
    return false;
  }
  return true;
}

/// Sinh danh sách các lượt nhắc uống thuốc từ tập [schedules] trong cửa sổ `[from, to)`.
///
/// Yêu cầu:
/// - [from] và [to] bắt buộc phải là mốc UTC ([DateTime.isUtc] == true).
/// - Cửa sổ `[from, to)`: bao gồm [from], loại trừ [to].
/// - Nếu `to <= from` hoặc [schedules] rỗng: trả về danh sách rỗng.
/// - Các mốc giờ uống và thứ trong tuần được tính toán theo lịch ngày giờ Việt Nam (UTC+7).
/// - Kết quả được sắp xếp tăng dần theo [ReminderOccurrence.scheduledAt], hòa thì sắp xếp
///   theo [ReminderOccurrence.medicationScheduleId].
List<ReminderOccurrence> generateOccurrences({
  required Iterable<LocalMedicationSchedule> schedules,
  required DateTime from,
  required DateTime to,
}) {
  if (!from.isUtc || !to.isUtc) {
    throw ArgumentError(
      'Both "from" and "to" must be UTC DateTimes (isUtc == true). '
      'Received from: $from (isUtc: ${from.isUtc}), to: $to (isUtc: ${to.isUtc})',
    );
  }

  if (to.isBefore(from) || to.isAtSameMomentAs(from)) {
    return const [];
  }

  if (schedules.isEmpty) {
    return const [];
  }

  // Chuyển mốc thời gian UTC sang biểu diễn ngày giờ Việt Nam (UTC+7)
  final fromVn = from.add(_vietnamOffset);
  final toVn = to.add(_vietnamOffset);

  // Khởi tạo ngày duyệt bắt đầu và ngày kết thúc theo lịch Việt Nam
  var currentVnDay = DateTime.utc(fromVn.year, fromVn.month, fromVn.day);
  final endVnDay = DateTime.utc(toVn.year, toVn.month, toVn.day);

  final List<ReminderOccurrence> occurrences = [];
  final Set<String> deduplicationKeys = {};

  while (!currentVnDay.isAfter(endVnDay)) {
    // Thứ trong tuần theo chuẩn ISO 8601 (1 = Thứ Hai ... 7 = Chủ Nhật)
    final vnWeekday = currentVnDay.weekday;

    for (final schedule in schedules) {
      if (!schedule.reminderEnabled) {
        continue;
      }

      if (!schedule.daysOfWeek.contains(vnWeekday)) {
        continue;
      }

      final timeParts = schedule.intakeTime.split(':');
      final hour = int.parse(timeParts[0]);
      final minute = timeParts.length > 1 ? int.parse(timeParts[1]) : 0;
      final second = timeParts.length > 2 ? int.parse(timeParts[2]) : 0;

      // Tạo mốc thời gian UTC cho lượt nhắc bằng cách trừ cố định 7 giờ từ ngày giờ VN
      final scheduledAt = DateTime.utc(
        currentVnDay.year,
        currentVnDay.month,
        currentVnDay.day,
        hour,
        minute,
        second,
      ).subtract(_vietnamOffset);
      
      // Lọc theo cửa sổ [from, to): bao gồm from, loại trừ to
      if (scheduledAt.isBefore(from) || !scheduledAt.isBefore(to)) {
        continue;
      }

      // Lọc theo khoảng hiệu lực của lịch (BQ-013)
      if (!_isScheduleEffective(schedule, scheduledAt)) {
        continue;
      }

      final key = '${schedule.id}_${scheduledAt.millisecondsSinceEpoch}';
      if (deduplicationKeys.add(key)) {
        occurrences.add(
          ReminderOccurrence(
            medicationScheduleId: schedule.id,
            scheduledAt: scheduledAt,
          ),
        );
      }
    }

    currentVnDay = currentVnDay.add(const Duration(days: 1));
  }

  occurrences.sort();
  return occurrences;
}
