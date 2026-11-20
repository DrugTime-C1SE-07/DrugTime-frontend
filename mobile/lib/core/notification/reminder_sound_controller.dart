import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:drugtime_mobile/core/notification/notification_service.dart';
import 'package:drugtime_mobile/core/notification/reminder_sound.dart';
import 'package:drugtime_mobile/core/notification/reminder_sound_native.dart';
import 'package:drugtime_mobile/core/notification/reminder_sound_store.dart';
import 'package:drugtime_mobile/core/notification/reminder_sound_validator.dart';

/// Trạng thái màn S08-4a và nguồn channel cho thông báo nhắc thuốc.
class ReminderSoundController extends ChangeNotifier {
  ReminderSoundController({
    required ReminderSoundStore store,
    required ReminderSoundNative native,
    required NotificationPlatform notifications,
    TargetPlatform? targetPlatform,
    void Function(String message)? onLog,
    Random? random,
  })  : _store = store,
        _native = native,
        _notifications = notifications,
        _targetPlatform = targetPlatform,
        _onLog = onLog ?? debugPrint,
        _random = random ?? Random.secure() {
    _native.onPreviewDone = _previewDone;
  }

  static const maxCustom = 10;

  /// MediaStore `RELATIVE_PATH` và `IS_PENDING` cần Android 10 (Q2).
  static const minCustomSdk = 29;
  static const addFailedMessage = 'Không thêm được âm thanh, vui lòng thử lại';

  final ReminderSoundStore _store;
  final ReminderSoundNative _native;
  final NotificationPlatform _notifications;
  final TargetPlatform? _targetPlatform;
  final void Function(String message) _onLog;
  final Random _random;

  /// Gọi sau khi lựa chọn đổi để lên lịch lại các lượt nhắc chưa tới giờ.
  VoidCallback? onSoundChanged;

  ReminderSoundSettings _settings = const ReminderSoundSettings();
  bool _loaded = false;
  bool _customSupported = false;
  bool _busy = false;
  String? _playingId;
  String? _error;

  bool get customSupported => _customSupported;
  bool get busy => _busy;
  String? get playingId => _playingId;
  String? get error => _error;
  bool get fallbackNotice => _settings.fallbackNotice;
  String get selectedId => selected.id;
  List<ReminderSound> get customSounds =>
      [for (final custom in _settings.customs) custom.sound];
  bool get canAdd => _customSupported && _settings.customs.length < maxCustom;

  ReminderSound get selected =>
      _resolve(_settings.selectedId) ?? ReminderSounds.fallback;

  bool get _isAndroid =>
      (_targetPlatform ?? defaultTargetPlatform) == TargetPlatform.android;

  Future<void> load() async {
    _settings = await _store.read();
    _customSupported = _isAndroid && await _sdkInt() >= minCustomSdk;
    _loaded = true;
    await ensureValid();
  }

  /// Gọi khi mở app và trước mỗi lần lập lịch: âm đã chọn không còn thì về
  /// chuông mặc định (không bao giờ về `silent`), và bảo đảm channel tồn tại.
  Future<void> ensureValid() async {
    if (!_loaded) return load();
    final id = _settings.selectedId;
    final custom = _customById(id);
    final missing = custom != null
        ? !await _exists(custom)
        : ReminderSounds.builtinById(id) == null;
    if (missing) {
      _settings = _settings.copyWith(
          selectedId: ReminderSounds.fallback.id, fallbackNotice: true);
      await _store.write(_settings);
    }
    await _createChannel(selected);
    notifyListeners();
  }

  Future<void> select(String id) async {
    final sound = _resolve(id);
    if (sound == null) return;
    await _createChannel(sound);
    _settings = _settings.copyWith(selectedId: id, fallbackNotice: false);
    await _store.write(_settings);
    notifyListeners();
    onSoundChanged?.call();
  }

  Future<void> addFromDevice() async {
    if (!canAdd || _busy) return;
    _busy = true;
    _error = null;
    notifyListeners();
    String? tempPath;
    try {
      final picked = await _native.pick();
      if (picked == null) return;
      tempPath = picked.path;
      final error = ReminderSoundValidator.checkFile(
              size: picked.size, head: picked.head) ??
          ReminderSoundValidator.checkDuration(
              await _native.probeDurationMs(picked.path));
      if (error != null) {
        _error = error.message;
        return;
      }
      final id = 'custom_${_newId()}';
      final number = _nextNumber();
      final saved = await _native.commit(
        tempPath: picked.path,
        id: id,
        ext: ReminderSoundValidator.formatOf(picked.head)!,
        number: number,
      );
      tempPath = null;
      final custom = CustomReminderSound(
          id: id, number: number, path: saved.path, uri: saved.uri);
      await _createChannel(custom.sound);
      _settings = _settings.copyWith(customs: [..._settings.customs, custom]);
      await _store.write(_settings);
    } on Exception catch (e) {
      _onLog('[ReminderSound] add failed: $e');
      _error = addFailedMessage;
    } finally {
      if (tempPath != null) await _discard(tempPath);
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> delete(String id) async {
    final custom = _customById(id);
    if (custom == null) return;
    if (_playingId == id) await stopPreview();
    final wasSelected = _settings.selectedId == id;
    _settings = _settings.copyWith(
      customs: [
        for (final c in _settings.customs)
          if (c.id != id) c,
      ],
      selectedId: wasSelected ? ReminderSounds.fallback.id : null,
    );
    await _store.write(_settings);
    if (wasSelected) await _createChannel(ReminderSounds.fallback);
    notifyListeners();
    if (wasSelected) onSoundChanged?.call();
    await _removeFiles(custom);
  }

  /// Đăng xuất: xóa mọi âm tự thêm và về mặc định (Q1).
  Future<void> clearAll() async {
    await stopPreview();
    final customs = _settings.customs;
    _settings = const ReminderSoundSettings();
    _error = null;
    await _store.clear();
    notifyListeners();
    for (final custom in customs) {
      await _removeFiles(custom);
    }
  }

  Future<void> togglePreview(ReminderSound sound) async {
    if (_playingId == sound.id || !sound.playsSound) return stopPreview();
    await stopPreview();
    _playingId = sound.id;
    notifyListeners();
    try {
      await _native.play(sound);
    } on Exception catch (e) {
      _onLog('[ReminderSound] preview failed: $e');
      _playingId = null;
      _error = ReminderSoundError.undecodable.message;
      notifyListeners();
    }
  }

  Future<void> stopPreview() async {
    if (_playingId == null) return;
    _playingId = null;
    notifyListeners();
    try {
      await _native.stop();
    } on Exception catch (e) {
      _onLog('[ReminderSound] stop failed: $e');
    }
  }

  Future<void> openSoundSettings() async {
    try {
      await _native.openSoundSettings();
    } on Exception catch (e) {
      _onLog('[ReminderSound] open settings failed: $e');
    }
  }

  Future<void> dismissFallbackNotice() async {
    if (!_settings.fallbackNotice) return;
    _settings = _settings.copyWith(fallbackNotice: false);
    await _store.write(_settings);
    notifyListeners();
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  void _previewDone() {
    if (_playingId == null) return;
    _playingId = null;
    notifyListeners();
  }

  ReminderSound? _resolve(String id) =>
      ReminderSounds.builtinById(id) ?? _customById(id)?.sound;

  CustomReminderSound? _customById(String id) {
    for (final custom in _settings.customs) {
      if (custom.id == id) return custom;
    }
    return null;
  }

  int _nextNumber() {
    final used = {for (final c in _settings.customs) c.number};
    return List.generate(maxCustom, (i) => i + 1)
        .firstWhere((n) => !used.contains(n), orElse: () => used.length + 1);
  }

  String _newId() =>
      List.generate(16, (_) => _random.nextInt(16).toRadixString(16)).join();

  Future<int> _sdkInt() async {
    try {
      return await _native.sdkInt();
    } on Exception catch (e) {
      _onLog('[ReminderSound] sdkInt failed: $e');
      return 0;
    }
  }

  // Lỗi khi kiểm tra coi như mất file: nhắc thuốc phải có âm chắc chắn phát được.
  Future<bool> _exists(CustomReminderSound custom) async {
    try {
      return await _native.exists(path: custom.path, uri: custom.uri);
    } on Exception catch (e) {
      _onLog('[ReminderSound] exists failed: $e');
      return false;
    }
  }

  Future<void> _createChannel(ReminderSound sound) async {
    if (!_isAndroid) return;
    await _notifications.createNotificationChannel(sound.channel);
  }

  Future<void> _removeFiles(CustomReminderSound custom) async {
    try {
      if (_isAndroid) {
        await _notifications.deleteNotificationChannel(custom.sound.channelId);
      }
      await _native.delete(path: custom.path, uri: custom.uri);
    } on Exception catch (e) {
      _onLog('[ReminderSound] delete ${custom.id} failed: $e');
    }
  }

  Future<void> _discard(String tempPath) async {
    try {
      await _native.discard(tempPath);
    } on Exception catch (e) {
      _onLog('[ReminderSound] discard failed: $e');
    }
  }
}

class ReminderSoundScope extends InheritedNotifier<ReminderSoundController> {
  const ReminderSoundScope({
    super.key,
    required ReminderSoundController controller,
    required super.child,
  }) : super(notifier: controller);

  static ReminderSoundController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<ReminderSoundScope>();
    assert(scope != null,
        'Không tìm thấy ReminderSoundScope phía trên widget này');
    return scope!.notifier!;
  }

  /// Null khi app không cấp scope (ví dụ bản xem trước); màn S08-4a hiện chưa khả dụng.
  static ReminderSoundController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<ReminderSoundScope>()
      ?.notifier;

  static ReminderSoundController read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<ReminderSoundScope>();
    assert(scope != null,
        'Không tìm thấy ReminderSoundScope phía trên widget này');
    return scope!.notifier!;
  }
}
