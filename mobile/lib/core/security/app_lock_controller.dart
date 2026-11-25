import 'dart:io' show Platform;

import 'package:flutter/widgets.dart';

import '../platform/keyguard_service.dart';
import 'app_lock_settings_store.dart';
import 'device_authenticator.dart';

/// Trạng thái "Khóa ứng dụng": khi bật, mỗi lần người dùng rời app (tắt app,
/// chuyển app, khóa màn hình) thì phải xác thực lại mới thấy nội dung.
class AppLockController extends ChangeNotifier {
  AppLockController({
    required AppLockSettingsStore store,
    required DeviceAuthenticator authenticator,
    AppLeavePlatform leavePlatform = const DefaultAppLeavePlatform(),
    bool? useLeaveHint,
  })  : _store = store,
        _authenticator = authenticator,
        _leave = leavePlatform,
        // Android: activity ngoài do app mở (chọn ảnh, xin quyền) cũng gây
        // `paused`, nên hỏi native xem người dùng có tự rời app không.
        // iOS chỉ `paused` khi app thật sự vào nền.
        _useLeaveHint = useLeaveHint ?? Platform.isAndroid;

  final AppLockSettingsStore _store;
  final DeviceAuthenticator _authenticator;
  final AppLeavePlatform _leave;
  final bool _useLeaveHint;

  bool _loaded = false;
  bool _enabled = false;
  bool _locked = false;
  bool _obscured = false;
  bool _signedIn = false;
  bool _pausedSinceResume = false;
  Future<bool>? _authenticating;

  bool get loaded => _loaded;
  bool get enabled => _enabled;
  bool get locked => _locked;

  /// Che nội dung: khi app rời foreground, hoặc chưa đọc xong cài đặt (fail-closed).
  bool get obscured => !_loaded || _obscured;

  Future<void> load({required bool signedIn}) async {
    _signedIn = signedIn;
    try {
      _enabled = await _store.readEnabled();
    } on Exception catch (e) {
      // Keychain/Keystore hỏng thì phiên cũng không đọc được; không chặn app.
      debugPrint('Không đọc được cài đặt khóa ứng dụng: $e');
      _enabled = false;
    }
    _locked = _enabled && signedIn;
    _loaded = true;
    notifyListeners();
    await _leave.setRecentsPrivacy(_enabled);
  }

  Future<bool> isDeviceSupported() => _authenticator.isDeviceSupported();

  /// Bật khóa; chỉ lưu khi người dùng xác thực thành công.
  Future<bool> enable() async {
    if (_enabled) return true;
    if (!await _authenticate()) return false;
    await _store.writeEnabled(true);
    _enabled = true;
    notifyListeners();
    await _leave.setRecentsPrivacy(true);
    return true;
  }

  Future<void> disable() async {
    await _store.clear();
    await _reset();
  }

  Future<bool> unlock() async {
    if (!_locked) return true;
    final ok = await _authenticate();
    if (ok) {
      _locked = false;
      _obscured = false;
      notifyListeners();
    }
    return ok;
  }

  /// Gọi khi trạng thái đăng nhập đổi; đăng xuất hoặc 401 thì tắt khóa (AC7).
  Future<void> onAuthChanged({required bool signedIn}) async {
    final signedOut = _signedIn && !signedIn;
    _signedIn = signedIn;
    if (!signedOut) return;
    await _store.clear();
    await _reset();
  }

  Future<void> onLifecycle(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        _obscure();
      case AppLifecycleState.paused:
        _pausedSinceResume = true;
        _obscure();
      case AppLifecycleState.resumed:
        await _onResumed();
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _onResumed() async {
    final paused = _pausedSinceResume;
    _pausedSinceResume = false;
    // Luôn đọc cờ native sau khi paused để cờ cũ không làm khóa nhầm sau này.
    final userLeft =
        paused && (!_useLeaveHint || await _leave.consumeUserLeftApp());
    if (!_enabled || !_signedIn) return;
    if (userLeft && _authenticating == null) _locked = true;
    if (!_locked) _obscured = false;
    notifyListeners();
  }

  void _obscure() {
    if (!_enabled || _obscured) return;
    _obscured = true;
    notifyListeners();
  }

  /// Một prompt tại một thời điểm; prompt gây inactive/resumed không làm khóa lại.
  Future<bool> _authenticate() =>
      _authenticating ??= _authenticator.authenticate().whenComplete(() {
        _authenticating = null;
      });

  Future<void> _reset() async {
    final changed = _enabled || _locked || _obscured;
    _enabled = false;
    _locked = false;
    _obscured = false;
    if (changed) notifyListeners();
    await _leave.setRecentsPrivacy(false);
  }
}
