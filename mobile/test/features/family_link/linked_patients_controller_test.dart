import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/core/storage/local_db/local_medication_store.dart';
import 'package:drugtime_mobile/features/family/domain/entities/family_alert.dart';
import 'package:drugtime_mobile/features/family/domain/repositories/family_alert_repository.dart';
import 'package:drugtime_mobile/features/family/presentation/state/family_alert_controller.dart';
import 'package:drugtime_mobile/features/family_link/presentation/state/linked_patients_controller.dart';

class _FakeLocalMedicationStore implements LocalMedicationStore, PatientDataClearable {
  final List<String> clearedPatients = [];

  @override
  Future<void> clearPatient(String patientId) async {
    clearedPatients.add(patientId);
  }

  Future<void> clearPatientData(String patientId) => clearPatient(patientId);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAlertRepository implements FamilyAlertRepository {
  Future<FamilyAlertPage> Function({int limit, int offset})? onList;
  Future<FamilyAlert> Function(int id)? onDetail;

  @override
  Future<FamilyAlertPage> list({int offset = 0, int limit = 20}) async =>
      onList != null ? onList!(limit: limit, offset: offset) : const FamilyAlertPage([], 0, 0);

  @override
  Future<FamilyAlert> detail(int id) async =>
      onDetail != null ? onDetail!(id) : throw UnimplementedError();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, dynamic> _testAlertJson({required int id, required String patientId}) => {
      'id': id,
      'type': 'canh_bao_bo_lo_lieu_nguoi_than',
      'title': 'Cảnh báo',
      'content': 'Nội dung',
      'is_read': false,
      'about_patient_user_id': patientId,
      'about_patient_name': 'Bệnh nhân',
      'medication_name': 'Thuốc A',
      'scheduled_at': '2026-10-23T08:00:00Z',
      'created_at': '2026-10-23T08:00:00Z',
    };

void main() {
  const patientA = '11111111-1111-1111-1111-111111111111';
  const patientB = '22222222-2222-2222-2222-222222222222';
  const patientC = '33333333-3333-3333-3333-333333333333';

  group('FamilyAlertController.removePatient (P4 / AC8)', () {
    test('Loại bỏ alert của patient bị thu hồi, reset detail nếu đang mở, giữ nguyên alert của patient khác', () async {
      final alertRepo = _FakeAlertRepository();
      final c = FamilyAlertController(alertRepo)..setSession('session-1', ready: true);

      alertRepo.onList = ({int limit = 20, int offset = 0}) async => FamilyAlertPage([
        FamilyAlert.fromJson(_testAlertJson(id: 1, patientId: patientA)),
        FamilyAlert.fromJson(_testAlertJson(id: 2, patientId: patientB)),
        FamilyAlert.fromJson(_testAlertJson(id: 3, patientId: patientA)),
      ], 3, 3);
      await c.load();
      expect(c.items.length, 3);

      alertRepo.onDetail = (id) async => FamilyAlert.fromJson(_testAlertJson(id: 1, patientId: patientA));
      await c.open(1);
      expect(c.detail?.patientId, patientA);

      // Thu hồi quyền của patientA
      c.removePatient(patientA);

      expect(c.items.length, 1);
      expect(c.items.single.patientId, patientB);
      expect(c.detail, isNull);
      expect(c.openId, isNull);
      c.dispose();
    });
  });

  group('LinkedPatientsController (P5 / AC6, AC7, AC8, AC9)', () {
    test('Xử lý 403 thu hồi quyền: xóa khỏi state, dọn SQLite cache và alerts (AC6, AC8)', () async {
      final store = _FakeLocalMedicationStore();
      final alertRepo = _FakeAlertRepository();
      final alertController = FamilyAlertController(alertRepo)..setSession('session-1', ready: true);

      // Nạp cảnh báo ban đầu cho cả 2 bệnh nhân
      alertRepo.onList = ({int limit = 20, int offset = 0}) async => FamilyAlertPage([
        FamilyAlert.fromJson(_testAlertJson(id: 1, patientId: patientA)),
        FamilyAlert.fromJson(_testAlertJson(id: 2, patientId: patientB)),
        FamilyAlert.fromJson(_testAlertJson(id: 3, patientId: patientA)),
      ], 3, 3);
      await alertController.load();

      expect(alertController.items.length, 3);

      final controller = LinkedPatientsController(
        localStore: store,
        alertController: alertController,
        initialPatients: const [
          LinkedPatient(id: patientA, name: 'Bác An'),
          LinkedPatient(id: patientB, name: 'Cô Ba'),
        ],
      );

      var notified = 0;
      controller.addListener(() => notified++);

      expect(controller.hasPatient(patientA), isTrue);
      expect(controller.hasPatient(patientB), isTrue);
      expect(controller.patients.length, 2);

      // Giả lập nhận 403 thu hồi quyền cho patientA
      await controller.handleRevocation(patientA);

      // State đã loại bỏ patientA, giữ nguyên patientB (AC6, AC8)
      expect(controller.hasPatient(patientA), isFalse);
      expect(controller.hasPatient(patientB), isTrue);
      expect(controller.patients.length, 1);
      expect(controller.patients.single.id, patientB);
      expect(notified, 1);

      // Cache SQLite của patientA đã được gọi xóa (AC6)
      expect(store.clearedPatients, contains(patientA));
      expect(store.clearedPatients, isNot(contains(patientB)));

      // Alerts của patientA đã được dọn sạch khỏi FamilyAlertController (AC6, AC8)
      expect(alertController.items.any((a) => a.patientId == patientA), isFalse);
      expect(alertController.items.single.patientId, patientB);

      controller.dispose();
      alertController.dispose();
    });

    test('Đồng bộ danh sách mới: xóa các bệnh nhân không còn trong danh sách (AC7, AC8)', () async {
      final store = _FakeLocalMedicationStore();
      final controller = LinkedPatientsController(
        localStore: store,
        initialPatients: const [
          LinkedPatient(id: patientA, name: 'Bác An'),
          LinkedPatient(id: patientB, name: 'Cô Ba'),
          LinkedPatient(id: patientC, name: 'Chú Tư'),
        ],
      );

      // Server trả về danh sách mới chỉ còn patientB và patientC (patientA bị gỡ)
      await controller.syncPatients(const [
        LinkedPatient(id: patientB, name: 'Cô Ba'),
        LinkedPatient(id: patientC, name: 'Chú Tư'),
      ]);

      expect(controller.hasPatient(patientA), isFalse);
      expect(controller.hasPatient(patientB), isTrue);
      expect(controller.hasPatient(patientC), isTrue);
      expect(store.clearedPatients, [patientA]);

      // Đồng bộ bằng syncPatientIds: chỉ còn patientC
      await controller.syncPatientIds([patientC]);
      expect(controller.hasPatient(patientB), isFalse);
      expect(controller.hasPatient(patientC), isTrue);
      expect(store.clearedPatients, [patientA, patientB]);

      controller.dispose();
    });

    test('An toàn khi gọi nhiều request thu hồi đồng thời và lặp lại (AC9)', () async {
      final store = _FakeLocalMedicationStore();
      final controller = LinkedPatientsController(
        localStore: store,
        initialPatients: const [
          LinkedPatient(id: patientA, name: 'Bác An'),
        ],
      );

      // Chạy 5 lời gọi đồng thời cho cùng patientA
      await Future.wait([
        controller.handleRevocation(patientA),
        controller.handleRevocation(patientA),
        controller.handleRevocation(patientA),
        controller.handleRevocation(patientA),
        controller.handleRevocation(patientA),
      ]);

      expect(controller.hasPatient(patientA), isFalse);
      expect(controller.patients, isEmpty);

      // Gọi lại lần nữa trên patient đã bị gỡ -> an toàn không lỗi
      await controller.handleRevocation(patientA);
      expect(controller.patients, isEmpty);

      controller.dispose();
    });

    test('Hoạt động an toàn khi không truyền localStore hoặc alertController', () async {
      final controller = LinkedPatientsController(
        initialPatients: const [
          LinkedPatient(id: patientA, name: 'Bác An'),
        ],
      );

      await expectLater(
        controller.handleRevocation(patientA),
        completes,
      );
      expect(controller.patients, isEmpty);
      controller.dispose();
    });
  });
}
