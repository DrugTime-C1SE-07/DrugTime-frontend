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
