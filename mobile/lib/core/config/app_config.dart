/// Cấu hình lúc build, truyền bằng `--dart-define-from-file` (hoặc `--dart-define`).
///
/// Ví dụ chạy với backend local trên Android emulator (tạo `.env.android` từ `.env.example`):
///   flutter run --dart-define-from-file=.env.android
library;

import 'package:flutter/foundation.dart';

abstract final class AppConfig {
  static const previewRequested =
      bool.fromEnvironment('DRUGTIME_PREVIEW', defaultValue: true);
  static bool previewFor({required bool debug, required bool requested}) =>
      debug && requested;
  static bool get previewEnabled =>
      previewFor(debug: kDebugMode, requested: previewRequested);

  /// Legacy flag retained for compatibility; never selects a data source.
  static const adherenceDemoEnabled =
      bool.fromEnvironment('DRUGTIME_ADHERENCE_DEMO', defaultValue: false);

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
