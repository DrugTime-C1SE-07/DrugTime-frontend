import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Xác thực chủ máy bằng Face ID, vân tay hoặc mã khóa màn hình.
/// App chỉ nhận đúng/sai; dữ liệu sinh trắc do hệ điều hành giữ.
abstract interface class DeviceAuthenticator {
  /// Thiết bị đã đặt khóa màn hình (sinh trắc hoặc mã PIN/mật khẩu).
  Future<bool> isDeviceSupported();

  /// `true` khi xác thực thành công; hủy, thất bại hay lỗi đều trả `false`.
  Future<bool> authenticate();
}

class LocalDeviceAuthenticator implements DeviceAuthenticator {
  LocalDeviceAuthenticator({LocalAuthentication? auth})
      : _auth = auth ?? LocalAuthentication();

  static const reason = 'Xác thực để mở khóa DrugTime';

  final LocalAuthentication _auth;

  @override
  Future<bool> isDeviceSupported() async {
    try {
      return await _auth.isDeviceSupported();
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        // Cho phép mã khóa màn hình khi sinh trắc không dùng được (Q4).
        biometricOnly: false,
      );
    } on LocalAuthException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
