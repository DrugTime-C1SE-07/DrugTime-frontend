import '../../domain/entities/medication.dart';
import '../../domain/repositories/medication_repository.dart';

/// Dữ liệu mẫu trong bộ nhớ, dùng cho giai đoạn dựng UI trước khi có API.
class InMemoryMedicationRepository implements MedicationRepository {
  InMemoryMedicationRepository({List<Medication>? seed})
      : _medications = [...(seed ?? sampleMedications)];

  final List<Medication> _medications;

  @override
  Future<List<Medication>> fetchAll() async => List.unmodifiable(_medications);

  @override
  Future<void> add(Medication medication) async {
    _medications.insert(0, medication);
  }

  @override
  Future<void> update(Medication medication) async {
    final index = _medications.indexWhere((m) => m.id == medication.id);
    if (index != -1) {
      _medications[index] = medication;
    }
  }

  @override
  Future<void> delete(String id) async {
    _medications.removeWhere((m) => m.id == id);
  }

  @override
  Future<List<DrugCatalogItem>> searchCatalog(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return sampleCatalog;
    return sampleCatalog
        .where((d) =>
            d.name.toLowerCase().contains(q) ||
            d.activeIngredient.toLowerCase().contains(q))
        .toList();
  }

  @override
  Future<DrugCatalogItem?> findCatalogItem(String catalogId) async {
    try {
      return sampleCatalog.firstWhere((d) => d.id == catalogId);
    } catch (_) {
      return null;
    }
  }
}

const sampleCatalog = <DrugCatalogItem>[
  DrugCatalogItem(
    id: 'metformin-500',
    name: 'Metformin 500mg',
    activeIngredient: 'Metformin hydrochloride',
    strength: '500 mg',
    dosageForm: 'Viên nén bao phim',
  ),
  DrugCatalogItem(
    id: 'glucophage-850',
    name: 'Glucophage 850mg',
    activeIngredient: 'Metformin hydrochloride',
    strength: '850 mg',
    dosageForm: 'Viên nén bao phim',
  ),
  DrugCatalogItem(
    id: 'losartan-50',
    name: 'Losartan 50mg',
    activeIngredient: 'Losartan kali',
    strength: '50 mg',
    dosageForm: 'Viên nén bao phim',
  ),
  DrugCatalogItem(
    id: 'amlodipin-5',
    name: 'Amlodipin 5mg',
    activeIngredient: 'Amlodipin besilat',
    strength: '5 mg',
    dosageForm: 'Viên nén',
  ),
  DrugCatalogItem(
    id: 'atorvastatin-20',
    name: 'Atorvastatin 20mg',
    activeIngredient: 'Atorvastatin calci',
    strength: '20 mg',
    dosageForm: 'Viên nén bao phim',
  ),
  DrugCatalogItem(
    id: 'omeprazol-20',
    name: 'Omeprazol 20mg',
    activeIngredient: 'Omeprazol',
    strength: '20 mg',
    dosageForm: 'Viên nang cứng',
  ),
  DrugCatalogItem(
    id: 'paracetamol-500',
    name: 'Paracetamol 500mg',
    activeIngredient: 'Paracetamol',
    strength: '500 mg',
    dosageForm: 'Viên nén',
  ),
  DrugCatalogItem(
    id: 'hapacol-250',
    name: 'Hapacol 250',
    activeIngredient: 'Paracetamol',
    strength: '250 mg / gói',
    dosageForm: 'Thuốc cốm sủi bọt',
    unit: 'gói',
  ),
  DrugCatalogItem(
    id: 'amoxicillin-500',
    name: 'Amoxicillin 500mg',
    activeIngredient: 'Amoxicillin',
    strength: '500 mg',
    dosageForm: 'Viên nang cứng',
  ),
  DrugCatalogItem(
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
    name: 'Paracetamol 500mg',
    activeIngredient: 'Paracetamol',
    strength: '500 mg',
    unit: 'viên',
    dosePerIntake: 1,
    frequency: DoseFrequency.asNeeded,
    timing: IntakeTiming.afterMeal,
    stockRemaining: 10,
  ),
  Medication(
    id: 'm5',
    catalogId: 'amoxicillin-500',
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
