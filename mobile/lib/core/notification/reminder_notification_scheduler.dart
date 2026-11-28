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
        _preferences =
            preferences ?? (() => const ReminderPreferences(repeatIfMissed: false));

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
        sound.channelIdFor(vibrate: vibrate),
        sound.channelNameFor(vibrate: vibrate),
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
  Future<void> _zonedSchedule(
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
  /// 3. Gộp các thuốc cùng giờ thành một thông báo (thuốc có ID nhỏ nhất làm đại diện):
  ///    màn nhắc tự gom mọi thuốc cùng giờ, nên nhiều thông báo giống hệt chỉ là trùng.
  /// 4. Lên lịch từng mốc với chế độ ưu tiên [AndroidScheduleMode.exactAllowWhileIdle].
  /// 5. Nếu thiếu quyền exact alarm (ném ngoại lệ), tự động fallback sang
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
    const repeatDelay = ReminderPreferences.repeatDelay;

    // Lọc giữ các lượt có mốc gốc hoặc lượt nhắc lại +10 phút còn ở tương lai.
    final activeOccurrences = occurrences.where((occ) =>
        occ.scheduledAt.isAfter(now) ||
        (prefs.repeatIfMissed && occ.scheduledAt.add(repeatDelay).isAfter(now)));

    // Khử trùng lặp va chạm ID
    final deduplicated = detectIdCollisions(
      activeOccurrences,
      onCollision: onLog,
    );

    final slots = <DateTime, List<int>>{};
    for (final occ in deduplicated) {
      slots
          .putIfAbsent(occ.scheduledAt, () => [])
          .add(occ.medicationScheduleId);
    }

    final events = <({
      DateTime fireAt,
      DateTime scheduledAt,
      bool isRepeat,
      int representativeId,
    })>[];
    final sortedTimes = slots.keys.toList()..sort();
    for (final at in sortedTimes) {
      final ids = slots[at]!..sort();
      slots[at] = List.unmodifiable(ids);
      if (at.isAfter(now)) {
        events.add((
          fireAt: at,
          scheduledAt: at,
          isRepeat: false,
          representativeId: ids.first,
        ));
      }
      final repeatAt = at.add(repeatDelay);
      if (prefs.repeatIfMissed && repeatAt.isAfter(now)) {
        events.add((
          fireAt: repeatAt,
          scheduledAt: at,
          isRepeat: true,
          representativeId: ids.first,
        ));
      }
    }

    events.sort((a, b) {
      final cmp = a.fireAt.compareTo(b.fireAt);
      if (cmp != 0) return cmp;
      if (a.isRepeat != b.isRepeat) return a.isRepeat ? 1 : -1;
      return a.scheduledAt.compareTo(b.scheduledAt);
    });

    final isIos =
        (targetPlatform ?? defaultTargetPlatform) == TargetPlatform.iOS;
    final cappedEvents = isIos && events.length > maxIosScheduledNotifications
        ? events.take(maxIosScheduledNotifications).toList()
        : events;

    _slots.clear();
    for (final e in cappedEvents) {
      _slots.putIfAbsent(e.scheduledAt, () => slots[e.scheduledAt]!);
      await _scheduleOne(
        e.representativeId,
        e.scheduledAt,
        fireAt: e.fireAt,
        isRepeat: e.isRepeat,
      );
    }
  }

  /// Thuốc theo từng mốc giờ đã lên lịch; phần tử đầu là thuốc đại diện của thông báo.
  final Map<DateTime, List<int>> _slots = {};

  /// Lập một thông báo (gốc hoặc nhắc lại +10 phút) cho thuốc đại diện.
  Future<void> _scheduleOne(
    int medicationScheduleId,
    DateTime scheduledAt, {
    required DateTime fireAt,
    required bool isRepeat,
  }) async {
    final payload = NotificationPayload(
      medicationScheduleId: medicationScheduleId,
      scheduledAt: scheduledAt,
      isRepeat: isRepeat,
    ).serialize();
    await _zonedSchedule(
      isRepeat
          ? repeatNotificationIdFor(medicationScheduleId, scheduledAt)
          : notificationIdFor(medicationScheduleId, scheduledAt),
      isRepeat ? repeatBody : defaultBody,
      fireAt,
      payload,
      isRepeat ? 'nhắc lại' : 'thông báo',
    );
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
    final at = scheduledAt.toUtc();
    await platform.cancel(repeatNotificationIdFor(medicationScheduleId, at));
    await _scheduleOne(
      medicationScheduleId,
      at,
      fireAt: remindAt.toUtc(),
      isRepeat: false,
    );
  }

  /// Hủy một lượt thông báo cụ thể, kể cả lượt nhắc lại của nó (idempotent).
  ///
  /// Nếu lượt đó là đại diện của mốc giờ chưa tới (hoặc còn lượt nhắc lại +10 phút
  /// chưa tới) mà vẫn còn thuốc khác cùng giờ, lên lịch lại cho thuốc kế tiếp.
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
    await platform.cancel(repeatNotificationIdFor(targetId, at));

    final slot = _slots[at];
    if (slot == null || !slot.contains(targetId)) return;
    final rest = List<int>.unmodifiable(slot.where((id) => id != targetId));
    if (rest.isEmpty) {
      _slots.remove(at);
      return;
    }
    _slots[at] = rest;
    if (slot.first == targetId) {
      final now = _clock().toUtc();
      final prefs = _preferences();
      if (at.isAfter(now)) {
        await _scheduleOne(rest.first, at, fireAt: at, isRepeat: false);
      }
      final repeatAt = at.add(ReminderPreferences.repeatDelay);
      if (prefs.repeatIfMissed && repeatAt.isAfter(now)) {
        await _scheduleOne(rest.first, at, fireAt: repeatAt, isRepeat: true);
      }
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
        await platform.cancel(
          notificationIdFor(payload.medicationScheduleId, payload.scheduledAt),
        );
        await platform.cancel(
          repeatNotificationIdFor(
              payload.medicationScheduleId, payload.scheduledAt),
        );
        if (response.id != null) {
          await platform.cancel(response.id!);
        }
      }
    }
  }
}
