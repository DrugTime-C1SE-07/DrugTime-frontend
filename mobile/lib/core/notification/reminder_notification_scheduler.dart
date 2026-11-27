import 'dart:ui';
import 'package:flutter/foundation.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:drugtime_mobile/core/notification/notification_id.dart';
import 'package:drugtime_mobile/core/notification/notification_service.dart';
import 'package:drugtime_mobile/core/notification/reminder_occurrence_generator.dart';
import 'package:drugtime_mobile/core/notification/reminder_sound.dart';
import 'package:drugtime_mobile/core/notification/reminder_scheduler.dart';

/// Dịch vụ lên lịch và hủy thông báo nhắc uống thuốc cục bộ trên Android/iOS.
///
/// Tuân thủ:
/// - Quyết định NT-02: Không chứa tên thuốc trên màn hình khóa.
/// - Quyết định CD7: Múi giờ cố định Asia/Ho_Chi_Minh (UTC+7), không dùng múi giờ thiết bị.
/// - Thời điểm hiện tại luôn được tiêm qua clock provider.
/// - Triển khai [ReminderScheduler] để hỗ trợ thao tác hoãn cữ (snooze).
class ReminderNotificationScheduler implements ReminderScheduler {
  ReminderNotificationScheduler({
    required this.platform,
    required this.location,
    DateTime Function()? clockProvider,
    this.onTakeDose,
    this.onLog,
    this.targetPlatform,
    ReminderSound Function()? soundChannel,
  })  : _clock = clockProvider ?? DateTime.timestamp,
        _soundChannel = soundChannel ?? (() => ReminderSounds.system);

  static const int maxIosScheduledNotifications = 64;

  final NotificationPlatform platform;
  final tz.Location location;
  final DateTime Function() _clock;
  final TargetPlatform? targetPlatform;

  /// Âm đang chọn (S08-4a); chỉ đổi channel, mọi trường khác giữ nguyên (QD-26).
  final ReminderSound Function() _soundChannel;

  /// Callback xử lý khi người dùng nhấn nút hành động "Đã uống".
  final Future<void> Function(NotificationPayload payload)? onTakeDose;

  /// Callback ghi log chẩn đoán hoặc cảnh báo va chạm/fallback.
  final void Function(String message)? onLog;

  static const String actionTakeDose = 'take_dose';
  static const String actionTakeDoseTitle = 'Đã uống';
  static const String defaultTitle = 'Nhắc uống thuốc';
  static const String defaultBody = 'Đã đến giờ uống thuốc theo lịch';

  NotificationDetails get _notificationDetails {
    final sound = _soundChannel();
    return NotificationDetails(
      android: AndroidNotificationDetails(
        sound.channelId,
        sound.channelName,
        channelDescription: NotificationService.reminderChannelDescription,
        importance: Importance.max,
        priority: Priority.high,
        fullScreenIntent: true,
        category: AndroidNotificationCategory.alarm,
        color: const Color(0xFF004D40),
        playSound: sound.playsSound,
        sound: sound.androidSound,
        enableVibration: true,
      ),
    );
  }

  /// Lên lịch các lượt nhắc uống thuốc từ danh sách [occurrences].
  ///
  /// Quy trình:
  /// 1. Lọc bỏ các lượt quá khứ hoặc trùng thời điểm hiện tại (`scheduledAt <= now`).
  /// 2. Khử trùng lặp ID thông báo bằng [detectIdCollisions].
  /// 3. Gộp các thuốc cùng giờ thành một thông báo (thuốc có ID nhỏ nhất làm đại diện):
  ///    màn nhắc tự gom mọi thuốc cùng giờ, nên nhiều thông báo giống hệt chỉ là trùng.
  /// 4. Lên lịch từng mốc với chế độ ưu tiên [AndroidScheduleMode.exactAllowWhileIdle].
  /// 5. Nếu thiếu quyền exact alarm (ném ngoại lệ), tự động fallback sang
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

    final slots = <DateTime, List<int>>{};
    for (final occ in deduplicated) {
      slots
          .putIfAbsent(occ.scheduledAt, () => [])
          .add(occ.medicationScheduleId);
    }
    var times = slots.keys.toList()..sort();

    final isIos =
        (targetPlatform ?? defaultTargetPlatform) == TargetPlatform.iOS;
    if (isIos && times.length > maxIosScheduledNotifications) {
      times = times.take(maxIosScheduledNotifications).toList();
    }

    _slots.clear();
    for (final at in times) {
      final ids = slots[at]!..sort();
      _slots[at] = List.unmodifiable(ids);
      await _schedule(ids.first, at, fireAt: at);
    }
  }

  /// Thuốc theo từng mốc giờ đã lên lịch; phần tử đầu là thuốc đại diện của thông báo.
  final Map<DateTime, List<int>> _slots = {};

  Future<void> _schedule(
    int medicationScheduleId,
    DateTime scheduledAt, {
    required DateTime fireAt,
  }) async {
    final id = notificationIdFor(medicationScheduleId, scheduledAt);
    final payload = NotificationPayload(
      medicationScheduleId: medicationScheduleId,
      scheduledAt: scheduledAt,
    ).serialize();
    final scheduledDate = tz.TZDateTime.from(fireAt, location);

    Future<void> schedule(AndroidScheduleMode mode) => platform.zonedSchedule(
          id,
          defaultTitle,
          defaultBody,
          scheduledDate,
          _notificationDetails,
          androidScheduleMode: mode,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: payload,
        );

    try {
      await schedule(AndroidScheduleMode.exactAllowWhileIdle);
    } catch (e) {
      onLog?.call(
        'Lỗi lên lịch exact alarm cho thông báo $id: $e. '
        'Fallback sang inexactAllowWhileIdle (lưu ý: không thỏa mãn NFR04 về độ trễ).',
      );
      await schedule(AndroidScheduleMode.inexactAllowWhileIdle);
    }
  }

  /// Lên lịch hoãn cữ thuốc (snooze) đến [remindAt].
  ///
  /// Triển khai interface [ReminderScheduler].
  /// Lưu ý: [scheduledAt] vẫn là mốc thời gian gốc của cữ thuốc để đảm bảo
  /// tính nhất quán cho luồng xác nhận liều và outbox.
  @override
  Future<void> snooze({
    required int medicationScheduleId,
    required DateTime scheduledAt,
    required DateTime remindAt,
  }) =>
      _schedule(
        medicationScheduleId,
        scheduledAt.toUtc(),
        fireAt: remindAt.toUtc(),
      );

  /// Hủy một lượt thông báo cụ thể (idempotent), gỡ cả thông báo đang hiện.
  ///
  /// Nếu lượt đó là đại diện của mốc giờ chưa tới mà còn thuốc khác cùng giờ,
  /// lên lịch lại thông báo cho thuốc kế tiếp để các thuốc còn lại vẫn được nhắc.
  @override
  Future<void> cancelOccurrence({
    int? scheduleId,
    int? medicationScheduleId,
    required DateTime scheduledAt,
  }) async {
    final targetId = scheduleId ?? medicationScheduleId;
    if (targetId == null) {
      throw ArgumentError(
        'Either scheduleId or medicationScheduleId must be provided',
      );
    }
    final at = scheduledAt.toUtc();
    await platform.cancel(notificationIdFor(targetId, at));

    final slot = _slots[at];
    if (slot == null || !slot.contains(targetId)) return;
    final rest = List<int>.unmodifiable(slot.where((id) => id != targetId));
    if (rest.isEmpty) {
      _slots.remove(at);
      return;
    }
    _slots[at] = rest;
    if (slot.first == targetId && at.isAfter(_clock().toUtc())) {
      await _schedule(rest.first, at, fireAt: at);
    }
  }

  /// Hủy toàn bộ các thông báo đang chờ thuộc về [scheduleId].
  ///
  /// Đọc danh sách pending notifications từ plugin, trích xuất payload và
  /// chỉ hủy các thông báo có đúng ID lịch tương ứng.
  @override
  Future<void> cancelAllForSchedule(int scheduleId) async {
    final shared = _slots.entries
        .where((e) => e.value.contains(scheduleId))
        .map((e) => e.key)
        .toList();
    for (final at in shared) {
      await cancelOccurrence(scheduleId: scheduleId, scheduledAt: at);
    }

    final pendingRequests = await platform.pendingNotificationRequests();

    for (final request in pendingRequests) {
      final payload = NotificationPayload.tryParse(request.payload);
      if (payload != null && payload.medicationScheduleId == scheduleId) {
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
