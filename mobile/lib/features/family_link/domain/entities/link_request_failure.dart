/// Lỗi khi gửi yêu cầu liên kết, đã dịch từ phản hồi HTTP để tầng giao diện không phụ thuộc API.
library;

enum LinkRequestFailureKind {
  /// 404 `link_code_not_found`: mã không tồn tại, hoặc patient chưa đồng ý `family_sharing`.
  /// Server cố ý không phân biệt hai trường hợp (BS-05).
  codeNotFound,

  /// 422 `self_link_not_allowed`.
  selfLink,

  /// 422 lỗi field: mã sai định dạng.
  invalidFormat,

  /// 409 `link_request_pending`: đã có yêu cầu đang chờ. Client coi như đã gửi.
  alreadyPending,

  /// 409 `already_linked`.
  alreadyLinked,

  /// 429 `link_request_locked`: nhập sai nhiều lần.
  locked,

  /// 429 `link_request_daily_limit`.
  dailyLimit,

  /// 429 `link_request_cooldown`: bị cùng patient từ chối 5 lần liên tiếp (BS-04).
  cooldown,

  /// 401: phiên hết hạn; `ApiClient` đã đưa người dùng về màn Đăng nhập.
  unauthorized,

  /// Không kết nối được, hết thời gian chờ, hoặc lỗi máy chủ.
  network,

  unknown;

  /// Bị giới hạn tạm thời; gửi lại chỉ có ý nghĩa sau `retryAfter`.
  bool get isRateLimited => this == locked || this == dailyLimit || this == cooldown;
}

class LinkRequestFailure implements Exception {
  const LinkRequestFailure(this.kind, {this.retryAfter});

  final LinkRequestFailureKind kind;

  /// Thời gian phải chờ (header `Retry-After`) khi [kind] là lỗi 429.
  final Duration? retryAfter;

  // Không đưa body phản hồi hay mã liên kết vào đây: đối tượng lỗi có thể bị in ra log.
  @override
  String toString() => 'LinkRequestFailure(${kind.name})';
}
