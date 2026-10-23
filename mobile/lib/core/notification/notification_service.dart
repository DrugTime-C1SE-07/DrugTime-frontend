import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:drugtime_mobile/core/notification/notification_id.dart';
import '../../features/family/domain/entities/family_alert.dart';

abstract class FamilyNotificationPlatform {
  Future<void> showFamily(int id, String body);
  Future<void> clearFamily();
}

/// Abstraction bọc plugin thông báo để dễ dàng test unit độc lập không cần thiết bị.
abstract class NotificationPlatform {
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
  });

  Future<void> createNotificationChannel(AndroidNotificationChannel channel);

  Future<void> zonedSchedule(
    int id,
    String? title,
    String? body,
    tz.TZDateTime scheduledDate,
    NotificationDetails notificationDetails, {
    required AndroidScheduleMode androidScheduleMode,
    required UILocalNotificationDateInterpretation
        uiLocalNotificationDateInterpretation,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
  });

  Future<void> cancel(int id, {String? tag});

  Future<List<PendingNotificationRequest>> pendingNotificationRequests();

  Future<NotificationAppLaunchDetails?>
      getNotificationAppLaunchDetails() async => null;

  Future<bool?> requestFullScreenIntentPermission() async => true;
}

/// Cài đặt mặc định của [NotificationPlatform] sử dụng [FlutterLocalNotificationsPlugin].
class DefaultNotificationPlatform
    implements NotificationPlatform, FamilyNotificationPlatform {
  DefaultNotificationPlatform([FlutterLocalNotificationsPlugin? plugin])
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  @override
  // Tag riêng cho từng cảnh báo; khớp remote để dọn được cả hai nguồn thông báo.
  Future<void> showFamily(int id, String body) => _plugin.show(
      0,
      'DrugTime',
      body,
      NotificationDetails(
          android: AndroidNotificationDetails(
              'family_alerts', 'Cảnh báo người thân',
              tag: 'family_alert_$id',
              visibility: NotificationVisibility.private,
              fullScreenIntent: false)),
      payload: 'family:$id');

  @override
  Future<void> clearFamily() async {
    // Chỉ hủy tag người thân để giữ các thông báo nhắc uống thuốc đã lên lịch.
    final active = await _plugin.getActiveNotifications();
    for (final notification in active) {
      if (notification.tag?.startsWith('family_alert_') == true &&
          notification.id != null) {
        await _plugin.cancel(notification.id!, tag: notification.tag);
      }
    }
  }

  @override
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
  }) async {
    final result = await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
    );
    await createNotificationChannel(const AndroidNotificationChannel(
        'family_alerts', 'Cảnh báo người thân',
        importance: Importance.defaultImportance));
    return result;
  }

  @override
  Future<void> createNotificationChannel(
    AndroidNotificationChannel channel,
  ) async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  @override
  Future<void> zonedSchedule(
    int id,
    String? title,
    String? body,
    tz.TZDateTime scheduledDate,
    NotificationDetails notificationDetails, {
    required AndroidScheduleMode androidScheduleMode,
    required UILocalNotificationDateInterpretation
        uiLocalNotificationDateInterpretation,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
  }) {
    return _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      notificationDetails,
      androidScheduleMode: androidScheduleMode,
      uiLocalNotificationDateInterpretation:
          uiLocalNotificationDateInterpretation,
      payload: payload,
      matchDateTimeComponents: matchDateTimeComponents,
    );
  }

  @override
  Future<void> cancel(int id, {String? tag}) {
    return _plugin.cancel(id, tag: tag);
  }

  @override
  Future<List<PendingNotificationRequest>> pendingNotificationRequests() {
    return _plugin.pendingNotificationRequests();
  }

  @override
  Future<NotificationAppLaunchDetails?> getNotificationAppLaunchDetails() {
    return _plugin.getNotificationAppLaunchDetails();
  }

  @override
  Future<bool?> requestFullScreenIntentPermission() async {
    return _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestFullScreenIntentPermission();
  }
}

/// Dịch vụ quản lý thông báo nhắc uống thuốc.
///
/// Khởi tạo múi giờ cố định Asia/Ho_Chi_Minh (UTC+7) và cấu hình kênh thông báo.
class NotificationService {
  NotificationService({
    NotificationPlatform? platform,
    this.onNotificationAction,
  })  : _platform = platform ?? DefaultNotificationPlatform(),
        _actionHandler = onNotificationAction;

  final NotificationPlatform _platform;
  void Function(int?)? onFamilyAction;
  int? _pendingFamilyId;
  bool _pendingFamilyInvalid = false;
  bool consumeInvalidFamilyPayload() {
    final invalid = _pendingFamilyInvalid;
    _pendingFamilyInvalid = false;
    return invalid;
  }

  int? consumeFamilyId() {
    final id = _pendingFamilyId;
    _pendingFamilyId = null;
    return id;
  }

  Future<void> showFamily(int id, String body) async {
    final platform = _platform;
    if (platform is FamilyNotificationPlatform) {
      await (platform as FamilyNotificationPlatform).showFamily(id, body);
    }
  }

  Future<void> clearFamily() async {
    _pendingFamilyId = null;
    _pendingFamilyInvalid = false;
    final platform = _platform;
    if (platform is FamilyNotificationPlatform) {
      await (platform as FamilyNotificationPlatform).clearFamily();
    }
  }

  // Prefix phân luồng payload; cold start chỉ giữ ID chờ app gắn callback điều hướng.
  bool _handleFamily(String? raw) {
    if (raw == null || !raw.startsWith('family:')) return false;
    final id = familyNotificationId(raw.substring(7));
    if (onFamilyAction != null) {
      onFamilyAction!(id);
    } else {
      _pendingFamilyId = id;
      _pendingFamilyInvalid = id == null;
    }
    return true;
  }

  /// Callback chuyển tiếp payload khi người dùng bấm vào thông báo nhắc uống thuốc.
  final void Function(NotificationPayload payload)? onNotificationAction;
  void Function(NotificationPayload payload)? _actionHandler;

  NotificationPayload? _pendingPayload;
  NotificationPayload? get pendingPayload => _pendingPayload;

  /// Đăng ký handler nhận hành động tương tác thông báo.
  /// Nếu có [pendingPayload] đang chờ từ cold start, lập tức gọi handler và xóa đệm.
  void setNotificationActionHandler(
    void Function(NotificationPayload payload)? handler,
  ) {
    _actionHandler = handler;
    if (handler != null && _pendingPayload != null) {
      final payload = _pendingPayload!;
      _pendingPayload = null;
      handler(payload);
    }
  }

  /// Tiêu thụ (consume) và xóa payload đang chờ.
  NotificationPayload? consumePendingPayload() {
    final payload = _pendingPayload;
    _pendingPayload = null;
    return payload;
  }

  /// Yêu cầu cấp quyền full-screen intent trên Android 14+ (AC8).
  Future<bool?> requestFullScreenIntentPermission() async {
    return _platform.requestFullScreenIntentPermission();
  }

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  tz.Location? _location;

  /// Vị trí múi giờ đã được khởi tạo (luôn là Asia/Ho_Chi_Minh = UTC+7).
  tz.Location get location {
    final loc = _location;
    if (loc == null) {
      throw StateError('NotificationService has not been initialized');
    }
    return loc;
  }

  static const String reminderChannelId = 'drugtime_reminder_channel';
  static const String reminderChannelName = 'Nhắc uống thuốc';
  static const String reminderChannelDescription =
      'Thông báo nhắc uống thuốc đúng giờ';

  /// Khởi tạo dịch vụ thông báo (idempotent: gọi nhiều lần không sinh lỗi).
  Future<void> init() async {
    if (_isInitialized) return;

    // Cố định múi giờ Asia/Ho_Chi_Minh theo CD7, không dùng múi giờ thiết bị.
    tz_data.initializeTimeZones();
    _location = tz.getLocation('Asia/Ho_Chi_Minh');

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _platform.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );

    const androidChannel = AndroidNotificationChannel(
      reminderChannelId,
      reminderChannelName,
      description: reminderChannelDescription,
      importance: Importance.max,
    );
    await _platform.createNotificationChannel(androidChannel);

    // Kiểm tra và đệm payload khi khởi động lạnh từ thông báo (cold start)
    final launchDetails = await _platform.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      final raw = launchDetails?.notificationResponse?.payload;
      _handleFamily(raw);
      final payload = NotificationPayload.tryParse(raw);
      if (payload != null) {
        if (_actionHandler != null) {
          _actionHandler!(payload);
        } else if (onNotificationAction != null) {
          onNotificationAction!(payload);
        } else {
          _pendingPayload = payload;
        }
      }
    }

    _isInitialized = true;
  }

  void _handleNotificationResponse(NotificationResponse response) {
    final rawPayload = response.payload;
    if (rawPayload == null) return;
    if (_handleFamily(rawPayload)) return;

    final payload = NotificationPayload.tryParse(rawPayload);
    if (payload != null) {
      if (_actionHandler != null) {
        _actionHandler!(payload);
      } else if (onNotificationAction != null) {
        onNotificationAction!(payload);
      } else {
        _pendingPayload = payload;
      }
    }
  }
}
