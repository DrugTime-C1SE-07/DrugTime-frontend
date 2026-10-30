import 'dart:async';

import '../../domain/entities/caregiver.dart';
import '../../domain/entities/caregiver_failure.dart';
import '../../domain/entities/incoming_link_request.dart';
import '../../domain/repositories/caregiver_repository.dart';

/// Yêu cầu theo dõi và người giám sát trong bộ nhớ: bản web xem thử và test.
///
/// Mô phỏng hành vi server: chấp thuận chuyển yêu cầu thành người giám sát với công tắc tắt,
/// từ chối và hủy thì bỏ khỏi danh sách. Thao tác trên `linkId` không còn thì ném lỗi
/// `notFound`.
///
/// Test chèn lỗi hoặc làm chậm bằng [failures]: mỗi lời gọi lấy một phần tử đầu hàng đợi;
/// `CaregiverFailure` (hay lỗi khác) thì ném, `Completer` thì chờ test hoàn tất rồi mới chạy
/// tiếp, `null` thì chạy bình thường.
class InMemoryCaregiverRepository implements CaregiverRepository {
  InMemoryCaregiverRepository({
    List<IncomingLinkRequest>? pending,
    List<Caregiver>? caregivers,
    List<Object?>? failures,
  })  : pending = [...?pending],
        caregivers = [...?caregivers],
        failures = failures ?? [];

  final List<IncomingLinkRequest> pending;
  final List<Caregiver> caregivers;
  final List<Object?> failures;

  /// Tên các lời gọi đã nhận, kèm tham số, để test kiểm.
  final List<String> calls = [];

  /// Tham số của các lần chấp thuận.
  final List<({int linkId, String familyUserId, String documentVersion})> approvals = [];

  @override
  Future<List<IncomingLinkRequest>> listPendingRequests() async {
    calls.add('listPendingRequests');
    await _next();
    return List.unmodifiable(pending);
  }

  @override
  Future<void> approve({
    required int linkId,
    required String familyUserId,
    required String documentVersion,
  }) async {
    calls.add('approve:$linkId');
    approvals.add((linkId: linkId, familyUserId: familyUserId, documentVersion: documentVersion));
    await _next();
    final request = _takePending(linkId);
    caregivers.insert(
      0,
      Caregiver(
        linkId: request.linkId,
        familyUserId: request.familyUserId,
        familyName: request.familyName,
        sharingEnabled: false,
        approvedAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> reject(int linkId) async {
    calls.add('reject:$linkId');
    await _next();
    _takePending(linkId);
  }

  @override
  Future<List<Caregiver>> listCaregivers() async {
    calls.add('listCaregivers');
    await _next();
    return List.unmodifiable(caregivers);
  }

  @override
  Future<Caregiver> setSharing(int linkId, {required bool enabled}) async {
    calls.add('setSharing:$linkId:$enabled');
    await _next();
    final index = _caregiverIndex(linkId);
    return caregivers[index] = caregivers[index].copyWith(sharingEnabled: enabled);
  }

  @override
  Future<void> revoke(int linkId) async {
    calls.add('revoke:$linkId');
    await _next();
    caregivers.removeAt(_caregiverIndex(linkId));
  }

  Future<void> _next() async {
    if (failures.isEmpty) return;
    switch (failures.removeAt(0)) {
      case null:
        return;
      case final Completer<void> completer:
        await completer.future;
      case final Object error:
        throw error;
    }
  }

  IncomingLinkRequest _takePending(int linkId) {
    final index = pending.indexWhere((r) => r.linkId == linkId);
    if (index < 0) throw const CaregiverFailure(CaregiverFailureKind.notFound);
    return pending.removeAt(index);
  }

  int _caregiverIndex(int linkId) {
    final index = caregivers.indexWhere((c) => c.linkId == linkId);
    if (index < 0) throw const CaregiverFailure(CaregiverFailureKind.notFound);
    return index;
  }
}
