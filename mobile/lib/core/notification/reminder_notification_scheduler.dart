import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:drugtime_mobile/core/notification/notification_id.dart';
import 'package:drugtime_mobile/core/notification/notification_service.dart';
import 'package:drugtime_mobile/core/notification/reminder_occurrence_generator.dart';

/// Dịch vụ lên lịch và hủy thông báo nhắc uống thuốc cục bộ trên Android/iOS.
///
/// Tuân thủ:
/// - Quyết định NT-02: Không chứa tên thuốc trên màn hình khóa.
/// - Quyết định CD7: Múi giờ cố định Asia/Ho_Chi_Minh (UTC+7), không dùng múi giờ thiết bị.
/// - Thời điểm hiện tại luôn được tiêm qua clock provider.
class ReminderNotificationScheduler {
  ReminderNotificationScheduler({
    required this.platform,
    required this.location,
    DateTime Function()? clockProvider,
    this.onTakeDose,
    this.onLog,
  }) : _clock = clockProvider ?? DateTime.timestamp;

  final NotificationPlatform platform;
  final tz.Location location;
  final DateTime Function() _clock;

  /// Callback xử lý khi người dùng nhấn nút hành động "Đã uống".
  final Future<void> Function(NotificationPayload payload)? onTakeDose;

  /// Callback ghi log chẩn đoán hoặc cảnh báo va chạm/fallback.
  final void Function(String message)? onLog;

  static const String actionTakeDose = 'take_dose';
  static const String actionTakeDoseTitle = 'Đã uống';
  static const String defaultTitle = 'Nhắc uống thuốc';
  static const String defaultBody = 'Đã đến giờ uống thuốc theo lịch';

  /// Lên lịch các lượt nhắc uống thuốc từ danh sách [occurrences].
  ///
  /// Quy trình:
  /// 1. Lọc bỏ các lượt quá khứ hoặc trùng thời điểm hiện tại (`scheduledAt <= now`).
  /// 2. Khử trùng lặp ID thông báo bằng [detectIdCollisions].
  /// 3. Lên lịch từng lượt với chế độ ưu tiên [AndroidScheduleMode.exactAllowWhileIdle].
  /// 4. Nếu thiếu quyền exact alarm (ném ngoại lệ), tự động fallback sang
  ///    [AndroidScheduleMode.inexactAllowWhileIdle] và ghi log (lưu ý: không đạt NFR04).
  Future<void> scheduleOccurrences(
    Iterable<ReminderOccurrence> occurrences,
  ) async {
    final now = _clock().toUtc();

    // Lọc bỏ lượt trong quá khứ hoặc hiện tại
    final futureOccurrences =
        occurrences.where((occ) => occ.scheduledAt.isAfter(now));

    // Khử trùng lặp va chạm ID
    final deduplicated = detectIdCollisions(
      futureOccurrences,
      onCollision: onLog,
    );

    for (final occ in deduplicated) {
      final id = notificationIdFor(occ.medicationScheduleId, occ.scheduledAt);
      final payload = NotificationPayload(
        medicationScheduleId: occ.medicationScheduleId,
        scheduledAt: occ.scheduledAt,
      ).serialize();

      final scheduledDate = tz.TZDateTime.from(occ.scheduledAt, location);

      const androidNotificationDetails = AndroidNotificationDetails(
        NotificationService.reminderChannelId,
        NotificationService.reminderChannelName,
        channelDescription: NotificationService.reminderChannelDescription,
        importance: Importance.max,
        priority: Priority.high,
        actions: [
          AndroidNotificationAction(
            actionTakeDose,
            actionTakeDoseTitle,
            showsUserInterface: false,
            cancelNotification: true,
          ),
        ],
      );

      const notificationDetails = NotificationDetails(
        android: androidNotificationDetails,
      );

      try {
        await platform.zonedSchedule(
          id,
          defaultTitle,
          defaultBody,
          scheduledDate,
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: payload,
        );
      } catch (e) {
        onLog?.call(
          'Lỗi lên lịch exact alarm cho thông báo $id: $e. '
          'Fallback sang inexactAllowWhileIdle (lưu ý: không thỏa mãn NFR04 về độ trễ).',
        );

        await platform.zonedSchedule(
          id,
          defaultTitle,
          defaultBody,
          scheduledDate,
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: payload,
        );
      }
    }
  }

  /// Hủy một lượt thông báo cụ thể (idempotent).
  Future<void> cancelOccurrence({
    required int medicationScheduleId,
    required DateTime scheduledAt,
  }) async {
    final id = notificationIdFor(medicationScheduleId, scheduledAt);
    await platform.cancel(id);
  }

  /// Hủy toàn bộ các thông báo đang chờ thuộc về [medicationScheduleId].
  ///
  /// Đọc danh sách pending notifications từ plugin, trích xuất payload và
  /// chỉ hủy các thông báo có đúng ID lịch tương ứng.
  Future<void> cancelAllForSchedule(int medicationScheduleId) async {
    final pendingRequests = await platform.pendingNotificationRequests();

    for (final request in pendingRequests) {
      final payload = NotificationPayload.tryParse(request.payload);
      if (payload != null &&
          payload.medicationScheduleId == medicationScheduleId) {
        await platform.cancel(request.id);
      }
    }
  }

  /// Xử lý phản hồi khi người dùng tương tác với thông báo hoặc bấm nút "Đã uống".
  ///
  /// Chỉ xử lý trên tiến trình đang hoạt động (foreground/background active).
  Future<void> handleNotificationResponse(NotificationResponse response) async {
    if (response.actionId == actionTakeDose && response.payload != null) {
      final payload = NotificationPayload.tryParse(response.payload);
      if (payload != null) {
        await onTakeDose?.call(payload);
        if (response.id != null) {
          await platform.cancel(response.id!);
        }
      }
    }
  }
}
