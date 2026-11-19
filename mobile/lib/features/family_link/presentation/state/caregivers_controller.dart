import 'package:flutter/foundation.dart';

import '../../domain/entities/caregiver.dart';
import '../../domain/entities/caregiver_failure.dart';
import '../../domain/repositories/caregiver_repository.dart';

/// Người giám sát của người dùng (vai patient), trên màn Hồ sơ > Người giám sát.
///
/// Không cache: tải khi mở màn, khi kéo xuống và sau khi hủy liên kết. Công tắc hiện đúng giá trị
/// server trả về; lỗi thì giữ giá trị cũ. Mỗi thao tác trả `null` khi thành công, hoặc loại lỗi.
class CaregiversController extends ChangeNotifier {
  CaregiversController(this._repository);

  final CaregiverRepository _repository;

  List<Caregiver> _items = const [];
  bool _loading = false;
  bool _loaded = false;
  CaregiverFailureKind? _loadError;
  final Set<int> _busy = {};
  bool _disposed = false;

  List<Caregiver> get items => _items;
  bool get isLoading => _loading;

  /// Đã tải xong ít nhất một lần (phân biệt "đang tải lần đầu" với "danh sách rỗng").
  bool get isLoaded => _loaded;
  CaregiverFailureKind? get loadError => _loadError;

  /// Đang gửi thao tác cho liên kết [linkId]: khóa công tắc và nút hủy của mục đó.
  bool isBusy(int linkId) => _busy.contains(linkId);

  Future<void> load() async {
    _loading = true;
    _notify();
    try {
      _items = await _repository.listCaregivers();
      _loadError = null;
      _loaded = true;
    } on CaregiverFailure catch (failure) {
      _loadError = failure.kind;
    } finally {
      _loading = false;
      _notify();
    }
  }

  Future<CaregiverFailureKind?> setSharing(Caregiver caregiver, {required bool enabled}) =>
      _run(caregiver.linkId, () async {
        final updated = await _repository.setSharing(caregiver.linkId, enabled: enabled);
        _items = [
          for (final item in _items) item.linkId == updated.linkId ? updated : item,
        ];
      });

  Future<CaregiverFailureKind?> revoke(Caregiver caregiver) => _run(caregiver.linkId, () async {
        await _repository.revoke(caregiver.linkId);
        await load();
      });

  // Màn khóa điều khiển khi [isBusy]; lần gọi trùng (nếu có) bị bỏ qua và trả null.
  Future<CaregiverFailureKind?> _run(int linkId, Future<void> Function() action) async {
    if (!_busy.add(linkId)) return null;
    _notify();
    try {
      await action();
      return null;
    } on CaregiverFailure catch (failure) {
      if (failure.kind.needsReload) await load();
      return failure.kind;
    } finally {
      _busy.remove(linkId);
      _notify();
    }
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
