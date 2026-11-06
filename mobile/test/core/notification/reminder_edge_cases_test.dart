import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/core/contracts/dose_outbox.dart';
import 'package:drugtime_mobile/core/notification/reminder_scheduler.dart';
import 'package:drugtime_mobile/core/storage/local_db/local_models.dart';
import 'package:drugtime_mobile/features/medication/domain/entities/medication.dart';
import 'package:drugtime_mobile/features/medication/domain/repositories/medication_repository.dart';
import 'package:drugtime_mobile/features/medication/presentation/screens/edit_medication_screen.dart';
import 'package:drugtime_mobile/features/medication/presentation/state/edit_medication_controller.dart';
import 'package:drugtime_mobile/features/medication/presentation/state/medication_controller.dart';
import 'package:drugtime_mobile/features/reminder/domain/entities/dose_reminder.dart';
import 'package:drugtime_mobile/features/reminder/presentation/state/dose_reminder_controller.dart';

class _MockDoseOutbox implements DoseOutbox {
  final List<LocalDoseLog> enqueued = [];

  @override
  Future<LocalDoseLog> enqueue({
    required int medicationScheduleId,
    required DateTime scheduledAt,
    required DateTime takenAt,
  }) async {
    final log = LocalDoseLog(
      clientUuid: 'test-uuid-${enqueued.length + 1}',
      medicationScheduleId: medicationScheduleId,
      scheduledAt: scheduledAt,
      takenAt: takenAt,
      status: DoseLogStatus.taken,
      syncState: DoseLogSyncState.pendingUpload,
      localUpdatedAt: takenAt,
    );
    enqueued.add(log);
    return log;
  }

  @override
  Future<List<LocalDoseLog>> getPendingLogs() async => enqueued;

  @override
  Future<void> markSynced({
    required String clientUuid,
    required int? serverId,
    required DateTime syncedAt,
  }) async {}

  @override
  Future<void> markFailed({
    required String clientUuid,
    required String errorMessage,
  }) async {}

  @override
  Stream<DoseLogSyncState?> watchStatus(String clientUuid) =>
      const Stream.empty();

  @override
  Future<void> dispose() async {}
}

class _MockReminderScheduler implements ReminderScheduler {
  final List<Map<String, dynamic>> cancelledOccurrences = [];
  final List<int> cancelledSchedules = [];
  final List<Map<String, dynamic>> snoozedCalls = [];

  @override
  Future<void> cancelOccurrence({
    int? scheduleId,
    int? medicationScheduleId,
    required DateTime scheduledAt,
  }) async {
    cancelledOccurrences.add({
      'scheduleId': scheduleId ?? medicationScheduleId,
      'scheduledAt': scheduledAt,
    });
  }

  @override
  Future<void> cancelAllForSchedule(int scheduleId) async {
    cancelledSchedules.add(scheduleId);
  }

  @override
  Future<void> snooze({
    required int medicationScheduleId,
    required DateTime scheduledAt,
    required DateTime remindAt,
  }) async {
    snoozedCalls.add({
      'medicationScheduleId': medicationScheduleId,
      'scheduledAt': scheduledAt,
      'remindAt': remindAt,
    });
  }
}

class _FakeMedicationRepository implements MedicationRepository {
  Medication? lastUpdated;

  @override
  Future<List<Medication>> fetchAll() async => const [];

  @override
  Future<Medication> add(Medication draft, {required String clientUuid}) async =>
      draft;

  @override
  Future<Medication> update(Medication before, Medication after) async {
    lastUpdated = after;
    return after;
  }

  @override
  Future<Medication> setStopped(String id, bool stopped) async =>
      throw UnimplementedError();

  @override
  Future<void> delete(String id) async {}

  @override
  Future<List<DrugCatalogItem>> searchCatalog(String query) async => const [];
}

void main() {
  group('Task 2.08: Reminder Edge Cases — Hủy thông báo', () {
    late _MockDoseOutbox outbox;
    late _MockReminderScheduler scheduler;

    setUp(() {
      outbox = _MockDoseOutbox();
      scheduler = _MockReminderScheduler();
    });

    group('Subtask 65: Uống thuốc sớm trước giờ cữ', () {
      final scheduledAt = DateTime.utc(2026, 10, 29, 12, 0, 0);
      final item = DoseReminderItem(
        medicationScheduleId: 101,
        scheduledAt: scheduledAt,
        medicationName: 'Amlodipine',
        dosageText: '1 viên',
        instruction: 'Uống sau ăn',
      );
      final group = DoseReminderGroup([item]);

      test('Khi uống sớm (trước giờ cữ 30 phút), gọi cancelOccurrence', () async {
        // Clock lúc 11:30 UTC (< 12:00 UTC)
        final earlyTime = DateTime.utc(2026, 10, 29, 11, 30, 0);
        final controller = DoseReminderController(
          group: group,
          outbox: outbox,
          scheduler: scheduler,
          clock: () => earlyTime,
        );

        final result = await controller.confirmItem(item);

        expect(result, isTrue);
        expect(outbox.enqueued.length, 1);
        expect(scheduler.cancelledOccurrences.length, 1);
        expect(scheduler.cancelledOccurrences.first['scheduleId'], 101);
        expect(scheduler.cancelledOccurrences.first['scheduledAt'], scheduledAt);
      });

      test('Khi xác nhận qua confirmDose() sớm, cũng gọi cancelOccurrence', () async {
        final earlyTime = DateTime.utc(2026, 10, 29, 11, 45, 0);
        final controller = DoseReminderController(
          group: group,
          outbox: outbox,
          scheduler: scheduler,
          clock: () => earlyTime,
        );

        final result = await controller.confirmDose(item);

        expect(result, isTrue);
        expect(scheduler.cancelledOccurrences.length, 1);
        expect(scheduler.cancelledOccurrences.first['scheduleId'], 101);
      });

      test('Khi uống đúng giờ hoặc sau giờ cữ, KHÔNG gọi cancelOccurrence', () async {
        // Clock lúc 12:05 UTC (> 12:00 UTC)
        final lateTime = DateTime.utc(2026, 10, 29, 12, 5, 0);
        final controller = DoseReminderController(
          group: group,
          outbox: outbox,
          scheduler: scheduler,
          clock: () => lateTime,
        );

        final result = await controller.confirmItem(item);

        expect(result, isTrue);
        expect(outbox.enqueued.length, 1);
        expect(scheduler.cancelledOccurrences, isEmpty);
      });
    });

    group('Subtask 67: Tắt nhắc nhở (reminder_enabled = false)', () {
      final sampleMed = Medication(
        id: '202',
        catalogId: '1',
        name: 'Metformin',
        activeIngredient: 'Metformin HCl',
        strength: '500mg',
        unit: 'viên',
        dosePerIntake: 1,
        frequency: DoseFrequency.twice,
        timing: IntakeTiming.afterMeal,
        reminderEnabled: true,
      );

      test('EditMedicationController.save() với reminder_enabled == false gọi cancelAllForSchedule', () async {
        final repo = _FakeMedicationRepository();
        final editController = EditMedicationController(
          medication: sampleMed,
          medicationRepository: repo,
          reminderScheduler: scheduler,
        );

        expect(editController.reminderEnabled, isTrue);

        final saved = await editController.save(reminderEnabled: false);

        expect(saved.reminderEnabled, isFalse);
        expect(repo.lastUpdated?.reminderEnabled, isFalse);
        expect(scheduler.cancelledSchedules, [202]);
      });

      test('EditMedicationController.save() giữ reminder_enabled == true KHÔNG hủy thông báo', () async {
        final repo = _FakeMedicationRepository();
        final editController = EditMedicationController(
          medication: sampleMed,
          medicationRepository: repo,
          reminderScheduler: scheduler,
        );

        final saved = await editController.save(reminderEnabled: true);

        expect(saved.reminderEnabled, isTrue);
        expect(scheduler.cancelledSchedules, isEmpty);
      });

      testWidgets('EditMedicationScreen: Gạt tắt nhắc nhở và Lưu gọi cancelAllForSchedule', (tester) async {
        tester.view.physicalSize = const Size(400, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final repo = _FakeMedicationRepository();
        final medController = MedicationController(repo);

        await tester.pumpWidget(
          MaterialApp(
            home: MedicationScope(
              controller: medController,
              child: Scaffold(
                body: EditMedicationScreen(
                  medication: sampleMed,
                  reminderScheduler: scheduler,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Kiểm tra SwitchListTile có mặt và bật
        final switchFinder = find.byKey(const Key('edit_medication_reminder_switch'));
        expect(switchFinder, findsOneWidget);

        // Gạt tắt Switch
        await tester.tap(switchFinder);
        await tester.pumpAndSettle();

        // Bấm nút Lưu
        final saveBtn = find.widgetWithText(FilledButton, 'Lưu');
        expect(saveBtn, findsOneWidget);
        await tester.tap(saveBtn);
        await tester.pumpAndSettle();

        // Xác minh scheduler.cancelAllForSchedule đã được gọi cho scheduleId 202
        expect(scheduler.cancelledSchedules, [202]);
      });
    });
  });
}
