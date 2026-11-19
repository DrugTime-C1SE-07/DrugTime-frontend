import 'package:permission_handler/permission_handler.dart';

enum CameraPermissionStatus { granted, denied, permanentlyDenied }

/// Quyền camera cho màn quét QR; tách ra để test thay bằng bản giả.
abstract interface class CameraPermission {
  /// Xin quyền (hệ điều hành chỉ hỏi khi còn được hỏi) và trả trạng thái sau đó.
  Future<CameraPermissionStatus> request();

  /// Mở trang Cài đặt của app để người dùng tự bật quyền.
  Future<void> openSettings();
}

class SystemCameraPermission implements CameraPermission {
  const SystemCameraPermission();

  @override
  Future<CameraPermissionStatus> request() async {
    final status = await Permission.camera.request();
    if (status.isGranted || status.isLimited) return CameraPermissionStatus.granted;
    if (status.isPermanentlyDenied || status.isRestricted) {
      return CameraPermissionStatus.permanentlyDenied;
    }
    return CameraPermissionStatus.denied;
  }

  @override
  Future<void> openSettings() async {
    await openAppSettings();
  }
}
