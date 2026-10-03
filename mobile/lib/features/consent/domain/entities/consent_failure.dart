/// Lỗi của thao tác consent, đã dịch từ lỗi HTTP để tầng giao diện không phụ thuộc API.
library;

enum ConsentFailureKind {
  /// Không kết nối được máy chủ, hết thời gian chờ, hoặc máy chủ lỗi tạm thời.
  network,

  /// 401: phiên hết hạn; app đã được đưa về màn Đăng nhập.
  unauthorized,

  /// 422 `consent_document_outdated`: văn bản app hiển thị không phải bản hiện hành.
  documentOutdated,

  unknown,
}

class ConsentFailure implements Exception {
  const ConsentFailure(this.kind, [this.detail]);

  final ConsentFailureKind kind;

  /// Nội dung gốc để ghi log/debug; không hiển thị cho người dùng.
  final String? detail;

  @override
  String toString() => 'ConsentFailure(${kind.name}${detail == null ? '' : ': $detail'})';
}
