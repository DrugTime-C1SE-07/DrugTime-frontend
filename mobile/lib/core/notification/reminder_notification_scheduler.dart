import 'dart:ui';
import 'package:flutter/foundation.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:drugtime_mobile/core/notification/notification_id.dart';
import 'package:drugtime_mobile/core/notification/notification_service.dart';
import 'package:drugtime_mobile/core/notification/notification_preferences.dart';
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
    ReminderPreferences Function()? preferences,
  })  : _clock = clockProvider ?? DateTime.timestamp,
        _soundChannel = soundChannel ?? (() => ReminderSounds.system),
        _preferences = preferences ?? (() => const ReminderPreferences());

  static const int maxIosScheduledNotifications = 64;

  final NotificationPlatform platform;
  final tz.Location location;
  final DateTime Function() _clock;
  final TargetPlatform? targetPlatform;

  /// Âm đang chọn (S08-4a); chỉ đổi channel, mọi trường khác giữ nguyên (QD-26).
  final ReminderSound Function() _soundChannel;

  /// Tùy chọn ở màn Thông báo & Nhắc nhở, đọc lại mỗi lần lập lịch.
  final ReminderPreferences Function() _preferences;
  ReminderPreferences get preferences => _preferences();

  /// Callback xử lý khi người dùng nhấn nút hành động "Đã uống".
  final Future<void> Function(NotificationPayload payload)? onTakeDose;

  /// Callback ghi log chẩn đoán hoặc cảnh báo va chạm/fallback.
  final void Function(String message)? onLog;

  static const String actionTakeDose = 'take_dose';
  static const String actionTakeDoseTitle = 'Đã uống';
  static const String defaultTitle = 'Nhắc uống thuốc';
  static const String defaultBody = 'Đã đến giờ uống thuốc theo lịch';
  static const String repeatBody = 'Bạn chưa xác nhận liều thuốc theo lịch';

  NotificationDetails get _notificationDetails {
    final sound = _soundChannel();
    final vibrate = _preferences().vibrate;
    // Channel Android không đổi được rung sau khi tạo: tắt rung dùng channel riêng.
    return NotificationDetails(
      android: AndroidNotificationDetails(
        vibrate ? sound.channelId : '${sound.channelId}_no_vibration',
        vibrate ? sound.channelName : '${sound.channelName} · không rung',
        channelDescription: NotificationService.reminderChannelDescription,
        importance: Importance.max,
        priority: Priority.high,
        fullScreenIntent: true,
        category: AndroidNotificationCategory.alarm,
        color: const Color(0xFF004D40),
        playSound: sound.playsSound,
        sound: sound.androidSound,
        enableVibration: vibrate,
      ),
    );
  }

  /// Lập một thông báo; thiếu quyền exact alarm thì fallback inexact và ghi log
  /// (lưu ý: không đạt NFR04 về độ trễ).
  Future<void> _schedule(
      int id, String body, DateTime at, String payload, String label) async {
    final date = tz.TZDateTime.from(at, location);
    try {
      await platform.zonedSchedule(
        id,
        defaultTitle,
        body,
        date,
        _notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    } catch (e) {
      onLog?.call(
        'Lỗi lên lịch exact alarm cho $label $id: $e. '
        'Fallback sang inexactAllowWhileIdle (lưu ý: không thỏa mãn NFR04 về độ trễ).',
      );
      await platform.zonedSchedule(
        id,
        defaultTitle,
        body,
        date,
        _notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    }
  }

  /// Lên lịch các lượt nhắc uống thuốc từ danh sách [occurrences].
  ///
  /// Quy trình:
  /// 1. Lọc bỏ các lượt quá khứ hoặc trùng thời điểm hiện tại (`scheduledAt <= now`).
  /// 2. Khử trùng lặp ID thông báo bằng [detectIdCollisions].
  /// 3. Lên lịch từng lượt với chế độ ưu tiên [AndroidScheduleMode.exactAllowWhileIdle].
  /// 4. Nếu thiếu quyền exact alarm (ném ngoại lệ), tự động fallback sang
  ///    [AndroidScheduleMode.inexactAllowWhileIdle] và ghi log (lưu ý: không đạt NFR04).
  ///
  /// Tùy chọn nhắc: tắt nhắc thì không lập gì; bật "nhắc lại nếu bỏ lỡ" thì mỗi lượt có thêm
  /// một thông báo sau [ReminderPreferences.repeatDelay], cùng payload với lượt gốc.
  Future<void> scheduleOccurrences(
    Iterable<ReminderOccurrence> occurrences,
  ) async {
    final prefs = _preferences();
    if (!prefs.enabled) return;
    final now = _clock().toUtc();

    // Lọc bỏ lượt trong quá khứ hoặc hiện tại
    final futureOccurrences =
        occurrences.where((occ) => occ.scheduledAt.isAfter(now));

    // Khử trùng lặp va chạm ID
    var deduplicated = detectIdCollisions(
      futureOccurrences,
      onCollision: onLog,
    );

    final isIos =
        (targetPlatform ?? defaultTargetPlatform) == TargetPlatform.iOS;
    // Nhắc lại chiếm thêm một chỗ mỗi lượt trong giới hạn 64 thông báo chờ của iOS.
    final iosLimit = prefs.repeatIfMissed
        ? maxIosScheduledNotifications ~/ 2
        : maxIosScheduledNotifications;
    if (isIos && deduplicated.length > iosLimit) {
      final sorted = List<ReminderOccurrence>.from(deduplicated)..sort();
      deduplicated = sorted.take(iosLimit).toList(growable: false);
    }

    for (final occ in deduplicated) {
      final id = notificationIdFor(occ.medicationScheduleId, occ.scheduledAt);
      final payload = NotificationPayload(
        medicationScheduleId: occ.medicationScheduleId,
        scheduledAt: occ.scheduledAt,
      ).serialize();

      await _schedule(id, defaultBody, occ.scheduledAt, payload, 'thông báo');
      if (prefs.repeatIfMissed) {
        await _schedule(
          repeatNotificationIdFor(occ.medicationScheduleId, occ.scheduledAt),
          repeatBody,
          occ.scheduledAt.add(ReminderPreferences.repeatDelay),
          payload,
          'nhắc lại',
        );
      }
    }
  }

  /// Lên lịch hoãn cữ thuốc (snooze) đến [remindAt].
  ///
  /// Triển khai interface [ReminderScheduler].
  /// Lưu ý: [scheduledAt] vẫn là mốc thời gian gốc của cữ thuốc để đảm bảo
  /// tính nhất quán cho luồng xác nhận liều và outbox. Người dùng đã chọn giờ nhắc
  /// nên lượt "nhắc lại nếu bỏ lỡ" của liều này bị bỏ.
  @override
  Future<void> snooze({
    required int medicationScheduleId,
    required DateTime scheduledAt,
    required DateTime remindAt,
  }) async {
    final utcScheduledAt = scheduledAt.toUtc();
    final id = notificationIdFor(medicationScheduleId, utcScheduledAt);
    final payload = NotificationPayload(
      medicationScheduleId: medicationScheduleId,
      scheduledAt: utcScheduledAt,
    ).serialize();

    await platform
        .cancel(repeatNotificationIdFor(medicationScheduleId, utcScheduledAt));
    await _schedule(id, defaultBody, remindAt.toUtc(), payload, 'snooze');
  }

  /// Hủy một lượt thông báo cụ thể, kể cả lượt nhắc lại của nó (idempotent).
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
    final id = notificationIdFor(targetId, scheduledAt.toUtc());
    await platform.cancel(id);
    await platform
        .cancel(repeatNotificationIdFor(targetId, scheduledAt.toUtc()));
  }

  /// Hủy toàn bộ các thông báo đang chờ thuộc về [scheduleId].
  ///
  /// Đọc danh sách pending notifications từ plugin, trích xuất payload và
  /// chỉ hủy các thông báo có đúng ID lịch tương ứng.
  @override
  Future<void> cancelAllForSchedule(int scheduleId) async {
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
