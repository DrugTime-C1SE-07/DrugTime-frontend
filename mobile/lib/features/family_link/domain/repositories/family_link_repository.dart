import '../entities/link_request.dart';

/// Gửi yêu cầu liên kết của người dùng đang đăng nhập (vai người thân) tới patient chủ mã.
///
/// App không giữ trạng thái liên kết làm căn cứ phân quyền: server quyết định ở mỗi request.
abstract interface class FamilyLinkRepository {
  /// [code] là mã đã chuẩn hóa. [clientUuid] dùng lại đúng giá trị khi gửi lại cùng một lần
  /// bấm gửi (idempotent ở server). Ném `LinkRequestFailure` khi lỗi.
  Future<LinkRequest> sendLinkRequest({
    required String code,
    required String clientUuid,
  });
}
