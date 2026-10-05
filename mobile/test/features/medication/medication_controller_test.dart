import 'package:drugtime_mobile/features/medication/data/repositories/in_memory_medication_repository.dart';
import 'package:drugtime_mobile/features/medication/domain/entities/medication.dart';
import 'package:drugtime_mobile/features/medication/domain/entities/medication_failure.dart';
import 'package:drugtime_mobile/features/medication/presentation/state/medication_controller.dart';
import 'package:flutter_test/flutter_test.dart';

/// Repository mẫu có thể bật lỗi cho từng thao tác và đếm số lần tải.
class FlakyRepository extends InMemoryMedicationRepository {
  FlakyRepository({super.seed});

  MedicationFailure? failFetch;
  MedicationFailure? failWrite;
  int fetches = 0;

  @override
  Future<List<Medication>> fetchAll() {
    fetches++;
    final failure = failFetch;
    if (failure != null) throw failure;
    return super.fetchAll();
  }

  @override
  Future<Medication> setStopped(String id, bool stopped) {
    final failure = failWrite;
    if (failure != null) throw failure;
    return super.setStopped(id, stopped);
  }

  @override
  Future<void> delete(String id) {
    final failure = failWrite;
    if (failure != null) throw failure;
    return super.delete(id);
  }
}

void main() {
  const network = MedicationFailure(MedicationFailureKind.network);

  test('load lỗi đặt loadError và giữ danh sách cũ', () async {
    final repo = FlakyRepository();
    final controller = MedicationController(repo);
    await controller.load();
    final before = controller.medications;
    expect(before, isNotEmpty);

    repo.failFetch = network;
    await controller.load();

    expect(controller.loadError?.kind, MedicationFailureKind.network);
    expect(controller.medications, before);
    expect(controller.isLoading, isFalse);

    repo.failFetch = null;
    await controller.load();
    expect(controller.loadError, isNull);
  });

  test('thao tác thành công tải lại danh sách từ repository', () async {
    final repo = FlakyRepository();
    final controller = MedicationController(repo);
    await controller.load();
    final fetchesBefore = repo.fetches;
    final id = controller.medications.firstWhere((m) => m.isActive).id;

    final stopped = await controller.setStopped(id, true);

    expect(stopped.isActive, isFalse);
    expect(repo.fetches, fetchesBefore + 1);
    expect(controller.getMedicationById(id)?.isActive, isFalse);
  });

  test('thao tác lỗi ném MedicationFailure, danh sách không đổi, không tải lại', () async {
    final repo = FlakyRepository();
    final controller = MedicationController(repo);
    await controller.load();
    final before = controller.medications;
    final fetchesBefore = repo.fetches;
    repo.failWrite = const MedicationFailure(MedicationFailureKind.forbidden);

    await expectLater(
      controller.delete(before.first.id),
      throwsA(isA<MedicationFailure>()),
    );
    expect(controller.medications, before);
    expect(repo.fetches, fetchesBefore);
  });

  test('add cùng clientUuid hai lần chỉ có một thuốc (AC9)', () async {
    final controller = MedicationController(InMemoryMedicationRepository(seed: []));
    final draft = sampleMedications.first.copyWith(id: '');

    final first = await controller.add(draft, clientUuid: 'u-1');
    final second = await controller.add(draft, clientUuid: 'u-1');

    expect(second.id, first.id);
    expect(controller.medications, hasLength(1));
  });

  test('clear bỏ dữ liệu và lỗi (đăng xuất)', () async {
    final repo = FlakyRepository();
    final controller = MedicationController(repo);
    await controller.load();
    repo.failFetch = network;
    await controller.load();

    controller.clear();

    expect(controller.medications, isEmpty);
    expect(controller.loadError, isNull);
  });
}
