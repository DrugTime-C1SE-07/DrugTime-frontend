import 'package:flutter/foundation.dart';

import '../../../consent/domain/entities/consent.dart';
import '../../domain/entities/caregiver_failure.dart';
import '../../domain/entities/incoming_link_request.dart';
import '../../domain/repositories/caregiver_repository.dart';

/// Yêu cầu theo dõi đang chờ gửi tới người dùng (vai patient), trên tab Người thân.
///
/// Không giữ danh sách làm căn cứ: tải lại khi mở tab, khi kéo xuống và sau mỗi thao tác.
/// Mỗi thao tác trả `null` khi thành công, hoặc loại lỗi để màn hiện câu báo.
class IncomingRequestsController extends ChangeNotifier {
  IncomingRequestsController(this._repository);

  final CaregiverRepository _repository;

  List<IncomingLinkRequest> _items = const [];
  bool _loading = false;
  CaregiverFailureKind? _loadError;
  final Set<int> _busy = {};
  bool _disposed = false;

  List<IncomingLinkRequest> get items => _items;
  bool get isLoading => _loading;

  /// Lỗi của lần tải gần nhất; danh sách cũ vẫn được giữ để hiển thị.
  CaregiverFailureKind? get loadError => _loadError;

  /// Đang gửi thao tác cho yêu cầu [linkId]: khóa hai nút của mục đó.
  bool isBusy(int linkId) => _busy.contains(linkId);

  Future<void> load() async {
    _loading = true;
    _notify();
    try {
      _items = await _repository.listPendingRequests();
      _loadError = null;
    } on CaregiverFailure catch (failure) {
      _loadError = failure.kind;
    } finally {
      _loading = false;
      _notify();
    }
  }

  /// Chỉ gọi sau khi người dùng đã tick xác nhận đồng ý chia sẻ cho đúng người này.
  Future<CaregiverFailureKind?> approve(IncomingLinkRequest request) => _run(
        request.linkId,
        () => _repository.approve(
          linkId: request.linkId,
          familyUserId: request.familyUserId,
          documentVersion: ConsentPurpose.familySharing.documentVersion,
        ),
      );

  Future<CaregiverFailureKind?> reject(IncomingLinkRequest request) =>
      _run(request.linkId, () => _repository.reject(request.linkId));

  /// Lối tắt "Bật chia sẻ ngay" sau khi chấp thuận; liên kết đã rời danh sách chờ nên không tải
  /// lại danh sách này.
  Future<CaregiverFailureKind?> enableSharing(int linkId) async {
    try {
      await _repository.setSharing(linkId, enabled: true);
      return null;
    } on CaregiverFailure catch (failure) {
      return failure.kind;
    }
  }

  // Màn khóa nút khi [isBusy]; lần gọi trùng (nếu có) bị bỏ qua và trả null, không gửi lại.
  Future<CaregiverFailureKind?> _run(int linkId, Future<void> Function() action) async {
    if (!_busy.add(linkId)) return null;
    _notify();
    CaregiverFailureKind? error;
    try {
      await action();
    } on CaregiverFailure catch (failure) {
      error = failure.kind;
    } finally {
      _busy.remove(linkId);
    }
    // Thành công hay lỗi đều đọc lại từ server: trạng thái thật có thể đã khác danh sách đang có.
    await load();
    return error;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
