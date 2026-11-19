import 'package:flutter/foundation.dart';

import '../../../consent/domain/entities/consent.dart';
import '../../domain/entities/caregiver_failure.dart';
import '../../domain/entities/incoming_link_request.dart';
import '../../domain/repositories/caregiver_repository.dart';

/// Yêu cầu theo dõi đang chờ gửi tới người dùng (vai patient), trên tab Người thân.
///
/// Không cache ngoại tuyến: cần kết nối mạng để tải và cập nhật.
/// Tải lại khi mở app, vào foreground, khi mở tab, kéo xuống và sau mỗi thao tác.
/// Mỗi thao tác trả `null` khi thành công, hoặc loại lỗi để màn hiện câu báo tiếng Việt.
class IncomingRequestsController extends ChangeNotifier {
  IncomingRequestsController(
    this._repository, {
    this.onLinkedCaregiversChanged,
  });

  final CaregiverRepository _repository;

  /// Gọi khi một yêu cầu được chấp thuận hoặc từ chối để làm mới danh sách người giám sát.
  final VoidCallback? onLinkedCaregiversChanged;

  List<IncomingLinkRequest> _items = const [];
  bool _loading = false;
  bool _isLoaded = false;
  CaregiverFailureKind? _loadError;
  final Set<int> _busy = {};
  bool _disposed = false;

  List<IncomingLinkRequest> get items => _items;
  int get pendingCount => _items.length;
  bool get isLoading => _loading;
  bool get isLoaded => _isLoaded;

  /// Đã tải thành công ít nhất một lần và danh sách rỗng.
  bool get isEmpty => _isLoaded && _items.isEmpty && _loadError == null;

  /// Gặp lỗi kết nối mạng (cần kết nối mạng, không cache ngoại tuyến).
  bool get isOffline => _loadError == CaregiverFailureKind.network;

  /// Lỗi của lần tải gần nhất; danh sách cũ vẫn được giữ để hiển thị nếu có.
  CaregiverFailureKind? get loadError => _loadError;

  /// Đang gửi thao tác cho yêu cầu [linkId]: khóa các nút thao tác của mục đó.
  bool isBusy(int linkId) => _busy.contains(linkId);

  Future<void> load() async {
    _loading = true;
    _notify();
    try {
      _items = await _repository.listPendingRequests();
      _loadError = null;
      _isLoaded = true;
    } on CaregiverFailure catch (failure) {
      _loadError = failure.kind;
    } catch (_) {
      _loadError = CaregiverFailureKind.unknown;
    } finally {
      _loading = false;
      _notify();
    }
  }

  /// Chấp thuận yêu cầu liên kết với phiên bản văn bản đồng ý chia sẻ hiện tại.
  Future<CaregiverFailureKind?> approve(IncomingLinkRequest request) async {
    final error = await _run(
      request.linkId,
      () => _repository.approve(
        linkId: request.linkId,
        familyUserId: request.familyUserId,
        documentVersion: ConsentPurpose.familySharing.documentVersion,
      ),
    );
    if (error == null) {
      onLinkedCaregiversChanged?.call();
    }
    return error;
  }

  /// Từ chối yêu cầu liên kết.
  Future<CaregiverFailureKind?> reject(IncomingLinkRequest request) async {
    final error = await _run(request.linkId, () => _repository.reject(request.linkId));
    if (error == null) {
      onLinkedCaregiversChanged?.call();
    }
    return error;
  }

  /// Lối tắt "Bật chia sẻ ngay" sau khi chấp thuận.
  Future<CaregiverFailureKind?> enableSharing(int linkId) async {
    try {
      await _repository.setSharing(linkId, enabled: true);
      onLinkedCaregiversChanged?.call();
      return null;
    } on CaregiverFailure catch (failure) {
      return failure.kind;
    } catch (_) {
      return CaregiverFailureKind.unknown;
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
    } catch (_) {
      error = CaregiverFailureKind.unknown;
    } finally {
      _busy.remove(linkId);
    }
    // Thành công hay lỗi đều đọc lại từ server để đồng bộ trạng thái thực tế.
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
