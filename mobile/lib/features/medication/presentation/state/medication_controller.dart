import 'package:flutter/widgets.dart';

import '../../domain/entities/medication.dart';
import '../../domain/entities/medication_failure.dart';
import '../../domain/repositories/medication_repository.dart';

class MedicationController extends ChangeNotifier {
  MedicationController(this._repository);

  final MedicationRepository _repository;

  List<Medication> _medications = const [];
  bool _isLoading = false;
  MedicationFailure? _loadError;

  List<Medication> get medications => _medications;
  bool get isLoading => _isLoading;

  /// Lỗi của lần tải gần nhất; danh sách cũ (nếu có) vẫn giữ để hiển thị.
  MedicationFailure? get loadError => _loadError;

  Future<void> load() async {
    _isLoading = true;
    _loadError = null;
    notifyListeners();
    try {
      _medications = await _repository.fetchAll();
    } on MedicationFailure catch (failure) {
      _loadError = failure;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Đăng xuất: bỏ dữ liệu của người dùng trước.
  void clear() {
    _medications = const [];
    _loadError = null;
    _isLoading = false;
    notifyListeners();
  }

  /// Ném [MedicationFailure] khi lỗi; danh sách giữ nguyên.
  Future<Medication> add(Medication draft, {required String clientUuid}) =>
      _mutate(() => _repository.add(draft, clientUuid: clientUuid));

  Future<Medication> update(Medication before, Medication after) =>
      _mutate(() => _repository.update(before, after));

  Future<Medication> setStopped(String id, bool stopped) =>
      _mutate(() => _repository.setStopped(id, stopped));

  Future<void> delete(String id) => _mutate(() => _repository.delete(id));

  Future<List<DrugCatalogItem>> searchCatalog(String query) =>
      _repository.searchCatalog(query);

  /// Ghi xong thì tải lại từ server, không tự sửa danh sách tại chỗ.
  Future<T> _mutate<T>(Future<T> Function() write) async {
    final result = await write();
    await load();
    return result;
  }

  Medication? getMedicationById(String id) {
    for (final m in _medications) {
      if (m.id == id) return m;
    }
    return null;
  }

  /// Thuốc này đã nằm trong danh sách đang dùng chưa (tránh nhập trùng).
  bool isInUse(String catalogId) =>
      _medications.any((m) => m.catalogId == catalogId && m.isActive);
}

/// Đưa [MedicationController] xuống cây widget, rebuild khi dữ liệu đổi.
class MedicationScope extends InheritedNotifier<MedicationController> {
  const MedicationScope({
    super.key,
    required MedicationController controller,
    required super.child,
  }) : super(notifier: controller);

  /// Lấy controller và đăng ký rebuild khi dữ liệu thay đổi.
  static MedicationController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<MedicationScope>();
    assert(scope != null, 'Không tìm thấy MedicationScope phía trên widget này');
    return scope!.notifier!;
  }

  /// Lấy controller mà không rebuild — dùng trong callback / initState.
  static MedicationController read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<MedicationScope>();
    assert(scope != null, 'Không tìm thấy MedicationScope phía trên widget này');
    return scope!.notifier!;
  }
}
