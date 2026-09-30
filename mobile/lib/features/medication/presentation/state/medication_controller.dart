import 'package:flutter/widgets.dart';

import '../../domain/entities/medication.dart';
import '../../domain/repositories/medication_repository.dart';

class MedicationController extends ChangeNotifier {
  MedicationController(this._repository);

  final MedicationRepository _repository;

  List<Medication> _medications = const [];
  bool _isLoading = false;

  List<Medication> get medications => _medications;
  bool get isLoading => _isLoading;

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    _medications = await _repository.fetchAll();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> add(Medication medication) async {
    await _repository.add(medication);
    _medications = await _repository.fetchAll();
    notifyListeners();
  }

  Future<List<DrugCatalogItem>> searchCatalog(String query) =>
      _repository.searchCatalog(query);

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
