import '../../domain/entities/dose_unit.dart';
import '../../domain/entities/medication.dart';
import '../../domain/entities/medication_failure.dart';
import '../../domain/repositories/medication_repository.dart';

/// Dữ liệu mẫu trong bộ nhớ: dùng cho bản web (xem giao diện, không có `dart:io`) và test.
/// Mô phỏng hành vi của server ở những điểm app dựa vào: gửi lại cùng `clientUuid` không tạo
/// trùng, ngừng/dùng lại, thuốc đã xoá không còn tìm thấy.
class InMemoryMedicationRepository
    implements MedicationRepository, CatalogDetailSource, ScheduleReminderUpdater {
  InMemoryMedicationRepository({List<Medication>? seed})
      : _medications = [
          for (final m in (seed ?? sampleMedications))
            _hydrateSchedulesStatic(m),
        ];

  final List<Medication> _medications;
  final Map<String, String> _idByClientUuid = {};
  var _nextId = 1;
  var _nextScheduleId = 1000;

  static Medication _hydrateSchedulesStatic(Medication m) {
    if (m.frequency.isAsNeeded || m.schedules.isNotEmpty || m.times.isEmpty) {
      return m;
    }
    final seedBase = m.id.codeUnits.fold<int>(0, (a, c) => (a * 31 + c) & 0x7fff);
    return m.copyWith(
      schedules: [
        for (final (i, t) in m.times.indexed)
          MedicationScheduleEntry(
            id: seedBase * 10 + i + 1,
            intakeTime: t,
            daysOfWeek: m.daysOfWeek,
            reminderEnabled: m.reminderEnabled,
          ),
      ],
    );
  }

  Medication _syncSchedules(
    Medication med, {
    List<MedicationScheduleEntry>? existingSchedules,
  }) {
    if (med.frequency.isAsNeeded) {
      return med.copyWith(schedules: const []);
    }
    final existingByTime = {
      for (final s in (existingSchedules ?? med.schedules)) s.intakeTime: s,
    };
    final sortedTimes = [...med.times]..sort();
    final nextSchedules = <MedicationScheduleEntry>[
      for (final t in sortedTimes)
        MedicationScheduleEntry(
          id: existingByTime[t]?.id ?? (_nextScheduleId++),
          intakeTime: t,
          daysOfWeek: med.daysOfWeek,
          reminderEnabled: existingByTime[t]?.reminderEnabled ?? med.reminderEnabled,
        ),
    ];
    final anyEnabled =
        nextSchedules.isEmpty ? med.reminderEnabled : nextSchedules.any((s) => s.reminderEnabled);
    return med.copyWith(
      times: sortedTimes,
      schedules: List.unmodifiable(nextSchedules),
      reminderEnabled: anyEnabled,
    );
  }

  @override
  Future<List<Medication>> fetchAll() async => List.unmodifiable(_medications);

  @override
  Future<Medication> add(Medication draft, {required String clientUuid}) async {
    final existingId = _idByClientUuid[clientUuid];
    if (existingId != null) return _find(existingId);
    final created = _syncSchedules(
      draft.copyWith(id: 'local-${_nextId++}', status: MedicationStatus.active),
    );
    _idByClientUuid[clientUuid] = created.id;
    _medications.insert(0, created);
    return created;
  }

  @override
  Future<Medication> update(Medication before, Medication after) async {
    final current = _find(before.id);
    if (!current.isActive) throw const MedicationFailure(MedicationFailureKind.stopped);
    final synced = _syncSchedules(after, existingSchedules: current.schedules);
    _replace(synced);
    return synced;
  }

  @override
  Future<Medication> updateScheduleReminder(
    String medicationId,
    int scheduleId,
    bool reminderEnabled,
  ) async {
    final current = _find(medicationId);
    if (!current.isActive) throw const MedicationFailure(MedicationFailureKind.stopped);
    final idx = current.schedules.indexWhere((s) => s.id == scheduleId);
    if (idx < 0) throw const MedicationFailure(MedicationFailureKind.notFound);
    final nextSchedules = [
      for (var i = 0; i < current.schedules.length; i++)
        i == idx
            ? current.schedules[i].copyWith(reminderEnabled: reminderEnabled)
            : current.schedules[i],
    ];
    final next = current.copyWith(
      schedules: List.unmodifiable(nextSchedules),
      reminderEnabled: nextSchedules.any((s) => s.reminderEnabled),
    );
    _replace(next);
    return next;
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
      schedules: current.schedules,
      daysOfWeek: current.daysOfWeek,
      status: stopped ? MedicationStatus.stopped : MedicationStatus.active,
      stockRemaining: current.stockRemaining,
      endedOn: stopped ? DateTime.now() : null,
      dosageForm: current.dosageForm,
      maxDosesPerDay: current.maxDosesPerDay,
      reminderEnabled: current.reminderEnabled,
      pillShape: current.pillShape,
      pillColor: current.pillColor,
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

  /// Bản giả: chỉ có dữ liệu của `sampleCatalog`, không có nhà sản xuất hay xuất xứ.
  @override
  Future<DrugCatalogDetail> fetchCatalogDetail(String catalogId) async {
    for (final d in sampleCatalog) {
      if (d.id == catalogId) {
        return DrugCatalogDetail(
          id: d.id,
          name: d.name,
          activeIngredient: d.activeIngredient.isEmpty ? null : d.activeIngredient,
          strength: d.strength.isEmpty ? null : d.strength,
          dosageForm: d.dosageForm.isEmpty ? null : d.dosageForm,
        );
      }
    }
    throw const MedicationFailure(MedicationFailureKind.notFound);
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
