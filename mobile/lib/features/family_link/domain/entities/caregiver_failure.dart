/// Lỗi khi patient quản lý yêu cầu theo dõi và người giám sát, đã dịch từ phản hồi HTTP.
library;

enum CaregiverFailureKind {
  /// 403 `khong_co_quyen`: không phải chủ liên kết (hoặc tài khoản admin).
  forbidden,

  /// 403 `consent_revoked`: chưa bật hoặc đã tắt "Chia sẻ với người thân" (`family_sharing`).
  consentRequired,

  /// 404 `family_link_not_found`.
  notFound,

  /// 409 `invalid_link_transition`, `family_link_not_active`, `link_approval_conflict`: dữ liệu
  /// trên màn đã cũ; tải lại.
  conflict,

  /// 409 `consent_confirmation_missing`: liên kết cũ không có bằng chứng xác nhận.
  confirmationMissing,

  /// 422 `consent_document_outdated`: app hiển thị văn bản đồng ý cũ; cần cập nhật app.
  documentOutdated,

  /// 422 lỗi cấu trúc request (lỗi của app).
  invalid,

  /// 401: `ApiClient` đã đưa người dùng về màn Đăng nhập.
  unauthorized,

  /// Không kết nối được, hết thời gian chờ, hoặc lỗi máy chủ (5xx).
  network,

  unknown;

  /// Danh sách trên màn có thể đã cũ: tải lại.
  bool get needsReload => this == conflict || this == notFound;
}

class CaregiverFailure implements Exception {
  const CaregiverFailure(this.kind);

  final CaregiverFailureKind kind;

  @override
  String toString() => 'CaregiverFailure(${kind.name})';
}
