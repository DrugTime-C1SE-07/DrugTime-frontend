enum HistoryFailureKind {
  unauthorized,
  consent,
  forbidden,
  network,
  validation,
  unavailable,
  invalidResponse,
  unconfigured,
}

class HistoryFailure implements Exception {
  const HistoryFailure(this.kind);
  final HistoryFailureKind kind;

  bool get removesAccess => {
        HistoryFailureKind.unauthorized,
        HistoryFailureKind.consent,
        HistoryFailureKind.forbidden,
      }.contains(kind);

  String get message => switch (kind) {
        HistoryFailureKind.unauthorized => 'Vui lòng đăng nhập lại.',
        HistoryFailureKind.consent =>
          'Bạn cần đồng ý xử lý dữ liệu sức khỏe để xem lịch sử.',
        HistoryFailureKind.forbidden => 'Bạn không có quyền xem lịch sử này.',
        HistoryFailureKind.network =>
          'Không kết nối được. Vui lòng kiểm tra mạng và thử lại.',
        HistoryFailureKind.validation => 'Khoảng thời gian không hợp lệ.',
        HistoryFailureKind.unconfigured =>
          'Chưa có kết nối Backend để xem lịch sử.',
        HistoryFailureKind.invalidResponse =>
          'Dữ liệu lịch sử không hợp lệ. Vui lòng thử lại.',
        HistoryFailureKind.unavailable =>
          'Không tải được lịch sử. Vui lòng thử lại.',
      };

  @override
  String toString() => 'HistoryFailure(${kind.name})';
}
