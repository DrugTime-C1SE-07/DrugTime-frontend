import '../entities/caregiver.dart';
import '../entities/incoming_link_request.dart';

/// Phía patient của liên kết người thân: duyệt yêu cầu theo dõi và quản lý người giám sát.
///
/// Không cache: mỗi hàm gọi server. Mọi hàm ném `CaregiverFailure` khi lỗi.
abstract interface class CaregiverRepository {
  /// Yêu cầu đang chờ gửi tới người dùng, mới nhất trước.
  Future<List<IncomingLinkRequest>> listPendingRequests();

  /// Chấp thuận kèm xác nhận đồng ý chia sẻ cho đúng [familyUserId]. Chỉ gọi sau khi người dùng
  /// đã tick đồng ý; [documentVersion] là phiên bản văn bản `family_sharing` đã hiển thị.
  Future<void> approve({
    required int linkId,
    required String familyUserId,
    required String documentVersion,
  });

  Future<void> reject(int linkId);

  /// Người giám sát đang hoạt động.
  Future<List<Caregiver>> listCaregivers();

  /// Đặt công tắc chia sẻ; trả trạng thái server sau khi đặt.
  Future<Caregiver> setSharing(int linkId, {required bool enabled});

  Future<void> revoke(int linkId);
}
