import '../../domain/entities/adherence_history.dart';

enum HistoryDayMarker { complete, missed, pending }

abstract final class HistoryFormat {
  static DateTime vietnam(DateTime instant) =>
      instant.toUtc().add(const Duration(hours: 7));
  static DateTime date(DateTime calendar) =>
      DateTime.utc(calendar.year, calendar.month, calendar.day);
  static DateTime today(DateTime instant) => date(vietnam(instant));
  static DateTime month(DateTime calendar) =>
      DateTime.utc(calendar.year, calendar.month);

  static List<DateTime> week(DateTime calendar) {
    final first = date(calendar).subtract(Duration(days: calendar.weekday - 1));
    return List.generate(7, (index) => first.add(Duration(days: index)));
  }

  static const weekdays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

  static String weekday(DateTime calendar) =>
      calendar.weekday == 7 ? 'Chủ nhật' : 'Thứ ${calendar.weekday + 1}';

  static String dayHeading(DateTime calendar, {required DateTime today}) =>
      '${weekday(calendar)}, ${day(calendar)}${calendar == today ? ' · Hôm nay' : ''}';

  static ({DateTime from, DateTime to}) period(
      DateTime selected, DateTime now) {
    final current = today(now);
    final first = month(selected);
    final last = DateTime.utc(first.year, first.month + 1, 0);
    return (from: first, to: last.isAfter(current) ? current : last);
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
  static String day(DateTime calendar) =>
      '${_two(calendar.day)}/${_two(calendar.month)}/${calendar.year}';
  static String shortDay(DateTime calendar, {required DateTime reference}) =>
      '${_two(calendar.day)}/${_two(calendar.month)}${calendar.year != reference.year ? '/${calendar.year}' : ''}';
  static String status(HistoryDoseStatus status) => switch (status) {
        HistoryDoseStatus.taken => 'Đã uống',
        HistoryDoseStatus.late => 'Trễ',
        HistoryDoseStatus.missed => 'Bỏ lỡ',
        HistoryDoseStatus.pending => 'Chờ',
        HistoryDoseStatus.unverified => 'Chưa xác minh',
      };
  static String time(DateTime instant) {
    final vn = vietnam(instant);
    return '${_two(vn.hour)}:${_two(vn.minute)}';
  }

  static String actual(HistoryDose dose) {
    final taken = dose.takenAt;
    if (taken == null) return 'Chưa ghi nhận đã uống';
    final different = today(taken) != today(dose.scheduledAt);
    return 'Đã uống lúc ${time(taken)}${different ? ' · ${day(today(taken))}' : ''}';
  }

  static String rate(double? value) => value == null
      ? 'Chưa tính'
      : '${value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '').replaceAll('.', ',')}%';

  static HistoryDayMarker? marker(AdherenceSummary? summary) {
    if (summary == null) return null;
    if (summary.missed > 0) return HistoryDayMarker.missed;
    if (summary.counted > 0) return HistoryDayMarker.complete;
    // Liều chưa xác minh hiển thị trung tính như liều đang chờ (3.19).
    return summary.pending > 0 || summary.unverified > 0
        ? HistoryDayMarker.pending
        : null;
  }
}
