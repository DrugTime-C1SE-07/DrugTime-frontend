/// Cấu hình lúc build, truyền bằng `--dart-define-from-file` (hoặc `--dart-define`).
///
/// Ví dụ chạy với backend local trên Android emulator (tạo `.env.android` từ `.env.example`):
///   flutter run --dart-define-from-file=.env.android
abstract final class AppConfig {
  /// Địa chỉ Backend API. Rỗng = chưa cấu hình (app báo lỗi, không dùng dữ liệu giả).
  static const apiBaseUrl = String.fromEnvironment('DRUGTIME_API_BASE_URL');

  static bool get isConfigured => apiBaseUrl.isNotEmpty;

  /// Host của link mời người thân `https://<host>/link#code=<mã>` (trang `/link` của landing).
  /// Đổi host thì sửa cả `intent-filter` App Links trong `android/app/src/main/AndroidManifest.xml`.
  static const inviteLinkHost = String.fromEnvironment(
    'DRUGTIME_INVITE_LINK_HOST',
    defaultValue: 'drug-time-frontend.vercel.app',
  );
}
