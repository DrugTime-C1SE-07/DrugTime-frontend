import 'package:drugtime_mobile/features/medication_capture/domain/ocr_models.dart';
import 'package:drugtime_mobile/app/app.dart';
import 'package:drugtime_mobile/features/medication_capture/domain/capture_models.dart';
import 'package:drugtime_mobile/features/auth/data/repositories/in_memory_auth_repository.dart';
import 'package:drugtime_mobile/features/auth/domain/entities/auth_session.dart';
import 'package:drugtime_mobile/features/auth/presentation/state/auth_controller.dart';
import 'package:drugtime_mobile/features/medication/data/repositories/in_memory_medication_repository.dart';
import 'package:drugtime_mobile/features/medication/domain/entities/medication.dart';
import 'package:drugtime_mobile/features/medication/domain/entities/medication_failure.dart';
import 'package:drugtime_mobile/features/medication/presentation/screens/add_medication_screen.dart';
import 'package:drugtime_mobile/features/medication/presentation/state/medication_controller.dart';
import 'package:drugtime_mobile/features/medication/presentation/widgets/medication_filter_bar.dart';
import 'package:drugtime_mobile/features/medication/presentation/widgets/medication_form_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Repository mẫu ghi lại lời gọi và cho phép giả lỗi cho lần gọi kế tiếp của từng thao tác.
class _OcrCatalogRepository extends RecordingRepository {
  @override
  Future<List<DrugCatalogItem>> searchCatalog(String query) async => const [
        DrugCatalogItem(
            id: '2',
            name: 'Thuốc dạng lỏng',
            activeIngredient: 'Hoạt chất',
            strength: '5 mg/ml',
            dosageForm: 'Dung dịch',
            unit: 'ml'),
      ];
}

class RecordingRepository extends InMemoryMedicationRepository {
  RecordingRepository({super.seed});

  final addCalls = <(Medication, String)>[];
  final updateCalls = <(Medication, Medication)>[];
  final stopCalls = <(String, bool)>[];
  final deleteCalls = <String>[];

  /// Lỗi ném ở lần gọi kế tiếp (rồi tự xoá).
  MedicationFailure? failNextAdd;
  MedicationFailure? failNextDelete;
  MedicationFailure? failNextFetch;

  @override
  Future<List<Medication>> fetchAll() {
    final failure = failNextFetch;
    failNextFetch = null;
    if (failure != null) throw failure;
    return super.fetchAll();
  }

  @override
  Future<Medication> add(Medication draft, {required String clientUuid}) {
    addCalls.add((draft, clientUuid));
    final failure = failNextAdd;
    failNextAdd = null;
    if (failure != null) throw failure;
    return super.add(draft, clientUuid: clientUuid);
  }

  @override
  Future<Medication> update(Medication before, Medication after) {
    updateCalls.add((before, after));
    return super.update(before, after);
  }

  @override
  Future<Medication> setStopped(String id, bool stopped) {
    stopCalls.add((id, stopped));
    return super.setStopped(id, stopped);
  }

  @override
  Future<void> delete(String id) {
    deleteCalls.add(id);
    final failure = failNextDelete;
    failNextDelete = null;
    if (failure != null) throw failure;
    return super.delete(id);
  }
}

class CatalogRecordingRepository extends RecordingRepository {
  final items = const [
    DrugCatalogItem(
        id: '100',
        name: 'Cùng tên',
        activeIngredient: 'Hoạt chất',
        strength: '5 mg',
        dosageForm: 'Viên nén'),
    DrugCatalogItem(
        id: '200',
        name: 'Cùng tên',
        activeIngredient: '',
        strength: '',
        dosageForm: ''),
  ];

  @override
  Future<List<DrugCatalogItem>> searchCatalog(String query) async => items;
}

Future<void> pickDrug(WidgetTester tester, String query, String name) async {
  await tester.tap(find.byType(TextField).last);
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).last, query);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pumpAndSettle();
  await tester.tap(find.text(name));
  await tester.pumpAndSettle();
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

Future<void> pumpApp(
  WidgetTester tester, {
  double textScale = 1,
  InMemoryMedicationRepository? repository,
}) async {
  tester.view.physicalSize = const Size(375, 812);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  await tester.pumpWidget(
    DrugTimeApp(
      authController: signedInAuth(),
      medicationRepository: repository ?? InMemoryMedicationRepository(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> openAddScreen(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Thêm'));
  await tester.pumpAndSettle();
  expect(find.text('Thêm thuốc mới'), findsOneWidget);
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  // ListView dựng lười: cuộn tới khi widget được build rồi mới chạm.
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find
        .descendant(
          of: find.byType(AddMedicationScreen),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('camera cancellation leaves existing add form intact',
      (tester) async {
    final repository = RecordingRepository();
    final controller = MedicationController(repository);
    var captures = 0;
    await tester.pumpWidget(MaterialApp(
        home: MedicationScope(
            controller: controller,
            child: AddMedicationScreen(captureLauncher: (_) async {
              captures++;
              return const CaptureResult.aborted();
            }))));
    await tester.tap(find.text('Quét vỏ thuốc'));
    await tester.pumpAndSettle();
    expect(captures, 1);
    expect(find.text('Thêm thuốc mới'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    expect(repository.addCalls, isEmpty);
    controller.dispose();
  });
  for (final strength in ['5 mg/ml', null]) {
    testWidgets(
        'OCR puts the selected ID and catalog dose unit on step 2 ($strength)',
        (tester) async {
      final repository = _OcrCatalogRepository();
      final controller = MedicationController(repository);
      final selected = OcrCandidate(
        id: 2,
        name: 'Thuốc dạng lỏng',
        activeIngredient: 'Hoạt chất',
        strengthText: strength,
        dosageForm: 'Dung dịch',
        hasActiveIngredients: true,
        score: .75,
      );
      const other = OcrCandidate(
        id: 1,
        name: 'Thuốc khác',
        activeIngredient: null,
        strengthText: null,
        dosageForm: null,
        hasActiveIngredients: false,
        score: .9,
      );
      await tester.pumpWidget(MaterialApp(
        home: MedicationScope(
          controller: controller,
          child: AddMedicationScreen(
            captureLauncher: (_) async => CaptureResult.candidates(
              OcrMatchResult(
                  status: OcrMatchStatus.lowConfidence,
                  items: [other, selected],
                  preselectedId: other.id,
                  suggestedQuery: null,
                  reasons: []),
              selectedCandidate: selected,
            ),
          ),
        ),
      ));
      await tester.tap(find.text('Quét vỏ hộp để tự điền'));
      await tester.pumpAndSettle();
      final selectedDrug =
          tester.widget<DrugPickerField>(find.byType(DrugPickerField)).value!;
      expect(selectedDrug.id, '2');
      expect(selectedDrug.unit, 'ml');
      expect(selectedDrug.strength, strength ?? '');
      expect(find.text('Lịch uống'), findsWidgets);
      expect(find.text('Thuốc khác'), findsNothing);
      expect(find.textContaining('HSD'), findsNothing);
      expect(find.textContaining('Quy cách'), findsNothing);
      expect(repository.addCalls, isEmpty);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });
  }
  group('S06 · Thuốc của tôi', () {
    testWidgets('hiện danh sách, cảnh báo sắp hết và lọc theo trạng thái',
        (tester) async {
      await pumpApp(tester);

      expect(find.text('Thuốc của tôi'), findsOneWidget);
      // Header không nhắc lại số thuốc đang dùng: thanh lọc đã hiện số đếm.
      expect(find.text('4 thuốc đang dùng'), findsNothing);
      expect(find.bySemanticsLabel('Đang dùng, 4 thuốc'), findsOneWidget);
      expect(find.text('1 thuốc sắp hết'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Sắp hết · còn 3 viên'), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('Sắp hết · còn 3 viên'), findsOneWidget);

      await tester.tap(find.text('Đã ngừng · 1'));
      await tester.pumpAndSettle();
      expect(find.text('Metformin 500mg'), findsNothing);
      expect(find.text('Amoxicillin 500mg'), findsOneWidget);
    });

    final headerAdd = find.widgetWithText(FilledButton, 'Thêm');
    final emptyAdd = find.widgetWithText(FilledButton, 'Thêm thuốc mới');

    testWidgets(
        'AC11, AC15: chưa có thuốc → chỉ nút giữa, không có tìm kiếm/tra cứu/bộ lọc',
        (tester) async {
      await pumpApp(tester,
          repository: InMemoryMedicationRepository(seed: const []));

      expect(find.text('Chưa có thuốc nào'), findsOneWidget);
      expect(emptyAdd, findsOneWidget);
      expect(headerAdd, findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Tra cứu danh mục thuốc'), findsNothing);
      expect(find.byType(MedicationFilterBar), findsNothing);

      await tester.tap(emptyAdd);
      await tester.pumpAndSettle();
      expect(find.byType(AddMedicationScreen), findsOneWidget);
    });

    testWidgets('AC12: có thuốc → có nút "Thêm" ở header, không có empty-state',
        (tester) async {
      await pumpApp(tester);

      expect(headerAdd, findsOneWidget);
      expect(emptyAdd, findsNothing);
      expect(find.text('Chưa có thuốc nào'), findsNothing);
      expect(find.byType(MedicationFilterBar), findsOneWidget);
    });

    testWidgets('AC13: tìm không khớp → chỉ nút "Thêm thuốc mới" ở giữa',
        (tester) async {
      await pumpApp(tester);

      await tester.enterText(find.byType(TextField), 'xyz');
      await tester.pumpAndSettle();

      expect(find.text('Không tìm thấy "xyz"'), findsOneWidget);
      expect(emptyAdd, findsOneWidget);
      expect(headerAdd, findsNothing);
      expect(
          find.byType(TextField), findsOneWidget); // còn ô tìm để sửa từ khóa
    });

    testWidgets('AC14: rỗng do tải lỗi → thẻ lỗi và nút "Thêm" ở header',
        (tester) async {
      final repository = RecordingRepository(seed: const [])
        ..failNextFetch =
            const MedicationFailure(MedicationFailureKind.network);
      await pumpApp(tester, repository: repository);

      expect(
          find.text('Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.'),
          findsOneWidget);
      expect(headerAdd, findsOneWidget);
      expect(emptyAdd, findsNothing);
    });

    testWidgets('tìm theo hoạt chất và báo khi không có kết quả',
        (tester) async {
      await pumpApp(tester);

      await tester.enterText(find.byType(TextField), 'cholecalciferol');
      await tester.pumpAndSettle();
      expect(find.text('Vitamin D3 1000IU'), findsOneWidget);
      expect(find.text('Metformin 500mg'), findsNothing);

      await tester.enterText(find.byType(TextField), 'xyz');
      await tester.pumpAndSettle();
      expect(find.text('Không tìm thấy "xyz"'), findsOneWidget);

      await tester.tap(find.byTooltip('Xoá tìm kiếm'));
      await tester.pumpAndSettle();
      expect(find.text('Metformin 500mg'), findsOneWidget);
    });
  });

  group('S07 · Thêm thuốc mới', () {
    testWidgets(
        '3.05: hủy/chọn lại giữ dữ liệu sử dụng, chưa tự lưu và đúng catalog id',
        (tester) async {
      final repository = RecordingRepository();
      await pumpApp(tester, repository: repository);
      await openAddScreen(tester);
      await pickDrug(tester, 'amlo', 'Amlodipin 5mg');
      await tapVisible(tester, find.byTooltip('Tăng liều'));
      await tapVisible(tester, find.text('3 lần/ngày'));
      // DrugPickerField is at the TOP of step-1 ListView.
      // After tapVisible() calls the list has scrolled down, so scroll back up first.
      final step1Scrollable = find
          .descendant(
              of: find.byType(AddMedicationScreen),
              matching: find.byType(Scrollable))
          .first;
      await tester.scrollUntilVisible(
        find.byType(DrugPickerField),
        -200,
        scrollable: step1Scrollable,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DrugPickerField));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'losartan');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Losartan 50mg'));
      await tester.pumpAndSettle();
      // Selecting without confirming cannot replace the existing form or save.
      expect(repository.addCalls, isEmpty);
      Navigator.of(tester.element(find.byType(TextField).last)).pop();
      await tester.pumpAndSettle();
      final original =
          tester.widget<DrugPickerField>(find.byType(DrugPickerField)).value!;
      expect(original.id, 'amlodipin-5');
      expect(repository.addCalls, isEmpty);
      await tester.scrollUntilVisible(
        find.byType(DrugPickerField),
        -200,
        scrollable: step1Scrollable,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DrugPickerField));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'losartan');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('Đang dùng'), findsOneWidget);
      await tester.tap(find.text('Losartan 50mg'));
      await tester.pumpAndSettle();
      expect(repository.addCalls, isEmpty);
      await tester.tap(find.text('Xác nhận thuốc'));
      await tester.pumpAndSettle();
      final picked =
          tester.widget<DrugPickerField>(find.byType(DrugPickerField)).value!;
      expect(picked.id, 'losartan-50');
      expect(picked.strength, '50 mg');
      expect(repository.addCalls, isEmpty);
      expect(find.textContaining('đã có trong danh sách đang dùng'),
          findsOneWidget);
      await tester.tap(find.text('Tiếp tục'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lưu thuốc'));
      await tester.pumpAndSettle();
      final saved = repository.addCalls.single.$1;
      expect(saved.catalogId, picked.id);
      expect(saved.name, picked.name);
      expect(saved.activeIngredient, picked.activeIngredient);
      expect(saved.strength, picked.strength);
      expect(saved.dosageForm, picked.dosageForm);
      expect(saved.unit, picked.unit);
      expect(saved.dosePerIntake, 2);
      expect(saved.frequency, DoseFrequency.thrice);
      expect(saved.times, DoseFrequency.thrice.defaultTimes);
    });

    testWidgets(
        '3.05: chọn đúng item cùng tên, thiếu thông tin giữ trường trống không tự lưu',
        (tester) async {
      final repository = CatalogRecordingRepository();
      await pumpApp(tester, repository: repository);
      await openAddScreen(tester);
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Cùng');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('Cùng tên'), findsNWidgets(2));
      expect(find.text('5 mg'), findsOneWidget);
      await tester.tap(find.text('Cùng tên').last);
      await tester.pumpAndSettle();
      expect(repository.addCalls, isEmpty);
      final picked =
          tester.widget<DrugPickerField>(find.byType(DrugPickerField)).value;
      expect(picked, same(repository.items.last));
      expect(
          tester.widget<ReadOnlyField>(find.byType(ReadOnlyField)).value, '');
      expect(find.textContaining('null'), findsNothing);
      expect(repository.addCalls, isEmpty);
      await tester.tap(find.text('Tiếp tục'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lưu thuốc'));
      await tester.pumpAndSettle();
      final saved = repository.addCalls.single.$1;
      expect(saved.catalogId, '200');
      expect(saved.activeIngredient, '');
      expect(saved.strength, '');
      expect(saved.dosageForm, isNull);
    });

    testWidgets('bắt chọn thuốc trước khi lưu', (tester) async {
      await pumpApp(tester);
      await openAddScreen(tester);

      await tester.tap(find.text('Tiếp tục'));
      await tester.pumpAndSettle();
      expect(find.text('Vui lòng chọn thuốc từ danh mục'), findsOneWidget);
    });

    testWidgets('chọn thuốc, đổi tần suất, lưu và thấy trong danh sách',
        (tester) async {
      await pumpApp(tester);
      await openAddScreen(tester);

      await tester.tap(find.byType(TextField).last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'amlo');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Amlodipin 5mg'));
      await tester.pumpAndSettle();

      // Hàm lượng tự điền từ danh mục.
      expect(find.text('5 mg'), findsOneWidget);

      await tapVisible(tester, find.byTooltip('Tăng liều'));
      expect(find.text('2 viên'), findsOneWidget);

      await tapVisible(tester, find.text('Khi cần'));
      expect(find.text('08:00'), findsNothing);
      expect(find.textContaining('không có lịch nhắc'), findsOneWidget);

      await tapVisible(tester, find.text('1 lần/ngày'));
      expect(find.text('08:00'), findsOneWidget);

      await tester.tap(find.text('Tiếp tục'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lưu thuốc'));
      await tester.pumpAndSettle();

      if (find.text('Về trang chủ').evaluate().isNotEmpty) {
        await tester.tap(find.text('Về trang chủ'));
        await tester.pumpAndSettle();
      }

      expect(find.text('Thuốc của tôi'), findsOneWidget);
      expect(find.text('Amlodipin 5mg'), findsOneWidget);
      expect(find.textContaining('Đã thêm Amlodipin 5mg'), findsOneWidget);
    });

    testWidgets('cảnh báo khi chọn thuốc đã có trong danh sách',
        (tester) async {
      await pumpApp(tester);
      await openAddScreen(tester);

      await tester.tap(find.byType(TextField).last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'losartan');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('Đang dùng'), findsOneWidget);
      await tester.tap(find.text('Losartan 50mg'));
      await tester.pumpAndSettle();

      expect(find.textContaining('đã có trong danh sách đang dùng'),
          findsOneWidget);
    });

    testWidgets('nhấn Lưu hai lần liên tiếp chỉ thêm một thuốc',
        (tester) async {
      final repository = InMemoryMedicationRepository();
      final before = (await repository.fetchAll()).length;
      await pumpApp(tester, repository: repository);
      await openAddScreen(tester);

      await tester.tap(find.byType(TextField).last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'amlo');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Amlodipin 5mg'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tiếp tục'));
      await tester.pumpAndSettle();

      // Hai lần nhấn trước khi frame kế tiếp kịp vô hiệu nút. Gọi thẳng onPressed
      // vì tap() thứ hai sẽ trượt: repo trong bộ nhớ lưu xong và đóng màn ngay.
      final save = tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Lưu thuốc'))
          .onPressed!;
      save();
      save();
      await tester.pumpAndSettle();

      final saved = await repository.fetchAll();
      expect(saved, hasLength(before + 1));
      expect(saved.where((m) => m.catalogId == 'amlodipin-5'), hasLength(1));
      if (find.text('Về trang chủ').evaluate().isNotEmpty) {
        await tester.tap(find.text('Về trang chủ'));
        await tester.pumpAndSettle();
      }
      expect(find.text('Thuốc của tôi'), findsOneWidget);
    });

    testWidgets('Lùi hệ thống quay lại từng bước và thoát không cảnh báo',
        (tester) async {
      await pumpApp(tester);
      await openAddScreen(tester);

      await pickDrug(tester, 'amlo', 'Amlodipin 5mg');
      await tester.tap(find.text('Tiếp tục'));
      await tester.pumpAndSettle();
      expect(find.byType(FigmaConfirmSummaryCard), findsOneWidget);
      expect(find.text('Đổi'), findsNothing);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(FigmaScheduleInputCard), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Tìm thuốc'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Thuốc của tôi'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);

      await openAddScreen(tester);
      await pickDrug(tester, 'amlo', 'Amlodipin 5mg');
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Thuốc của tôi'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
    });
  });

  group('Nối API: lỗi, client_uuid, tối đa lần/ngày', () {
    testWidgets(
        'lưu lỗi mạng: báo lỗi, giữ form; lưu lại dùng cùng client_uuid (AC9, AC10)',
        (tester) async {
      final repository = RecordingRepository();
      final before = (await repository.fetchAll()).length;
      await pumpApp(tester, repository: repository);
      await openAddScreen(tester);
      await pickDrug(tester, 'amlo', 'Amlodipin 5mg');

      repository.failNextAdd =
          const MedicationFailure(MedicationFailureKind.network);
      await tester.tap(find.text('Tiếp tục'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lưu thuốc'));
      await tester.pumpAndSettle();

      expect(find.text('Thêm thuốc mới'), findsOneWidget);
      expect(
          find.text('Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.'),
          findsOneWidget);
      expect(
          find.text('Amlodipin 5mg'), findsOneWidget); // thuốc đã chọn vẫn còn

      await tester.tap(find.text('Lưu thuốc'));
      await tester.pumpAndSettle();

      if (find.text('Về trang chủ').evaluate().isNotEmpty) {
        await tester.tap(find.text('Về trang chủ'));
        await tester.pumpAndSettle();
      }

      expect(find.text('Thuốc của tôi'), findsOneWidget);
      expect(repository.addCalls, hasLength(2));
      expect(repository.addCalls[0].$2, repository.addCalls[1].$2);
      expect(await repository.fetchAll(), hasLength(before + 1));
    });

    testWidgets('lỗi danh mục 422 hiện câu tiếng Việt tương ứng (AC10)',
        (tester) async {
      final repository = RecordingRepository();
      await pumpApp(tester, repository: repository);
      await openAddScreen(tester);
      await pickDrug(tester, 'amlo', 'Amlodipin 5mg');

      repository.failNextAdd =
          const MedicationFailure(MedicationFailureKind.catalogNotFound);
      await tester.tap(find.text('Tiếp tục'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lưu thuốc'));
      await tester.pumpAndSettle();

      expect(
        find.text(
            'Thuốc này không còn trong danh mục. Vui lòng chọn thuốc khác.'),
        findsOneWidget,
      );
      expect(find.text('Thêm thuốc mới'), findsOneWidget);
    });

    testWidgets(
        '"Khi cần" hiện ô tối đa lần/ngày 1–6, mặc định 3; đổi về theo giờ thì ẩn (AC14f)',
        (tester) async {
      final repository = RecordingRepository();
      await pumpApp(tester, repository: repository);
      await openAddScreen(tester);
      await pickDrug(tester, 'para', 'Paracetamol 500mg');

      expect(find.text('Tối đa mỗi ngày'), findsNothing);
      await tapVisible(tester, find.text('Khi cần'));
      expect(find.text('Tối đa mỗi ngày'), findsOneWidget);
      final stepper = find.byKey(const ValueKey('max-doses-stepper'));
      expect(find.descendant(of: stepper, matching: find.text('3 lần/ngày')),
          findsOneWidget);

      for (var i = 0; i < 5; i++) {
        await tapVisible(tester, find.byTooltip('Tăng số lần tối đa'));
      }
      expect(find.descendant(of: stepper, matching: find.text('6 lần/ngày')),
          findsOneWidget);
      final increase = tester.widget<IconButton>(
        find.ancestor(
          of: find.byTooltip('Tăng số lần tối đa'),
          matching: find.byType(IconButton),
        ),
      );
      expect(increase.onPressed, isNull, reason: 'không vượt quá 6');

      await tester.tap(find.text('Tiếp tục'));
      await tester.pumpAndSettle();
      expect(find.text('Tối đa 6 viên'), findsOneWidget);
      await tester.tap(find.text('Lưu thuốc'));
      await tester.pumpAndSettle();
      final draft = repository.addCalls.single.$1;
      expect(draft.frequency, DoseFrequency.asNeeded);
      expect(draft.maxDosesPerDay, 6);
    });

    testWidgets(
        'chọn lại tần suất theo giờ thì ẩn ô và không gửi số lần tối đa',
        (tester) async {
      final repository = RecordingRepository();
      await pumpApp(tester, repository: repository);
      await openAddScreen(tester);
      await pickDrug(tester, 'para', 'Paracetamol 500mg');

      await tapVisible(tester, find.text('Khi cần'));
      await tapVisible(tester, find.text('2 lần/ngày'));
      expect(find.text('Tối đa mỗi ngày'), findsNothing);

      await tester.tap(find.text('Tiếp tục'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lưu thuốc'));
      await tester.pumpAndSettle();
      expect(repository.addCalls.single.$1.maxDosesPerDay, isNull);
    });

    testWidgets(
        'S06 không tải được: thẻ lỗi + Thử lại, không báo "Chưa có thuốc nào"',
        (tester) async {
      final repository = RecordingRepository()
        ..failNextFetch =
            const MedicationFailure(MedicationFailureKind.network);
      await pumpApp(tester, repository: repository);

      expect(
          find.text('Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.'),
          findsOneWidget);
      expect(find.text('Chưa có thuốc nào'), findsNothing);

      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.text('Thử lại'), findsNothing);
      expect(find.bySemanticsLabel('Đang dùng, 4 thuốc'), findsOneWidget);
    });

    testWidgets('ô tìm danh mục: chưa gõ thì gợi ý', (tester) async {
      await pumpApp(tester);
      await openAddScreen(tester);
      await tester.tap(find.byType(TextField).last);
      await tester.pumpAndSettle();

      expect(find.text('Gõ có dấu hay không dấu đều được, ví dụ: thuoc ho.'),
          findsOneWidget);
      expect(find.text('Metformin 500mg'), findsNothing);
    });
  });

  testWidgets('hàng chip S06 không rớt dòng khi phóng chữ 1.5x',
      (tester) async {
    await pumpApp(tester, textScale: 1.5);

    final tops = [
      for (final label in ['Tất cả · 5', 'Đang dùng · 4', 'Đã ngừng · 1'])
        tester
            .getRect(find
                .ancestor(of: find.text(label), matching: find.byType(InkWell))
                .first)
            .top,
    ];
    expect(tops.toSet(), hasLength(1),
        reason: 'chip rớt xuống dòng khác: $tops');
    expect(tester.takeException(), isNull);
  });

  testWidgets('bố cục không vỡ khi phóng to chữ 1.5x', (tester) async {
    await pumpApp(tester, textScale: 1.5);
    expect(find.text('Thuốc của tôi'), findsOneWidget);

    await openAddScreen(tester);
    await tester.drag(find.byType(ListView).first, const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
