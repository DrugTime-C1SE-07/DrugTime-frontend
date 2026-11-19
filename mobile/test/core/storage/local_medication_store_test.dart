import 'package:drugtime_mobile/core/storage/local_db/local_db.dart';
import 'package:drugtime_mobile/core/storage/local_db/local_medication_store.dart';
import 'package:drugtime_mobile/core/storage/local_db/local_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _TestLocalDb implements LocalDb {
  _TestLocalDb(this._db);

  final Database _db;

  @override
  Future<Database> get database async => _db;

  @override
  Future<void> close() async => _db.close();
}

LocalMedicationSchedule _testSchedule({
  required int id,
  required String patientId,
  required String medicationName,
}) =>
    LocalMedicationSchedule(
      id: id,
      patientUserId: patientId,
      userMedicationId: 100 + id,
      medicationId: 200 + id,
      medicationName: medicationName,
      strengthText: '500mg',
      dosageForm: 'tablet',
      quantityPerDose: '1',
      dosesPerDay: 1,
      intakeTime: '08:00',
      daysOfWeek: const [1, 2, 3, 4, 5, 6, 7],
      reminderEnabled: true,
      effectiveFrom: DateTime.utc(2026, 10, 1),
      endedAt: null,
      serverSyncedAt: DateTime.utc(2026, 10, 23),
    );

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('SqliteLocalMedicationStore.clearPatientData', () {
    late Database db;
    late SqliteLocalMedicationStore store;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      await LocalDb.createSchema(db, 1);
      store = SqliteLocalMedicationStore(_TestLocalDb(db));
    });

    tearDown(() async {
      await db.close();
    });

    test('xóa sạch lịch uống của patientId được chỉ định, giữ nguyên patientId khác (AC7)', () async {
      // Setup: thêm 2 schedule cho patient-A, 1 schedule cho patient-B
      await store.replaceSchedules(
        patientId: 'patient-A',
        schedules: [
          _testSchedule(id: 1, patientId: 'patient-A', medicationName: 'Paracetamol'),
          _testSchedule(id: 2, patientId: 'patient-A', medicationName: 'Amoxicillin'),
        ],
      );
      await store.replaceSchedules(
        patientId: 'patient-B',
        schedules: [
          _testSchedule(id: 3, patientId: 'patient-B', medicationName: 'Vitamin C'),
        ],
      );

      expect((await store.getActiveSchedules(patientId: 'patient-A')).length, 2);
      expect((await store.getActiveSchedules(patientId: 'patient-B')).length, 1);

      // Thao tác: xóa dữ liệu của patient-A khi bị gỡ liên kết (QD-29)
      await store.clearPatientData('patient-A');

      // Kiểm tra: patient-A không còn dữ liệu nào trong DB
      final patientASchedules = await store.getActiveSchedules(patientId: 'patient-A');
      expect(patientASchedules, isEmpty);

      // Kiểm tra: patient-B vẫn còn nguyên vẹn dữ liệu
      final patientBSchedules = await store.getActiveSchedules(patientId: 'patient-B');
      expect(patientBSchedules.length, 1);
      expect(patientBSchedules.first.medicationName, 'Vitamin C');
    });

    test('thao tác có tính idempotent, gọi nhiều lần trên patient đã xóa không lỗi', () async {
      await store.replaceSchedules(
        patientId: 'patient-A',
        schedules: [
          _testSchedule(id: 1, patientId: 'patient-A', medicationName: 'Paracetamol'),
        ],
      );

      await store.clearPatientData('patient-A');
      expect(await store.getActiveSchedules(patientId: 'patient-A'), isEmpty);

      // Gọi lần 2: an toàn, không ném exception
      await store.clearPatientData('patient-A');
      expect(await store.getActiveSchedules(patientId: 'patient-A'), isEmpty);
    });
  });
}
