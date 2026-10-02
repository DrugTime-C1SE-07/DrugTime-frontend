/// Cấu hình lúc build, truyền bằng `--dart-define-from-file` (hoặc `--dart-define`).
///
/// Ví dụ chạy với backend local trên Android emulator (tạo `.env.android` từ `.env.example`):
///   flutter run --dart-define-from-file=.env.android
abstract final class AppConfig {
  /// Địa chỉ Backend API. Rỗng = chưa cấu hình (app báo lỗi, không dùng dữ liệu giả).
  static const apiBaseUrl = String.fromEnvironment('DRUGTIME_API_BASE_URL');

  static bool get isConfigured => apiBaseUrl.isNotEmpty;
}
