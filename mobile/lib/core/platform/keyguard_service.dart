import 'package:flutter/services.dart';

/// Giao diện trừu tượng giao tiếp với hệ thống quản lý khóa màn hình (Keyguard).
abstract class KeyguardPlatform {
  /// Kiểm tra xem thiết bị hiện tại có đang bị khóa màn hình (keyguard locked) hay không.
  Future<bool> isKeyguardLocked();

  /// Yêu cầu hệ điều hành hiển thị màn hình mở khóa (PIN/vân tay/hình vẽ).
  ///
  /// Trả về `true` nếu người dùng mở khóa thành công, `false` nếu hủy hoặc lỗi.
  Future<bool> requestDismissKeyguard();
}

/// Tín hiệu native cho "Khóa ứng dụng" (Android), dùng chung channel keyguard.
abstract class AppLeavePlatform {
  /// `true` nếu từ lần resume trước người dùng đã tự rời app (Home, Recents)
  /// hoặc tắt màn hình; đọc xong thì native reset cờ.
  Future<bool> consumeUserLeftApp();

  /// Ẩn ảnh chụp app trong màn đa nhiệm (Android 13+).
  Future<void> setRecentsPrivacy(bool enabled);
}

class DefaultAppLeavePlatform implements AppLeavePlatform {
  const DefaultAppLeavePlatform([MethodChannel? channel])
      : _channel = channel ??
            const MethodChannel('vn.drugtime.drugtime_mobile/keyguard');

  final MethodChannel _channel;

  @override
  Future<bool> consumeUserLeftApp() async {
    try {
      return await _channel.invokeMethod<bool>('consumeUserLeftApp') ?? true;
    } catch (_) {
      // Fail-closed: không biết thì khóa, tránh lộ dữ liệu sức khỏe.
      return true;
    }
  }

  @override
  Future<void> setRecentsPrivacy(bool enabled) async {
    try {
      await _channel.invokeMethod<void>('setRecentsPrivacy', enabled);
    } catch (_) {
      // Máy cũ/không hỗ trợ: vẫn còn lớp che phía Flutter.
    }
  }
}

/// Triển khai mặc định của [KeyguardPlatform] qua [MethodChannel].
class DefaultKeyguardPlatform implements KeyguardPlatform {
  const DefaultKeyguardPlatform([MethodChannel? channel])
      : _channel = channel ??
            const MethodChannel('vn.drugtime.drugtime_mobile/keyguard');

  final MethodChannel _channel;

  @override
  Future<bool> isKeyguardLocked() async {
    try {
      final isLocked = await _channel.invokeMethod<bool>('isKeyguardLocked');
      return isLocked ?? false;
    } catch (_) {
      // Mặc định an toàn: nếu nền tảng không hỗ trợ hoặc lỗi, coi như không khóa.
      return false;
    }
  }

  @override
  Future<bool> requestDismissKeyguard() async {
    try {
      final dismissed =
          await _channel.invokeMethod<bool>('requestDismissKeyguard');
      return dismissed ?? false;
    } catch (_) {
      return false;
    }
  }
}
