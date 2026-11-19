import 'package:drugtime_mobile/core/api/api_client.dart';
import 'package:drugtime_mobile/core/api/api_exception.dart';
import 'package:drugtime_mobile/core/storage/local_db/local_medication_store.dart';
import 'package:drugtime_mobile/core/storage/local_db/local_models.dart';
import 'package:drugtime_mobile/features/patient_dose_reminders/application/caregiver_reminder_launcher.dart';
import 'package:drugtime_mobile/features/patient_dose_reminders/data/patient_dose_reminder_repository.dart';
import 'package:flutter_test/flutter_test.dart';

final scheduledAt = DateTime.utc(2026, 11, 18, 23, 30);

class FakeReminderRepo extends PatientDoseReminderRepository {
  FakeReminderRepo(
      {this.detailError, this.markError, Map<String, dynamic>? detail})
      : _detail = detail ??
            {
              'id': 7,
              'patient_id': 'me',
              'schedule_id': 1,
              'scheduled_at': scheduledAt.toIso8601String(),
              'medication_name': 'Losartan',
              'sender_name': 'Con Nam',
            },
        super(ApiClient(baseUrl: Uri.parse('https://test.invalid')));

  final Object? detailError, markError;
  final Map<String, dynamic> _detail;
  final marked = <int>[];

  @override
  Future<Map<String, dynamic>> detail(int id) async {
    if (detailError case final e?) throw e;
    return _detail;
  }

  @override
  Future<void> markRead(int id) async {
    marked.add(id);
    if (markError case final e?) throw e;
  }
}

class FakeStore implements LocalMedicationStore {
  FakeStore({this.schedule, this.recorded = false, this.failure});
  final LocalMedicationSchedule? schedule;
  final bool recorded;
  final Exception? failure;

  @override
  Future<LocalMedicationSchedule?> getScheduleById(int scheduleId) async {
    if (failure case final e?) throw e;
    return schedule?.id == scheduleId ? schedule : null;
  }

  @override
  Future<bool> hasDoseLog(
          {required int medicationScheduleId,
          required DateTime scheduledAt}) async =>
      recorded;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final losartan = LocalMedicationSchedule(
  id: 1,
  patientUserId: 'me',
  userMedicationId: 10,
  medicationId: 100,
  medicationName: 'Losartan',
  strengthText: '50mg',
  dosageForm: 'Trước ăn sáng',
  quantityPerDose: '1',
  dosesPerDay: 1,
  intakeTime: '06:30',
  daysOfWeek: const [1, 2, 3, 4, 5, 6, 7],
  reminderEnabled: true,
  effectiveFrom: DateTime.utc(2026, 1),
  serverSyncedAt: DateTime.utc(2026, 11, 18),
);

void main() {
  test(
      'liều chưa ghi nhận + có lịch trên máy → màn nhắc 1 thuốc, đánh dấu đã đọc (AC10)',
      () async {
    final repo = FakeReminderRepo();
    final launch = await CaregiverReminderLauncher(
            repository: repo, store: FakeStore(schedule: losartan))
        .prepare(7);
    expect(launch, isA<OpenDoseReminder>());
    final open = launch as OpenDoseReminder;
    expect(open.sender, 'Con Nam');
    expect(open.group.items, hasLength(1));
    final item = open.group.items.single;
    expect(item.medicationScheduleId, 1);
    expect(item.scheduledAt, scheduledAt);
    expect(item.scheduledAt.isUtc, isTrue);
    expect(item.dosageText, '1 viên · 50mg');
    expect(repo.marked, [7]);
  });

  test(
      'liều đã ghi nhận → hộp thư (hiện "Bạn đã uống lúc"), không mở màn xác nhận (AC12)',
      () async {
    final launch = await CaregiverReminderLauncher(
            repository: FakeReminderRepo(),
            store: FakeStore(schedule: losartan, recorded: true))
        .prepare(7);
    expect(launch, isA<OpenReceivedReminder>());
    expect((launch as OpenReceivedReminder).reason, 'already_recorded');
  });

  test('chưa có lịch trên máy → hộp thư', () async {
    final launch = await CaregiverReminderLauncher(
            repository: FakeReminderRepo(), store: FakeStore())
        .prepare(7);
    expect((launch as OpenReceivedReminder).reason, 'no_local_schedule');
    final noStore = await CaregiverReminderLauncher(
            repository: FakeReminderRepo(), store: null)
        .prepare(7);
    expect((noStore as OpenReceivedReminder).reason, 'no_store');
  });

  test(
      'không đọc được lời nhắc (403/404/dữ liệu lạ) → hộp thư, không đánh dấu đọc',
      () async {
    for (final error in [
      const ApiException('denied', statusCode: 403),
      const ApiException('gone', statusCode: 404),
      const FormatException('bad'),
    ]) {
      final repo = FakeReminderRepo(detailError: error);
      final launch = await CaregiverReminderLauncher(
              repository: repo, store: FakeStore(schedule: losartan))
          .prepare(7);
      expect(launch, isA<OpenReceivedReminder>(), reason: '$error');
      expect(repo.marked, isEmpty);
    }
    final odd = FakeReminderRepo(detail: {'schedule_id': 'x'});
    expect(
        await CaregiverReminderLauncher(
                repository: odd, store: FakeStore(schedule: losartan))
            .prepare(7),
        isA<OpenReceivedReminder>());
  });

  test(
      'đánh dấu đọc lỗi mạng không chặn việc mở màn nhắc; tên trống → "Người thân"',
      () async {
    final repo = FakeReminderRepo(
        markError: const ApiException('offline', isTransient: true),
        detail: {
          'schedule_id': 1,
          'scheduled_at': scheduledAt.toIso8601String(),
          'sender_name': '  ',
        });
    final launch = await CaregiverReminderLauncher(
            repository: repo, store: FakeStore(schedule: losartan))
        .prepare(7);
    expect((launch as OpenDoseReminder).sender, 'Người thân');
    expect(repo.marked, [7]);
  });

  test('payload sai kiểu (TypeError) → hộp thư, không văng lỗi (review M1)',
      () async {
    final repo = FakeReminderRepo(detailError: TypeError());
    final launch = await CaregiverReminderLauncher(
            repository: repo, store: FakeStore(schedule: losartan))
        .prepare(7);
    expect((launch as OpenReceivedReminder).reason, 'detail_invalid');
    expect(repo.marked, isEmpty);
    final oddSender = FakeReminderRepo(detail: {
      'schedule_id': 1,
      'scheduled_at': scheduledAt.toIso8601String(),
      'sender_name': 42,
    });
    expect(
        (await CaregiverReminderLauncher(
                    repository: oddSender, store: FakeStore(schedule: losartan))
                .prepare(7) as OpenDoseReminder)
            .sender,
        'Người thân');
  });

  test('DB cục bộ lỗi → hộp thư, không đoán trạng thái liều (review M1)',
      () async {
    final launch = await CaregiverReminderLauncher(
            repository: FakeReminderRepo(),
            store: FakeStore(
                schedule: losartan, failure: Exception('database is locked')))
        .prepare(7);
    expect((launch as OpenReceivedReminder).reason, 'local_store_failed');
  });
}
