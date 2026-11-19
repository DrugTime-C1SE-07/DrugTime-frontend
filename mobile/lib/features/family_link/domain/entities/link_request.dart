/// Trạng thái của yêu cầu liên kết (`LinkRequestStatus` trong contract).
enum LinkRequestStatus {
  /// Đang chờ patient chấp thuận; người thân chưa xem được gì.
  pending,

  /// Patient đã chấp thuận.
  active,

  /// Patient đã từ chối.
  rejected,

  /// Liên kết đã bị hủy.
  revoked,

  /// Giá trị server trả mà app chưa biết (contract: client phải bỏ qua, không báo lỗi).
  unknown;

  static LinkRequestStatus fromApi(String? value) => switch (value) {
        'pending' => pending,
        'active' => active,
        'rejected' => rejected,
        'revoked' => revoked,
        _ => unknown,
      };
}

/// Yêu cầu liên kết của người gọi. Cố ý không có thông tin hồ sơ của patient (QD-34).
class LinkRequest {
  const LinkRequest({
    required this.id,
    required this.status,
    required this.requestedAt,
  });

  final int id;
  final LinkRequestStatus status;
  final DateTime requestedAt;
}
