import '../../../adherence_history/domain/entities/adherence_history.dart';
import '../../../adherence_history/presentation/utils/adherence_history_format.dart';
import '../home_schedule_controller.dart';

/// Lời chào theo giờ Việt Nam: trước 11h sáng, từ 18h tối, còn lại trưa.
({String text, bool night}) homeGreeting(DateTime now) {
  final hour = HistoryFormat.vietnam(now).hour;
  if (hour < 11) return (text: 'Chào buổi sáng', night: false);
  if (hour >= 18) return (text: 'Chào buổi tối', night: true);
  return (text: 'Chào buổi trưa', night: false);
}

/// Pha ngày đêm của pet theo giờ Việt Nam.
enum NightPhase { awake, yawning, asleep }

/// Những gì pet cần biết về hôm nay, rút từ dữ liệu trang chủ. Thuần, không giữ trạng thái.
class HomePetSignals {
  const HomePetSignals({
    required this.ictMinutes,
    this.loading = false,
    this.failed = false,
    this.empty = false,
    this.inDoseWindow = false,
    this.missedToday = false,
    this.allDone = false,
    this.pending = false,
    this.remaining = false,
    this.streak = 0,
    this.confirmedSeq = 0,
    this.confirmFailedSeq = 0,
  });

  /// Phút trong ngày theo giờ Việt Nam (0..1439), không theo múi giờ thiết bị.
  final int ictMinutes;
  final bool loading, failed, empty;

  /// Có liều đang được phép xác nhận (cửa sổ -30/+120 phút của `canConfirm`).
  final bool inDoseWindow;
  final bool missedToday, allDone, pending;

  /// Hôm nay còn liều chưa uống (`taken + late < total`).
  final bool remaining;
  final int streak, confirmedSeq, confirmFailedSeq;

  static const yawnFrom = 21 * 60 + 30,
      sleepFrom = 22 * 60,
      sleepUntil = 5 * 60 + 30;

  NightPhase get phase {
    final m = ictMinutes;
    if (m >= sleepFrom || m < sleepUntil) return NightPhase.asleep;
    if (m >= yawnFrom) return NightPhase.yawning;
    return NightPhase.awake;
  }

  /// Bản sao với phút trong ngày khác (các cờ khác giữ nguyên).
  HomePetSignals withMinutes(int minutes) => HomePetSignals(
        ictMinutes: minutes,
        loading: loading,
        failed: failed,
        empty: empty,
        inDoseWindow: inDoseWindow,
        missedToday: missedToday,
        allDone: allDone,
        pending: pending,
        remaining: remaining,
        streak: streak,
        confirmedSeq: confirmedSeq,
        confirmFailedSeq: confirmFailedSeq,
      );

  static int minutesOf(DateTime now) {
    final v = HistoryFormat.vietnam(now);
    return v.hour * 60 + v.minute;
  }

  /// [empty]: người dùng chưa có thuốc nào (biến thể trang chủ rỗng).
  factory HomePetSignals.from(HomeScheduleController? c, DateTime now,
      {bool empty = false}) {
    final minutes = minutesOf(now);
    if (c == null) {
      return HomePetSignals(ictMinutes: minutes, empty: empty);
    }
    final doses = c.day?.doses ?? const <HistoryDose>[];
    final summary = c.day?.summary;
    return HomePetSignals(
      ictMinutes: minutes,
      loading: c.loading,
      failed: c.failed,
      empty: empty,
      inDoseWindow: doses.any(
          (d) => HomeScheduleController.canConfirm(d, now) && !c.isPending(d)),
      missedToday: doses.any((d) => d.status == HistoryDoseStatus.missed),
      allDone: summary != null &&
          summary.total > 0 &&
          summary.taken + summary.late == summary.total,
      pending: doses.any(c.isPending),
      remaining: summary != null &&
          summary.total > 0 &&
          summary.taken + summary.late < summary.total,
      streak: c.streak ?? 0,
      confirmedSeq: c.confirmedSeq,
      confirmFailedSeq: c.confirmFailedSeq,
    );
  }
}
