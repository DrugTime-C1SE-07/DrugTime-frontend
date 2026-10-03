import '../entities/consent.dart';

/// Consent của chính người dùng đang đăng nhập. Mọi hàm ném `ConsentFailure` khi lỗi.
///
/// Trạng thái consent chỉ dùng để hiển thị và điều hướng; quyền truy cập dữ liệu luôn do
/// server kiểm ở mỗi request.
abstract interface class ConsentRepository {
  /// Đủ ba mục đích, theo thứ tự [ConsentPurpose.values].
  Future<List<ConsentState>> fetchAll();

  /// Gửi lại khi đã đồng ý là an toàn: server trả consent hiện có, không ghi mới.
  Future<ConsentState> grant(ConsentPurpose purpose);

  /// Rút khi chưa đồng ý vẫn thành công.
  Future<ConsentState> withdraw(ConsentPurpose purpose);
}
