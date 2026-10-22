/// Người giám sát: người thân đã được người dùng (vai patient) chấp thuận, `Caregiver` trong
/// contract.
///
/// [sharingEnabled] chỉ là công tắc của liên kết; người thân xem được dữ liệu khi công tắc bật
/// và người dùng còn đồng ý `family_sharing`. Server quyết định ở mỗi request.
class Caregiver {
  const Caregiver({
    required this.linkId,
    required this.familyUserId,
    required this.familyName,
    required this.sharingEnabled,
    required this.approvedAt,
  });

  final int linkId;
  final String familyUserId;
  final String? familyName;
  final bool sharingEnabled;

  /// `null` với liên kết cũ không có bằng chứng xác nhận: hủy được nhưng không bật chia sẻ được.
  final DateTime? approvedAt;

  Caregiver copyWith({bool? sharingEnabled}) => Caregiver(
        linkId: linkId,
        familyUserId: familyUserId,
        familyName: familyName,
        sharingEnabled: sharingEnabled ?? this.sharingEnabled,
        approvedAt: approvedAt,
      );
}
