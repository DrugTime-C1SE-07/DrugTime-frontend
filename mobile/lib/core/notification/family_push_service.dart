import 'dart:async';
import 'dart:ui' show DartPluginRegistrant;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../features/family/domain/entities/family_alert.dart';
import '../sync/background_sync.dart';

/// Push ẩn "gõ cửa" của task 3.19: data message, không có khối notification. Push cảnh báo
/// người thân không có trường `type`.
const syncRequestPushType = 'sync_request';

bool isSyncRequest(Map<String, dynamic> data) =>
    data['type'] == syncRequestPushType;

/// Android đọc cấu hình native từ google-services.json, không import file Dart cá nhân.
/// Thiếu cấu hình chỉ tắt push; các lỗi khởi tạo khác vẫn được báo ra.
Future<bool> initializeFamilyFirebase() async {
  try {
    await Firebase.initializeApp();
    return true;
  } on PlatformException catch (error) {
    final missingOptions = error.message
            ?.contains('Failed to load FirebaseOptions from resource.') ??
        false;
    if (!missingOptions) rethrow;
    debugPrint('Chưa có cấu hình Firebase Android; tắt thông báo push.');
    return false;
  }
}

// Cô lập SDK messaging để coordinator quản lý token độc lập với Firebase.
abstract class FamilyMessaging {
  Stream<String> get tokenRefresh;
  Future<String?> getToken();
  Future<void> deleteToken();
  Future<void> setAutoInit(bool enabled);
}

class AndroidFamilyMessaging implements FamilyMessaging {
  // The approved backend uses FCM registration tokens, not the SDK 17 FID protocol.
  // Keep the still-supported token API until that protocol is migrated separately.
  @override
  // ignore: deprecated_member_use
  Stream<String> get tokenRefresh => FirebaseMessaging.instance.onTokenRefresh;
  @override
  Future<String?> getToken() async {
    await FirebaseMessaging.instance.requestPermission();
    // ignore: deprecated_member_use
    return FirebaseMessaging.instance.getToken();
  }

  @override
  // ignore: deprecated_member_use
  Future<void> deleteToken() => FirebaseMessaging.instance.deleteToken();
  @override
  Future<void> setAutoInit(bool enabled) =>
      FirebaseMessaging.instance.setAutoInitEnabled(enabled);
}

@pragma('vm:entry-point')
Future<void> familyPushBackgroundHandler(RemoteMessage message) async {
  if (isSyncRequest(message.data)) {
    // Isolate nền cần plugin (secure storage, SQLCipher) trước khi gửi hàng chờ và checkpoint.
    DartPluginRegistrant.ensureInitialized();
    await runBackgroundSync();
    return;
  }
  // The OS displays the remote notification. Do not fetch/store patient data in an isolate.
  familyNotificationId(message.data['notification_id']);
}

class FamilyPushService extends ChangeNotifier {
  FamilyPushService({
    required this.android,
    required this.showForeground,
    this.onSyncRequest,
  });
  final bool android;
  final Future<void> Function(int, String) showForeground;

  /// Gọi khi nhận `sync_request` lúc app đang mở: đồng bộ hàng chờ liều rồi gửi checkpoint.
  final Future<Object?> Function()? onSyncRequest;
  final List<StreamSubscription<RemoteMessage>> _subscriptions = [];
  // Push chỉ giữ ID trong RAM; chi tiết luôn lấy qua API sau kiểm quyền.
  int? pendingId;
  bool invalid = false;
  bool _accepting = true;
  bool _disposed = false;
  bool get hasPending => pendingId != null || invalid;

  Future<void> start() async {
    if (!android) return;
    _subscriptions.add(FirebaseMessaging.onMessage.listen((m) => unawaited(
        receive(m.data, foreground: true, body: m.notification?.body))));
    _subscriptions.add(FirebaseMessaging.onMessageOpenedApp
        .listen((m) => offer(m.data['notification_id'])));
    // Thu tap lúc app bị đóng; app shell đợi phiên/consent trước khi mở chi tiết.
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (!_disposed && initial != null) offer(initial.data['notification_id']);
  }

  Future<void> receive(Map<String, dynamic> data,
      {bool foreground = false, String? body}) async {
    if (!android || !_accepting) return;
    // Không phải cảnh báo người thân: không mở hộp thư, không hiện thông báo.
    if (isSyncRequest(data)) {
      await onSyncRequest?.call();
      return;
    }
    final id = familyNotificationId(data['notification_id']);
    if (id == null) {
      offer(null);
      return;
    }
    if (foreground) {
      await showForeground(id, body ?? 'Bạn có cảnh báo mới về người thân');
    }
  }

  void offer(Object? value) {
    if (!_accepting || _disposed) return;
    pendingId = familyNotificationId(value);
    invalid = pendingId == null;
    notifyListeners();
  }

  void consume() {
    pendingId = null;
    invalid = false;
  }

  // Đóng nhận tap cũ khi hết phiên; phiên mới phải gọi allow để nhận lại.
  void clear({bool accept = false}) {
    consume();
    _accepting = accept;
  }

  void allow() {
    _accepting = true;
  }

  @override
  void dispose() {
    _disposed = true;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }
}
