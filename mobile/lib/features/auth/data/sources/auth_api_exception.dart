/// Lỗi gọi Backend Identity API, đã phân loại theo mã HTTP của API contract.
/// UI hiển thị thông điệp theo [kind], không hiển thị nguyên `detail` của backend.
library;

enum AuthErrorKind {
  /// 401: sai/hết hạn mã OTP, phiên không hợp lệ hoặc tài khoản đã bị xóa.
  invalidCredentials,

  /// 403 `admin_must_use_web`: tài khoản quản trị phải dùng Admin Web.
  adminMustUseWeb,

  /// 422: dữ liệu không hợp lệ; [AuthApiException.code] là mã ổn định nếu có.
  invalidInput,

  /// 429 `rate_limited`.
  rateLimited,

  /// 503 hoặc lỗi 5xx khác: dịch vụ xác thực đang lỗi.
  unavailable,

  /// Không kết nối được máy chủ (mất mạng, timeout).
  network,

  /// Mã trạng thái ngoài contract.
  unexpected,
}

class AuthApiException implements Exception {
  const AuthApiException(this.kind, {this.statusCode, this.code});

  final AuthErrorKind kind;
  final int? statusCode;

  /// `detail` dạng mã snake_case (403, 422 nghiệp vụ, 429, 503); null với 401 hoặc lỗi theo field.
  final String? code;

  factory AuthApiException.fromStatus(int statusCode, {String? code}) {
    final kind = switch (statusCode) {
      401 => AuthErrorKind.invalidCredentials,
      403 => AuthErrorKind.adminMustUseWeb,
      422 => AuthErrorKind.invalidInput,
      429 => AuthErrorKind.rateLimited,
      >= 500 => AuthErrorKind.unavailable,
      _ => AuthErrorKind.unexpected,
    };
    return AuthApiException(kind, statusCode: statusCode, code: code);
  }

  @override
  String toString() => 'AuthApiException($kind, status: $statusCode, code: $code)';
}
