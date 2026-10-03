import '../../domain/entities/dose_unit.dart';
import '../../domain/entities/medication.dart';
import '../../domain/entities/medication_failure.dart';
import '../../domain/repositories/medication_repository.dart';

/// Dữ liệu mẫu trong bộ nhớ: dùng cho bản web (xem giao diện, không có `dart:io`) và test.
/// Mô phỏng hành vi của server ở những điểm app dựa vào: gửi lại cùng `clientUuid` không tạo
/// trùng, ngừng/dùng lại, thuốc đã xoá không còn tìm thấy.
class InMemoryMedicationRepository implements MedicationRepository {
  InMemoryMedicationRepository({List<Medication>? seed})
      : _medications = [...(seed ?? sampleMedications)];

  final List<Medication> _medications;
  final Map<String, String> _idByClientUuid = {};
  var _nextId = 1;

  @override
  Future<List<Medication>> fetchAll() async => List.unmodifiable(_medications);

  @override
  Future<Medication> add(Medication draft, {required String clientUuid}) async {
    final existingId = _idByClientUuid[clientUuid];
    if (existingId != null) return _find(existingId);
    final created = draft.copyWith(id: 'local-${_nextId++}', status: MedicationStatus.active);
    _idByClientUuid[clientUuid] = created.id;
    _medications.insert(0, created);
    return created;
  }

  @override
  Future<Medication> update(Medication before, Medication after) async {
    final current = _find(before.id);
    if (!current.isActive) throw const MedicationFailure(MedicationFailureKind.stopped);
    _replace(after);
    return after;
  }

  @override
  Future<Medication> setStopped(String id, bool stopped) async {
    final current = _find(id);
    if (stopped == !current.isActive) return current;
    final next = Medication(
      id: current.id,
      catalogId: current.catalogId,
      name: current.name,
      activeIngredient: current.activeIngredient,
      strength: current.strength,
      unit: current.unit,
      dosePerIntake: current.dosePerIntake,
      frequency: current.frequency,
      timing: current.timing,
      times: current.times,
      status: stopped ? MedicationStatus.stopped : MedicationStatus.active,
      stockRemaining: current.stockRemaining,
      endedOn: stopped ? DateTime.now() : null,
      dosageForm: current.dosageForm,
      maxDosesPerDay: current.maxDosesPerDay,
    );
    _replace(next);
    return next;
  }

  @override
  Future<void> delete(String id) async {
    _find(id);
    _medications.removeWhere((m) => m.id == id);
  }

  @override
  Future<List<DrugCatalogItem>> searchCatalog(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return sampleCatalog
        .where((d) =>
            d.name.toLowerCase().contains(q) ||
            d.activeIngredient.toLowerCase().contains(q))
        .toList();
  }

  Medication _find(String id) {
    for (final m in _medications) {
      if (m.id == id) return m;
    }
    throw const MedicationFailure(MedicationFailureKind.notFound);
  }

  void _replace(Medication medication) {
    final index = _medications.indexWhere((m) => m.id == medication.id);
    _medications[index] = medication;
  }
}

DrugCatalogItem _sample({
  required String id,
  required String name,
  required String activeIngredient,
  required String strength,
  required String dosageForm,
}) =>
    DrugCatalogItem(
      id: id,
      name: name,
      activeIngredient: activeIngredient,
      strength: strength,
      dosageForm: dosageForm,
      unit: doseUnitFor(dosageForm),
    );

final sampleCatalog = <DrugCatalogItem>[
  _sample(
    id: 'metformin-500',
    name: 'Metformin 500mg',
    activeIngredient: 'Metformin hydrochloride',
    strength: '500 mg',
    dosageForm: 'Viên nén bao phim',
  ),
  _sample(
    id: 'glucophage-850',
    name: 'Glucophage 850mg',
    activeIngredient: 'Metformin hydrochloride',
    strength: '850 mg',
    dosageForm: 'Viên nén bao phim',
  ),
  _sample(
    id: 'losartan-50',
    name: 'Losartan 50mg',
    activeIngredient: 'Losartan kali',
    strength: '50 mg',
    dosageForm: 'Viên nén bao phim',
  ),
  _sample(
    id: 'amlodipin-5',
    name: 'Amlodipin 5mg',
    activeIngredient: 'Amlodipin besilat',
    strength: '5 mg',
    dosageForm: 'Viên nén',
  ),
  _sample(
    id: 'atorvastatin-20',
    name: 'Atorvastatin 20mg',
    activeIngredient: 'Atorvastatin calci',
    strength: '20 mg',
    dosageForm: 'Viên nén bao phim',
  ),
  _sample(
    id: 'omeprazol-20',
    name: 'Omeprazol 20mg',
    activeIngredient: 'Omeprazol',
    strength: '20 mg',
    dosageForm: 'Viên nang cứng',
  ),
  _sample(
    id: 'paracetamol-500',
    name: 'Paracetamol 500mg',
    activeIngredient: 'Paracetamol',
    strength: '500 mg',
    dosageForm: 'Viên nén',
  ),
  _sample(
    id: 'hapacol-250',
    name: 'Hapacol 250',
    activeIngredient: 'Paracetamol',
    strength: '250 mg / gói',
    dosageForm: 'Thuốc cốm sủi bọt (gói)',
  ),
  _sample(
    id: 'amoxicillin-500',
    name: 'Amoxicillin 500mg',
    activeIngredient: 'Amoxicillin',
    strength: '500 mg',
    dosageForm: 'Viên nang cứng',
  ),
  _sample(
    id: 'vitamin-d3-1000',
    name: 'Vitamin D3 1000IU',
    activeIngredient: 'Cholecalciferol',
    strength: '1000 IU',
    dosageForm: 'Viên nang mềm',
  ),
];

final sampleMedications = <Medication>[
  const Medication(
    id: 'm1',
    catalogId: 'metformin-500',
    dosageForm: 'Viên nén bao phim',
    name: 'Metformin 500mg',
    activeIngredient: 'Metformin hydrochloride',
    strength: '500 mg',
    unit: 'viên',
    dosePerIntake: 1,
    frequency: DoseFrequency.twice,
    timing: IntakeTiming.afterMeal,
    times: [DoseTime(8, 0), DoseTime(20, 0)],
    stockRemaining: 18,
  ),
  const Medication(
    id: 'm2',
    catalogId: 'losartan-50',
    dosageForm: 'Viên nén bao phim',
    name: 'Losartan 50mg',
    activeIngredient: 'Losartan kali',
    strength: '50 mg',
    unit: 'viên',
    dosePerIntake: 1,
    frequency: DoseFrequency.once,
    timing: IntakeTiming.anytime,
    times: [DoseTime(7, 0)],
    stockRemaining: 3,
  ),
  const Medication(
    id: 'm3',
    catalogId: 'vitamin-d3-1000',
    dosageForm: 'Viên nang mềm',
    name: 'Vitamin D3 1000IU',
    activeIngredient: 'Cholecalciferol',
    strength: '1000 IU',
    unit: 'viên',
    dosePerIntake: 1,
    frequency: DoseFrequency.once,
    timing: IntakeTiming.afterMeal,
    times: [DoseTime(8, 0)],
    stockRemaining: 25,
  ),
  const Medication(
    id: 'm4',
    catalogId: 'paracetamol-500',
    dosageForm: 'Viên nén',
    name: 'Paracetamol 500mg',
    activeIngredient: 'Paracetamol',
    strength: '500 mg',
    unit: 'viên',
    dosePerIntake: 1,
    frequency: DoseFrequency.asNeeded,
    timing: IntakeTiming.afterMeal,
    maxDosesPerDay: 3,
    stockRemaining: 10,
  ),
  Medication(
    id: 'm5',
    catalogId: 'amoxicillin-500',
    dosageForm: 'Viên nang cứng',
    name: 'Amoxicillin 500mg',
    activeIngredient: 'Amoxicillin',
    strength: '500 mg',
    unit: 'viên',
    dosePerIntake: 1,
    frequency: DoseFrequency.thrice,
    timing: IntakeTiming.afterMeal,
    times: const [DoseTime(7, 0), DoseTime(12, 0), DoseTime(19, 0)],
    status: MedicationStatus.stopped,
    endedOn: DateTime(2026, 8, 12),
  ),
];
