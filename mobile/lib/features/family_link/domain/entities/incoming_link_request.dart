/// Yêu cầu theo dõi đang chờ mà người khác gửi tới người dùng (vai patient),
/// `PendingFamilyLink` trong contract.
class IncomingLinkRequest {
  const IncomingLinkRequest({
    required this.linkId,
    required this.familyUserId,
    required this.familyName,
    required this.requestedAt,
    this.familyPhone,
    this.familyEmail,
  });

  final int linkId;
  final String familyUserId;

  /// `null` khi người gửi chưa có tên hiển thị; giao diện dùng tên thay thế.
  final String? familyName;
  final DateTime requestedAt;

  /// SĐT người thân nếu API trả về (chỉ hiển thị khi có, không tự suy ra).
  final String? familyPhone;

  /// Email người thân nếu API trả về (chỉ hiển thị khi có, không tự suy ra).
  final String? familyEmail;
}
