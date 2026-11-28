import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:drugtime_mobile/core/api/api_client.dart';

/// Tùy chọn nhắc uống thuốc lưu trên máy (màn Thông báo & Nhắc nhở).
@immutable
class ReminderPreferences {
  const ReminderPreferences({
    this.enabled = true,
    this.vibrate = true,
    this.repeatIfMissed = true,
    this.lowStockAlerts = true,
  });

  /// Tắt thì không lập nhắc cục bộ nào; lịch uống trên server giữ nguyên.
  final bool enabled;
  final bool vibrate;

  /// Nhắc thêm một lần sau [repeatDelay] nếu liều chưa được xác nhận (QD-20).
  final bool repeatIfMissed;

  /// Hiện cảnh báo sắp hết thuốc ở danh sách & chi tiết thuốc.
  final bool lowStockAlerts;

  static const repeatDelay = Duration(minutes: 10);

  ReminderPreferences copyWith({
    bool? enabled,
    bool? vibrate,
    bool? repeatIfMissed,
    bool? lowStockAlerts,
  }) =>
      ReminderPreferences(
        enabled: enabled ?? this.enabled,
        vibrate: vibrate ?? this.vibrate,
        repeatIfMissed: repeatIfMissed ?? this.repeatIfMissed,
        lowStockAlerts: lowStockAlerts ?? this.lowStockAlerts,
      );

  Map<String, Object> toJson() => {
        'enabled': enabled,
        'vibrate': vibrate,
        'repeat': repeatIfMissed,
        'low_stock': lowStockAlerts,
      };

  static ReminderPreferences fromJson(Map<String, dynamic> json) =>
      ReminderPreferences(
        enabled: json['enabled'] as bool? ?? true,
        vibrate: json['vibrate'] as bool? ?? true,
        repeatIfMissed: json['repeat'] as bool? ?? true,
        lowStockAlerts: json['low_stock'] as bool? ?? true,
      );

  @override
  bool operator ==(Object other) =>
      other is ReminderPreferences &&
      other.enabled == enabled &&
      other.vibrate == vibrate &&
      other.repeatIfMissed == repeatIfMissed &&
      other.lowStockAlerts == lowStockAlerts;

  @override
  int get hashCode =>
      Object.hash(enabled, vibrate, repeatIfMissed, lowStockAlerts);

  @override
  String toString() => 'ReminderPreferences${toJson()}';
}

abstract class ReminderPreferencesStore {
  Future<ReminderPreferences> read();
  Future<void> write(ReminderPreferences preferences);
  Future<void> clear();
}

/// Lưu theo thiết bị, xóa khi đăng xuất như âm nhắc.
class SecureReminderPreferencesStore implements ReminderPreferencesStore {
  SecureReminderPreferencesStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const key = 'reminder_preferences_v1';
  final FlutterSecureStorage _storage;

  @override
  Future<ReminderPreferences> read() async {
    final raw = await _storage.read(key: key);
    if (raw == null) return const ReminderPreferences();
    try {
      return ReminderPreferences.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } on Object {
      // Dữ liệu hỏng: về mặc định (nhắc bật) thay vì để mất nhắc thuốc.
      await _storage.delete(key: key);
      return const ReminderPreferences();
    }
  }

  @override
  Future<void> write(ReminderPreferences preferences) =>
      _storage.write(key: key, value: jsonEncode(preferences.toJson()));

  @override
  Future<void> clear() => _storage.delete(key: key);
}

/// Tùy chọn "Báo người giám sát khi bỏ lỡ liều" nằm ở server vì Worker đọc nó.
abstract class FamilyAlertPreferenceRepository {
  Future<bool> read();
  Future<void> write(bool enabled);
}

class RemoteFamilyAlertPreferenceRepository
    implements FamilyAlertPreferenceRepository {
  RemoteFamilyAlertPreferenceRepository(this._api);

  static const path = '/me/notification-preferences';
  static const field = 'missed_dose_family_alerts';
  final ApiClient _api;

  @override
  Future<bool> read() async {
    final json = await _api.getJson(path);
    if (json is Map && json[field] is bool) return json[field] as bool;
    throw const FormatException('notification preferences');
  }

  @override
  Future<void> write(bool enabled) =>
      _api.putJson(path, body: {field: enabled});
}

class NotificationPreferencesController extends ChangeNotifier {
  NotificationPreferencesController({
    required ReminderPreferencesStore store,
    FamilyAlertPreferenceRepository? familyAlerts,
  })  : _store = store,
        _familyAlerts = familyAlerts;

  final ReminderPreferencesStore _store;
  final FamilyAlertPreferenceRepository? _familyAlerts;

  /// Gọi sau khi tùy chọn nhắc đổi, để lập lại toàn bộ nhắc cục bộ.
  VoidCallback? onRemindersChanged;

  ReminderPreferences _reminders = const ReminderPreferences();
  ReminderPreferences get reminders => _reminders;

  bool? _familyAlertsEnabled;

  /// Null khi chưa tải được (đang tải, lỗi mạng hoặc bản xem trước không có server).
  bool? get familyAlertsEnabled => _familyAlertsEnabled;
  bool get supportsFamilyAlerts => _familyAlerts != null;

  Future<void> load() async {
    _reminders = await _store.read();
    notifyListeners();
  }

  /// Ném lỗi khi không đọc được từ server; giá trị cũ giữ nguyên.
  Future<void> loadFamilyAlerts() async {
    final repository = _familyAlerts;
    if (repository == null) return;
    _familyAlertsEnabled = await repository.read();
    notifyListeners();
  }

  /// Lưu trên máy trước rồi mới gửi server: lỗi mạng không làm mất thay đổi nhắc thuốc.
  Future<void> save({
    required ReminderPreferences reminders,
    bool? familyAlertsEnabled,
  }) async {
    if (reminders != _reminders) {
      await _store.write(reminders);
      _reminders = reminders;
      notifyListeners();
      onRemindersChanged?.call();
    }
    final repository = _familyAlerts;
    if (repository != null &&
        familyAlertsEnabled != null &&
        familyAlertsEnabled != _familyAlertsEnabled) {
      await repository.write(familyAlertsEnabled);
      _familyAlertsEnabled = familyAlertsEnabled;
      notifyListeners();
    }
  }

  Future<void> clear() async {
    await _store.clear();
    _reminders = const ReminderPreferences();
    _familyAlertsEnabled = null;
    notifyListeners();
  }
}

class NotificationPreferencesScope
    extends InheritedNotifier<NotificationPreferencesController> {
  const NotificationPreferencesScope({
    super.key,
    required NotificationPreferencesController controller,
    required super.child,
  }) : super(notifier: controller);

  /// Null khi app không cấp scope (ví dụ bản xem trước): màn hiện chưa khả dụng.
  static NotificationPreferencesController? maybeOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<NotificationPreferencesScope>()
          ?.notifier;
}
