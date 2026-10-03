/// Lỗi của thao tác thuốc, đã dịch từ lỗi HTTP để tầng giao diện không phụ thuộc API.
library;

enum MedicationFailureKind {
  /// Không kết nối được máy chủ, hết thời gian chờ, hoặc máy chủ lỗi tạm thời.
  network,

  /// 401: phiên hết hạn; app đã được đưa về màn Đăng nhập.
  unauthorized,

  /// 403 `khong_co_quyen`.
  forbidden,

  /// 403 `consent_revoked`: người bệnh đã rút đồng ý chia sẻ dữ liệu sức khỏe.
  consentRevoked,

  /// 404 `user_medication_not_found`: thuốc không còn (đã xoá ở nơi khác).
  notFound,

  /// 422 `catalog_medication_not_found`.
  catalogNotFound,

  /// 422 `medication_rule_violation`.
  ruleViolation,

  /// 422 `medication_stopped`: thuốc đã ngừng, phải dùng lại trước khi sửa.
  stopped,

  /// 422 dạng mảng lỗi từng field: dữ liệu gửi đi sai cấu trúc.
  validation,

  unknown,
}

class MedicationFailure implements Exception {
  const MedicationFailure(this.kind, [this.detail]);

  final MedicationFailureKind kind;

  /// Nội dung gốc để ghi log/debug; không hiển thị cho người dùng.
  final String? detail;

  @override
  String toString() => 'MedicationFailure(${kind.name}${detail == null ? '' : ': $detail'})';
}
