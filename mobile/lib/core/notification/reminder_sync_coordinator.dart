import '../storage/local_db/local_medication_store.dart';
import '../sync/schedule_sync_service.dart';
import 'notification_id.dart';
import 'reminder_notification_scheduler.dart';
import 'reminder_occurrence_generator.dart';

/// Đồng bộ lịch uống từ server về máy rồi lập lại toàn bộ nhắc thuốc cục bộ.
///
/// - QD-22: lập các nhắc trong [horizon] (mục tiêu 7 ngày), chạy lại khi mở app có
///   phiên và khi sửa thuốc.
/// - QD-33: lỗi mạng/API thì vẫn lập nhắc từ lịch đã lưu trên máy.
/// - Các lần gọi chạy tuần tự để không hủy/lập chồng lên nhau.
class ReminderSyncCoordinator {
  ReminderSyncCoordinator({
    required ScheduleSyncService syncService,
    required LocalMedicationStore localStore,
    required ReminderNotificationScheduler scheduler,
    DateTime Function()? clock,
    this.onLog,
    this.horizon = const Duration(days: 7),
  })  : _syncService = syncService,
        _localStore = localStore,
        _scheduler = scheduler,
        _clock = clock ?? DateTime.timestamp;

  final ScheduleSyncService _syncService;
  final LocalMedicationStore _localStore;
  final ReminderNotificationScheduler _scheduler;
  final DateTime Function() _clock;
  final void Function(String message)? onLog;
  final Duration horizon;

  Future<void> _tail = Future.value();

  /// Đồng bộ lịch của [patientId] và lập lại nhắc. Không ném lỗi ra ngoài: lỗi được
  /// ghi qua [onLog] để không chặn luồng đăng nhập hay sửa thuốc.
  Future<void> refresh(String patientId) => _queue(() async {
        try {
          await _syncService.syncSchedulesFromServer(patientId: patientId);
        } on Exception catch (e) {
          onLog?.call('Không đồng bộ được lịch uống, dùng lịch cục bộ: $e');
        }
        try {
          final schedules =
              await _localStore.getActiveSchedules(patientId: patientId);
          final now = _clock().toUtc();
          await _cancelPendingReminders(onlyFrom: now);
          final occurrences = generateOccurrences(
            schedules: schedules,
            from: now,
            to: now.add(horizon),
          );
          // QD-21: liều đã ghi nhận (kể cả xác nhận sớm) không nhắc lại.
          final pending = <ReminderOccurrence>[];
          for (final occ in occurrences) {
            final recorded = await _localStore.hasDoseLog(
              medicationScheduleId: occ.medicationScheduleId,
              scheduledAt: occ.scheduledAt,
            );
            if (!recorded) pending.add(occ);
          }
          await _scheduler.scheduleOccurrences(pending);
        } on Exception catch (e) {
          onLog?.call('Không lập được nhắc uống thuốc: $e');
        }
      });

  /// Hủy mọi nhắc thuốc đang chờ (đăng xuất). Không đụng thông báo người thân.
  Future<void> clear() => _queue(_cancelPendingReminders);

  /// Hủy nhắc thuốc đang chờ. Có [onlyFrom] thì chỉ hủy lượt có giờ dự kiến từ mốc
  /// đó trở đi (sẽ được lập lại); nhắc hoãn cữ giữ giờ gốc đã qua nên được giữ.
  Future<void> _cancelPendingReminders({DateTime? onlyFrom}) async {
    final pending = await _scheduler.platform.pendingNotificationRequests();
    for (final request in pending) {
      final payload = NotificationPayload.tryParse(request.payload);
      if (payload == null) continue;
      if (onlyFrom != null && payload.scheduledAt.isBefore(onlyFrom)) continue;
      await _scheduler.platform.cancel(request.id);
    }
  }

  Future<void> _queue(Future<void> Function() action) {
    final run = _tail.then((_) => action());
    _tail = run.catchError((Object _) {});
    return run;
  }
}
