import 'package:drugtime_mobile/app/app.dart';
import 'package:drugtime_mobile/app/app_shell.dart';
import 'package:drugtime_mobile/app/router.dart';
import 'package:drugtime_mobile/core/notification/notification_preferences.dart';
import 'package:drugtime_mobile/core/notification/reminder_scheduler.dart';
import 'package:drugtime_mobile/features/auth/data/repositories/in_memory_auth_repository.dart';
import 'package:drugtime_mobile/features/auth/domain/entities/auth_session.dart';
import 'package:drugtime_mobile/features/auth/presentation/state/auth_controller.dart';
import 'package:drugtime_mobile/features/interaction_check/data/repositories/in_memory_interaction_check_repository.dart';
import 'package:drugtime_mobile/features/interaction_check/domain/entities/interaction_check_result.dart';
import 'package:drugtime_mobile/features/medication/data/models/medication_api_mapper.dart';
import 'package:drugtime_mobile/features/medication/data/repositories/in_memory_medication_repository.dart';
import 'package:drugtime_mobile/features/medication/domain/entities/medication_failure.dart';
import 'package:drugtime_mobile/features/medication/presentation/screens/edit_medication_screen.dart';
import 'package:drugtime_mobile/features/medication/presentation/screens/medication_detail_screen.dart';
import 'package:drugtime_mobile/features/medication/presentation/screens/my_medications_screen.dart';
import 'package:drugtime_mobile/features/medication/presentation/state/medication_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'medication_screens_test.dart' show RecordingRepository;

class _TestReminderScheduler implements ReminderScheduler {
  final cancelledSchedules = <int>[];
  @override
  Future<void> cancelAllForSchedule(int scheduleId) async =>
      cancelledSchedules.add(scheduleId);
  @override
  Future<void> cancelOccurrence({
    int? scheduleId,
    int? medicationScheduleId,
    required DateTime scheduledAt,
  }) async {}
  @override
  Future<void> snooze({
    required int medicationScheduleId,
    required DateTime scheduledAt,
    required DateTime remindAt,
  }) async {}
}

class _PrefsStore implements ReminderPreferencesStore {
  _PrefsStore(this.value);
  ReminderPreferences value;
  @override
  Future<ReminderPreferences> read() async => value;
  @override
  Future<void> write(ReminderPreferences preferences) async => value = preferences;
  @override
  Future<void> clear() async => value = const ReminderPreferences();
}

class _CountingInteractionRepo extends InMemoryInteractionCheckRepository {
  int checks = 0;
  @override
  Future<InteractionCheckResult> checkPatientInteractions({
    required String patientId,
    int? candidateMedicationId,
    double? candidateDoseAmount,
    String? candidateDoseUnit,
    List<int>? medicationIds,
  }) {
    checks++;
    return super.checkPatientInteractions(
      patientId: patientId,
      candidateMedicationId: candidateMedicationId,
      candidateDoseAmount: candidateDoseAmount,
      candidateDoseUnit: candidateDoseUnit,
      medicationIds: medicationIds,
    );
  }
}


/// Người dùng đã đăng nhập và có hồ sơ: app mở thẳng Trang chủ như trước khi có màn đăng nhập.
AuthController signedInAuth() => AuthController(
      InMemoryAuthRepository(
        simulatedDelay: Duration.zero,
        initialSession: AuthSession(
          userId: 'test-user',
          accessToken: 'test-token',
          expiresAt: DateTime.now().add(const Duration(days: 10)),
          profileComplete: true,
        ),
      ),
    );

Future<void> pumpApp(WidgetTester tester, {InMemoryMedicationRepository? repository}) async {
  tester.view.physicalSize = const Size(375, 812);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(DrugTimeApp(
    initialTab: AppTab.medications,
    authController: signedInAuth(),
    medicationRepository: repository ?? InMemoryMedicationRepository(),
  ));
  await tester.pumpAndSettle();
}

Future<void> openDetail(WidgetTester tester, [String name = 'Losartan 50mg']) async {
  final finder = find.text(name);
  await tester.scrollUntilVisible(finder, 200, scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> tapVisibleIn(WidgetTester tester, Finder finder, Type screenType) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.descendant(
      of: find.byType(screenType),
      matching: find.byType(Scrollable),
    ).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  group('S06a · Xem chi tiết thuốc', () {
    testWidgets('chạm vào thẻ thuốc mở màn hình chi tiết', (tester) async {
      await pumpApp(tester);
      await openDetail(tester, 'Losartan 50mg');

      // Kiểm tra đang ở màn hình chi tiết
      expect(find.byType(MedicationDetailScreen), findsOneWidget);
      expect(find.text('Chi tiết thuốc'), findsOneWidget);
      expect(find.text('Losartan kali · Viên nén bao phim'), findsOneWidget);
      expect(find.text('Đang dùng'), findsOneWidget);
      expect(find.text('1 viên'), findsWidgets);
      expect(find.text('1 lần/ngày'), findsOneWidget);
      expect(find.text('Không liên quan bữa ăn'), findsOneWidget);
      expect(find.text('Còn 3 viên'), findsOneWidget);
      expect(find.text('Sắp hết thuốc'), findsOneWidget);
    });

    testWidgets('tạm ngừng thuốc và chuyển trạng thái', (tester) async {
      await pumpApp(tester);
      await openDetail(tester, 'Losartan 50mg');

      await tester.tap(find.text('Tạm ngừng thuốc này'));
      await tester.pumpAndSettle();

      // Hộp thoại xác nhận
      expect(find.text('Ngừng dùng thuốc?'), findsOneWidget);
      await tester.tap(find.text('Xác nhận ngừng'));
      await tester.pumpAndSettle();

      expect(find.text('Đã ngừng'), findsOneWidget);
      expect(find.text('Tiếp tục dùng thuốc này'), findsOneWidget);
    });
  });

  group('S06b · Sửa chi tiết thuốc (Figma Prototype)', () {
    testWidgets('hiển thị đầy đủ giao diện prototype', (tester) async {
      await pumpApp(tester);
      await openDetail(tester, 'Losartan 50mg');

      // Bấm nút Sửa thông tin thuốc
      await tester.tap(find.widgetWithText(FilledButton, 'Sửa thông tin thuốc'));
      await tester.pumpAndSettle();

      // Kiểm tra màn hình Sửa thông tin thuốc
      expect(find.byType(EditMedicationScreen), findsOneWidget);
      expect(find.text('Sửa thông tin thuốc'), findsOneWidget);
      expect(find.text('Losartan 50mg'), findsOneWidget);
      expect(find.text('Losartan kali · Viên nén bao phim'), findsOneWidget);

      // Hai cột: Số lượng/lần & Tần suất
      expect(find.text('Số lượng/lần'), findsOneWidget);
      expect(find.text('1 viên'), findsOneWidget);
      expect(find.text('Tần suất'), findsOneWidget);
      expect(find.text('1 lần/ngày'), findsOneWidget);

      // Giờ uống
      expect(find.text('Giờ uống'), findsOneWidget);
      expect(find.text('07:00'), findsOneWidget);
      expect(find.text('Thêm giờ'), findsOneWidget);

      // Uống thế nào: 3 nút Trước ăn, Sau ăn, Không liên quan
      await tester.scrollUntilVisible(
        find.text('Uống thế nào'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Uống thế nào'), findsOneWidget);
      expect(find.text('Trước ăn'), findsOneWidget);
      expect(find.text('Sau ăn'), findsOneWidget);
      expect(find.text('Không liên quan'), findsOneWidget);

      // 2 nút đáy: Lưu & Xoá thuốc
      expect(find.text('Lưu'), findsOneWidget);
      expect(find.text('Xoá thuốc'), findsOneWidget);
    });

    testWidgets('chỉnh sửa cách uống và lưu thành công', (tester) async {
      await pumpApp(tester);
      await openDetail(tester, 'Losartan 50mg');

      await tester.tap(find.widgetWithText(FilledButton, 'Sửa thông tin thuốc'));
      await tester.pumpAndSettle();

      // Đổi sang "Trước ăn"
      await tapVisibleIn(tester, find.text('Trước ăn'), EditMedicationScreen);

      // Bấm Lưu
      await tester.tap(find.text('Lưu'));
      await tester.pumpAndSettle();

      // Quay lại màn hình chi tiết thuốc và thấy "Trước ăn"
      expect(find.byType(MedicationDetailScreen), findsOneWidget);
      expect(find.text('Trước ăn'), findsOneWidget);
    });

    testWidgets('xoá thuốc khỏi danh sách có xác nhận', (tester) async {
      await pumpApp(tester);
      await openDetail(tester, 'Losartan 50mg');

      await tester.tap(find.widgetWithText(FilledButton, 'Sửa thông tin thuốc'));
      await tester.pumpAndSettle();

      // Bấm Xoá thuốc
      await tester.tap(find.text('Xoá thuốc'));
      await tester.pumpAndSettle();

      expect(find.text('Xoá thuốc?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Xoá thuốc'));
      await tester.pumpAndSettle();

      // Thoát về danh sách Thuốc của tôi
      expect(find.byType(MyMedicationsScreen), findsOneWidget);
      expect(find.text('Losartan 50mg'), findsNothing);
    });
  });

  group('Nối API: ngừng, dùng lại, xoá, sửa', () {
    Future<void> openEdit(WidgetTester tester) async {
      await tester.tap(find.widgetWithText(FilledButton, 'Sửa thông tin thuốc'));
      await tester.pumpAndSettle();
    }

    testWidgets('Ngừng rồi Tiếp tục dùng gọi setStopped(true/false) (AC12, AC14e)', (tester) async {
      final repository = RecordingRepository();
      await pumpApp(tester, repository: repository);
      await openDetail(tester, 'Losartan 50mg');

      await tester.tap(find.text('Tạm ngừng thuốc này'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xác nhận ngừng'));
      await tester.pumpAndSettle();

      expect(repository.stopCalls, [('m2', true)]);
      expect(find.text('Tiếp tục dùng thuốc này'), findsOneWidget);
      expect((await repository.fetchAll()).firstWhere((m) => m.id == 'm2').isActive, isFalse);

      await tester.tap(find.text('Tiếp tục dùng thuốc này'));
      await tester.pumpAndSettle();

      expect(repository.stopCalls.last, ('m2', false));
      expect(find.text('Tạm ngừng thuốc này'), findsOneWidget);
    });

    testWidgets('Xoá: gọi delete; lỗi 403 thì báo và thuốc vẫn còn (AC10, AC14e)', (tester) async {
      final repository = RecordingRepository()
        ..failNextDelete = const MedicationFailure(MedicationFailureKind.forbidden);
      await pumpApp(tester, repository: repository);
      await openDetail(tester, 'Losartan 50mg');
      await openEdit(tester);

      await tester.tap(find.text('Xoá thuốc'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Xoá thuốc'));
      await tester.pumpAndSettle();

      expect(repository.deleteCalls, ['m2']);
      expect(find.text('Bạn không có quyền thực hiện thao tác này.'), findsOneWidget);
      expect(find.byType(EditMedicationScreen), findsOneWidget);
      expect((await repository.fetchAll()).any((m) => m.id == 'm2'), isTrue);
    });

    testWidgets('Sửa liều chỉ gửi quantity_per_dose (AC13)', (tester) async {
      final repository = RecordingRepository();
      await pumpApp(tester, repository: repository);
      await openDetail(tester, 'Losartan 50mg');
      await openEdit(tester);

      await tester.tap(find.text('1 viên'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2 viên'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lưu'));
      await tester.pumpAndSettle();

      final (before, after) = repository.updateCalls.single;
      expect(MedicationApiMapper.patchBody(before, after), {'quantity_per_dose': 2.0});
      expect(find.byType(MedicationDetailScreen), findsOneWidget);
    });

    testWidgets('Thuốc "Khi cần" hiện ô tối đa lần/ngày ở màn sửa (AC14f)', (tester) async {
      final repository = RecordingRepository();
      await pumpApp(tester, repository: repository);
      await openDetail(tester, 'Paracetamol 500mg');
      expect(find.text('Tối đa 3 lần/ngày'), findsOneWidget);
      await openEdit(tester);

      expect(find.text('Tối đa mỗi ngày'), findsOneWidget);
      await tapVisibleIn(tester, find.byTooltip('Tăng số lần tối đa'), EditMedicationScreen);
      await tester.tap(find.text('Lưu'));
      await tester.pumpAndSettle();

      final (before, after) = repository.updateCalls.single;
      expect(MedicationApiMapper.patchBody(before, after), {'max_doses_per_day': 4});
    });
  });

  group('6.06 S06a/S06b Red Tests (AC2, AC3, AC8, AC10, AC18, AC21)', () {
    testWidgets('TC-606-16: Chi tiết thuốc hiện Ngày uống, Nhắc nhở, Dạng & màu hiển thị (AC2)',
        (tester) async {
      await pumpApp(tester);
      await openDetail(tester, 'Losartan 50mg');

      await tester.scrollUntilVisible(find.text('Thông tin chi tiết'), 200);
      await tester.pumpAndSettle();
      expect(find.text('Ngày uống'), findsOneWidget);
      expect(find.text('Hằng ngày'), findsOneWidget);
      expect(find.text('Nhắc nhở'), findsOneWidget);
      expect(find.text('Đang bật'), findsOneWidget);
      expect(find.text('Dạng & màu hiển thị'), findsOneWidget);
    });

    testWidgets('TC-606-17: Thuốc đã ngừng ẩn nút Sửa, hiện hướng dẫn dùng lại và cho Xoá thuốc (AC3)',
        (tester) async {
      final repo = RecordingRepository();
      await pumpApp(tester, repository: repo);
      await openDetail(tester, 'Amoxicillin 500mg');

      expect(find.text('Sửa thông tin thuốc'), findsNothing);
      expect(find.text('Tiếp tục dùng thuốc này'), findsOneWidget);
      expect(find.text('Xoá thuốc'), findsOneWidget);

      await tester.tap(find.text('Xoá thuốc'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Xoá thuốc'));
      await tester.pumpAndSettle();

      expect(repo.deleteCalls, ['m5']);
      expect(find.byType(MyMedicationsScreen), findsOneWidget);
    });

    testWidgets('TC-606-19: tắt Sắp hết thuốc ẩn cảnh báo trên MedicationCard và MedicationDetailScreen (AC18)',
        (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final prefsController = NotificationPreferencesController(
        store: _PrefsStore(ReminderPreferences.fromJson({
          'enabled': true,
          'vibrate': true,
          'repeat': true,
          'low_stock': false,
        })),
      );
      await prefsController.load();

      await tester.pumpWidget(DrugTimeApp(
        initialTab: AppTab.medications,
        authController: signedInAuth(),
        medicationRepository: InMemoryMedicationRepository(),
        notificationPreferencesController: prefsController,
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Sắp hết'), findsNothing);
      await openDetail(tester, 'Losartan 50mg');
      await tester.scrollUntilVisible(find.text('Còn 3 viên'), 200);
      await tester.pumpAndSettle();
      expect(find.text('Còn 3 viên'), findsOneWidget);
      expect(find.text('Sắp hết thuốc'), findsNothing);
    });

    testWidgets('TC-606-20: Sửa thuốc không đổi gì thì bấm Lưu không gọi interaction check hay update (AC10)',
        (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final repo = RecordingRepository();
      final interactions = _CountingInteractionRepo();
      final controller = MedicationController(
        repo,
        interactionCheckRepository: interactions,
      );
      addTearDown(controller.dispose);
      final med = sampleMedications[1];

      await tester.pumpWidget(AuthScope(
        controller: signedInAuth(),
        child: MedicationScope(
          controller: controller,
          child: MaterialApp(home: EditMedicationScreen(medication: med)),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
      await tester.pumpAndSettle();

      expect(interactions.checks, 0);
      expect(repo.updateCalls, isEmpty);
    });

    testWidgets('TC-606-21: Sửa thuốc hỗ trợ liều 0,5 / 9 / 10, đồng bộ giờ theo tần suất, và ẩn nhắc khi Khi cần (AC8)',
        (tester) async {
      await pumpApp(tester);
      await openDetail(tester, 'Losartan 50mg');
      await tester.tap(find.widgetWithText(FilledButton, 'Sửa thông tin thuốc'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('1 viên'));
      await tester.pumpAndSettle();
      expect(find.text('0,5 viên'), findsOneWidget);
      expect(find.text('9 viên'), findsOneWidget);
      expect(find.text('10 viên'), findsOneWidget);
      await tester.tap(find.text('0,5 viên'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('1 lần/ngày'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2 lần/ngày'));
      await tester.pumpAndSettle();
      expect(find.text('08:00'), findsOneWidget);
      expect(find.text('20:00'), findsOneWidget);

      await tester.tap(find.text('2 lần/ngày'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Khi cần'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('edit_medication_reminder_switch')), findsNothing);
    });

    testWidgets('TC-606-28: Detail & Edit giữ chữ >= 14px và không overflow ở 320x640 textScale 2.0 (AC21)',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final controller = MedicationController(InMemoryMedicationRepository());
      addTearDown(controller.dispose);
      await controller.load();

      await tester.pumpWidget(MedicationScope(
        controller: controller,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: MedicationDetailScreen(medication: sampleMedications[1]),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        final size = text.style?.fontSize;
        if (size != null) {
          expect(size, greaterThanOrEqualTo(14), reason: 'Text "${text.data}" has fontSize $size');
        }
      }
    });

    testWidgets('TC-606-18: thuốc Khi cần trên Chi tiết thuốc ẩn giờ nhắc và dòng Nhắc nhở (AC4)',
        (tester) async {
      await pumpApp(tester);
      await openDetail(tester, 'Paracetamol 500mg');
      expect(find.text('Tối đa 3 lần/ngày'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Thông tin chi tiết'), 200);
      await tester.pumpAndSettle();
      expect(find.text('Nhắc nhở'), findsNothing);
      expect(find.text('Ngày uống'), findsNothing);
    });

    testWidgets('TC-606-22: sửa dạng & màu (ẩn Bước 3/3), sửa tồn kho & ngày uống (chặn ngày rỗng/tồn âm) (AC6, AC7)',
        (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final repo = RecordingRepository();
      final interactions = _CountingInteractionRepo();
      final controller = MedicationController(
        repo,
        interactionCheckRepository: interactions,
      );
      addTearDown(controller.dispose);
      await controller.load();

      await tester.pumpWidget(AuthScope(
        controller: signedInAuth(),
        child: MedicationScope(
          controller: controller,
          child: MaterialApp(
            home: EditMedicationScreen(medication: controller.medications[1]),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Đổi dạng & màu (không hiện Bước 3/3)
      await tester.tap(find.byKey(const Key('edit-change-appearance')));
      await tester.pumpAndSettle();
      expect(find.text('Bước 3/3 · Xác nhận'), findsNothing);
      await tester.tap(find.byKey(const Key('pill-shape-capsule')));
      await tester.tap(find.byKey(const Key('pill-color-blue')));
      await tester.tap(find.byKey(const Key('use-pill-appearance')));
      await tester.pumpAndSettle();

      final scrollable = find
          .descendant(
            of: find.byType(EditMedicationScreen),
            matching: find.byType(Scrollable),
          )
          .first;

      // Chặn bỏ trống tất cả ngày uống -> nhấn Hằng ngày khôi phục
      for (var d = 1; d <= 7; d++) {
        await tester.scrollUntilVisible(
          find.byKey(Key('edit-day-$d')),
          100,
          scrollable: scrollable,
        );
        await tester.tap(find.byKey(Key('edit-day-$d')));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
      await tester.pumpAndSettle();
      expect(repo.updateCalls, isEmpty);
      await tester.tap(find.byKey(const Key('edit-days-everyday')));
      await tester.pumpAndSettle();

      // Chặn tồn kho âm, sau đó xoá tồn kho về null -> không chạy interaction check (phi lâm sàng)
      await tester.scrollUntilVisible(
        find.byKey(const Key('edit-stock-input')),
        200,
        scrollable: scrollable,
      );
      await tester.enterText(find.byKey(const Key('edit-stock-input')), '-5');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
      await tester.pumpAndSettle();
      expect(repo.updateCalls, isEmpty);

      await tester.enterText(find.byKey(const Key('edit-stock-input')), '');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
      await tester.pumpAndSettle();

      expect(interactions.checks, 0);
      final (before, after) = repo.updateCalls.single;
      expect(MedicationApiMapper.patchBody(before, after), {
        'stock_quantity': null,
        'pill_shape': 'capsule',
        'pill_color': 'blue',
      });
    });

    testWidgets('TC-606-23: AppRoutes.editMedication nhận ReminderSchedulerScope và hủy đúng schedule.id thật (AC5d, AC11)',
        (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final scheduler = _TestReminderScheduler();
      final repo = InMemoryMedicationRepository();
      final controller = MedicationController(repo);
      addTearDown(controller.dispose);
      await controller.load();
      final med = controller.medications.first; // Metformin 2 lịch

      await tester.pumpWidget(ReminderSchedulerScope(
        scheduler: scheduler,
        child: AuthScope(
          controller: signedInAuth(),
          child: MedicationScope(
            controller: controller,
            child: MaterialApp(
              onGenerateRoute: onGenerateRoute,
              home: Builder(
                builder: (context) => TextButton(
                  onPressed: () => Navigator.pushNamed(
                    context,
                    AppRoutes.editMedication,
                    arguments: med,
                  ),
                  child: const Text('Mở sửa'),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('Mở sửa'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const Key('edit_medication_reminder_switch')),
        200,
        scrollable: find
            .descendant(
              of: find.byType(EditMedicationScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.byKey(const Key('edit_medication_reminder_switch')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
      await tester.pumpAndSettle();

      expect(scheduler.cancelledSchedules, med.schedules.map((s) => s.id).toList());
    });

    testWidgets('TC-606-27: đổi tài khoản xóa NotificationPreferences nhưng khởi động lạnh vẫn giữ',
        (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final store = _PrefsStore(const ReminderPreferences(vibrate: false));
      final prefsController = NotificationPreferencesController(store: store);
      final authRepo = InMemoryAuthRepository(
        simulatedDelay: Duration.zero,
        initialSession: AuthSession(
          userId: 'user-1',
          accessToken: 'tok-1',
          expiresAt: DateTime.now().add(const Duration(days: 5)),
          profileComplete: true,
        ),
      );
      final auth = AuthController(authRepo);
      addTearDown(auth.dispose);

      await tester.pumpWidget(DrugTimeApp(
        authController: auth,
        medicationRepository: InMemoryMedicationRepository(),
        notificationPreferencesController: prefsController,
      ));
      await tester.pumpAndSettle();
      expect(prefsController.reminders.vibrate, isFalse, reason: 'cold start preserves stored prefs');

      await auth.signOut();
      await tester.pumpAndSettle();
      expect(prefsController.reminders.vibrate, isTrue);
    });

    for (final size in [const Size(320, 640), const Size(375, 812)]) {
      for (final scale in [1.0, 1.3, 2.0]) {
        testWidgets('TC-606-28 S06a/S06b no overflow at ${size.width.toInt()}x${size.height.toInt()} scale $scale',
            (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);

          final controller = MedicationController(InMemoryMedicationRepository());
          addTearDown(controller.dispose);
          await controller.load();

          await tester.pumpWidget(AuthScope(
            controller: signedInAuth(),
            child: MedicationScope(
              controller: controller,
              child: MaterialApp(
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: EditMedicationScreen(medication: controller.medications.first),
              ),
            ),
          ));
          await tester.pumpAndSettle();
          final err = tester.takeException();
          expect(err, isNull, reason: (err as FlutterError?)?.toStringDeep());
        });
      }
    }
  });
}
