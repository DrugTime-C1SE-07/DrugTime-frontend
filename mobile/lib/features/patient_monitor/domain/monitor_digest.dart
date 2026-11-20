import '../../adherence/domain/entities/adherence_history.dart';
import 'monitor_models.dart';

/// Tính toán thuần (không I/O) cho các màn người thân: thanh tiến độ, dòng tóm tắt,
/// chuỗi ngày, dải 7 ngày và trạng thái chăm sóc. Mọi mốc ngày theo giờ Việt Nam.
///
/// Trạng thái quá khứ luôn lấy từ server: chỉ `bo_lo` mới là [DoseSegment.missed];
/// quá giờ mà chưa có xác nhận (chờ / chưa xác minh) là [DoseSegment.overdue].

/// Một đoạn trên thanh tiến độ của card bệnh nhân.
enum DoseSegment { taken, late, missed, overdue, upcoming }

DoseSegment segmentOf(AdherenceDose dose, DateTime asOf) {
  if (dose.takenAt != null) {
    return dose.status == AdherenceDoseStatus.late
        ? DoseSegment.late
        : DoseSegment.taken;
  }
  if (dose.status == AdherenceDoseStatus.missed) return DoseSegment.missed;
  return dose.scheduledAt.isAfter(asOf)
      ? DoseSegment.upcoming
      : DoseSegment.overdue;
}

List<DoseSegment> doseSegments(List<AdherenceDose> doses, DateTime asOf) =>
    [for (final dose in doses) segmentOf(dose, asOf)];

/// Liều cần người thân chú ý: bỏ lỡ (server xác minh) hoặc quá giờ chưa xác nhận.
bool needsAttention(AdherenceDose dose, DateTime asOf) {
  final s = segmentOf(dose, asOf);
  return s == DoseSegment.missed || s == DoseSegment.overdue;
}

enum SummaryTone { alert, good, neutral }

class HubSummary {
  const HubSummary(
      {required this.confirmed,
      required this.total,
      required this.line,
      required this.tone,
      this.next});
  final int confirmed, total;
  final String line;
  final SummaryTone tone;

  /// Liều sắp tới gần nhất, nếu có.
  final AdherenceDose? next;
}

HubSummary hubSummary(List<AdherenceDose> doses, DateTime asOf) {
  final confirmed = doses.where((d) => d.takenAt != null).length;
  final total = doses.length;
  AdherenceDose? next;
  for (final dose in doses) {
    if (segmentOf(dose, asOf) == DoseSegment.upcoming) {
      next = dose;
      break;
    }
  }
  final count = '$confirmed/$total liều';
  AdherenceDose? first(DoseSegment s) {
    for (final dose in doses) {
      if (segmentOf(dose, asOf) == s) return dose;
    }
    return null;
  }

  if (total == 0) {
    return const HubSummary(
        confirmed: 0,
        total: 0,
        line: 'Hôm nay không có lịch uống',
        tone: SummaryTone.neutral);
  }
  final missed = first(DoseSegment.missed);
  if (missed != null) {
    return HubSummary(
        confirmed: confirmed,
        total: total,
        next: next,
        tone: SummaryTone.alert,
        line:
            '$count · Bỏ lỡ ${missed.medicationName} ${monitorTime(missed.scheduledAt)}');
  }
  final overdue = first(DoseSegment.overdue);
  if (overdue != null) {
    return HubSummary(
        confirmed: confirmed,
        total: total,
        next: next,
        tone: SummaryTone.alert,
        line:
            '$count · Chưa xác nhận ${overdue.medicationName} ${monitorTime(overdue.scheduledAt)}');
  }
  if (confirmed == total) {
    return HubSummary(
        confirmed: confirmed,
        total: total,
        tone: SummaryTone.good,
        line: '$count · Đã uống đủ hôm nay');
  }
  return HubSummary(
      confirmed: confirmed,
      total: total,
      next: next,
      tone: confirmed > 0 ? SummaryTone.good : SummaryTone.neutral,
      line:
          confirmed > 0 ? '$count · Đang đúng lịch' : '$count · Chưa tới giờ');
}

/// Số ngày liên tục (tính tới hôm nay) mà mọi liều đã tới giờ đều được uống.
///
/// Hôm nay chưa có liều nào tới giờ thì không làm đứt chuỗi và không được cộng.
/// Chỉ xét trong khoảng ngày có ở [history] (màn hôm nay tải 7 ngày).
int streakDays(AdherenceHistory history, DateTime now) {
  final today = monitorDay(now);
  final byDay = {
    for (final group in history.groups)
      DateTime.utc(group.date.year, group.date.month, group.date.day): group
  };
  var streak = 0;
  for (var offset = 0;; offset++) {
    final day = today.subtract(Duration(days: offset));
    if (day.isBefore(DateTime.utc(
        history.from.year, history.from.month, history.from.day))) {
      break;
    }
    final doses = (byDay[day]?.doses ?? const <AdherenceDose>[])
        .where((d) => !d.scheduledAt.isAfter(history.asOf))
        .toList();
    if (doses.isEmpty) {
      if (offset == 0) continue;
      break;
    }
    if (doses.every((d) => d.takenAt != null)) {
      streak++;
    } else {
      break;
    }
  }
  return streak;
}

/// Ô trên dải 7 ngày của một lịch uống (màn chi tiết liều).
enum StripMark { onTime, late, missed, pending, none }

class StripDay {
  const StripDay(this.day, this.mark);
  final DateTime day;
  final StripMark mark;
}

List<StripDay> scheduleStrip(
    AdherenceHistory history, int scheduleId, DateTime now) {
  final today = monitorDay(now);
  return [
    for (var offset = 6; offset >= 0; offset--)
      () {
        final day = today.subtract(Duration(days: offset));
        AdherenceDose? dose;
        for (final group in history.groups) {
          if (group.date.year != day.year ||
              group.date.month != day.month ||
              group.date.day != day.day) {
            continue;
          }
          for (final d in group.doses) {
            if (d.scheduleId == scheduleId) {
              dose = d;
              break;
            }
          }
        }
        final mark = dose == null
            ? StripMark.none
            : switch (dose.status) {
                AdherenceDoseStatus.taken => StripMark.onTime,
                AdherenceDoseStatus.late => StripMark.late,
                AdherenceDoseStatus.missed => StripMark.missed,
                _ => StripMark.pending,
              };
        return StripDay(day, mark);
      }(),
  ];
}

/// Trạng thái chăm sóc trong ngày, quyết định card trạng thái và cảnh khu vườn.
enum CareMood {
  /// Không có liều cần chú ý.
  ok,

  /// Có liều bỏ lỡ (server đã xác minh `bo_lo`), chưa nhắc.
  missed,

  /// Chỉ có liều quá giờ nhưng chưa xác nhận (chờ / chưa xác minh), chưa nhắc.
  /// Client không được tự kết luận là "chưa uống" (QD-24/25): người bệnh có thể đã uống
  /// mà điện thoại chưa đồng bộ.
  overdue,

  /// Có liều cần chú ý và người thân đã gửi nhắc cho liều đó.
  nudged,

  /// Không còn liều cần chú ý và có liều đã uống bù (uống trễ) hôm nay.
  recovered,
}

CareMood careMood(List<AdherenceDose> doses, DateTime asOf,
    {required bool Function(AdherenceDose dose) nudged}) {
  final attention = doses.where((d) => needsAttention(d, asOf)).toList();
  if (attention.isNotEmpty) {
    if (attention.any(nudged)) return CareMood.nudged;
    return attention.any((d) => segmentOf(d, asOf) == DoseSegment.missed)
        ? CareMood.missed
        : CareMood.overdue;
  }
  return doses.any((d) => segmentOf(d, asOf) == DoseSegment.late)
      ? CareMood.recovered
      : CareMood.ok;
}

/// "1 giờ 45 phút", "45 phút", "dưới 1 phút".
String formatDelay(Duration delay) {
  final minutes = delay.inMinutes;
  if (minutes < 1) return 'dưới 1 phút';
  final h = minutes ~/ 60, m = minutes % 60;
  if (h == 0) return '$m phút';
  return m == 0 ? '$h giờ' : '$h giờ $m phút';
}

/// Dạng ngắn cho dòng chi tiết: "1g50", "45p".
String formatDelayShort(Duration delay) {
  final minutes = delay.inMinutes;
  final h = minutes ~/ 60, m = minutes % 60;
  if (h == 0) return '${m}p';
  return '${h}g${m.toString().padLeft(2, '0')}';
}
