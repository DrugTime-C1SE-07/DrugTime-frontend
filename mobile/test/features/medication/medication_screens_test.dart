import 'package:drugtime_mobile/app/app.dart';
import 'package:drugtime_mobile/features/auth/data/repositories/in_memory_auth_repository.dart';
import 'package:drugtime_mobile/features/auth/domain/entities/auth_session.dart';
import 'package:drugtime_mobile/features/auth/presentation/state/auth_controller.dart';
import 'package:drugtime_mobile/features/medication/data/repositories/in_memory_medication_repository.dart';
import 'package:drugtime_mobile/features/medication/domain/entities/medication.dart';
import 'package:drugtime_mobile/features/medication/domain/entities/medication_failure.dart';
import 'package:drugtime_mobile/features/medication/presentation/screens/add_medication_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';


/// Repository mẫu ghi lại lời gọi và cho phép giả lỗi cho lần gọi kế tiếp của từng thao tác.
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

Future<void> pickDrug(WidgetTester tester, String query, String name) async {
  await tester.tap(find.text('Tìm tên thuốc, hoạt chất…'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).last, query);
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
    scrollable: find.descendant(
      of: find.byType(AddMedicationScreen),
      matching: find.byType(Scrollable),
    ).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  group('S06 · Thuốc của tôi', () {
    testWidgets('hiện danh sách, cảnh báo sắp hết và lọc theo trạng thái', (tester) async {
      await pumpApp(tester);

      expect(find.text('Thuốc của tôi'), findsOneWidget);
      expect(find.text('4 thuốc đang dùng'), findsOneWidget);
      expect(find.text('1 thuốc sắp hết'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Sắp hết · còn 3 viên'), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('Sắp hết · còn 3 viên'), findsOneWidget);

      await tester.tap(find.text('Đã ngừng · 1'));
      await tester.pumpAndSettle();
      expect(find.text('Metformin 500mg'), findsNothing);
      expect(find.text('Amoxicillin 500mg'), findsOneWidget);
    });

    testWidgets('tìm theo hoạt chất và báo khi không có kết quả', (tester) async {
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
    testWidgets('bắt chọn thuốc trước khi lưu', (tester) async {
      await pumpApp(tester);
      await openAddScreen(tester);

      await tester.tap(find.text('Lưu thuốc'));
      await tester.pumpAndSettle();
      expect(find.text('Vui lòng chọn thuốc từ danh mục'), findsOneWidget);
    });

    testWidgets('chọn thuốc, đổi tần suất, lưu và thấy trong danh sách', (tester) async {
      await pumpApp(tester);
      await openAddScreen(tester);

      await tester.tap(find.text('Tìm tên thuốc, hoạt chất…'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'amlo');
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

      await tester.tap(find.text('Lưu thuốc'));
      await tester.pumpAndSettle();

      expect(find.text('Thuốc của tôi'), findsOneWidget);
      expect(find.text('Amlodipin 5mg'), findsOneWidget);
      expect(find.textContaining('Đã thêm Amlodipin 5mg'), findsOneWidget);
    });

    testWidgets('cảnh báo khi chọn thuốc đã có trong danh sách', (tester) async {
      await pumpApp(tester);
      await openAddScreen(tester);

      await tester.tap(find.text('Tìm tên thuốc, hoạt chất…'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'losartan');
      await tester.pumpAndSettle();
      expect(find.text('Đang dùng'), findsOneWidget);
      await tester.tap(find.text('Losartan 50mg'));
      await tester.pumpAndSettle();

      expect(find.textContaining('đã có trong danh sách đang dùng'), findsOneWidget);
    });

    testWidgets('nhấn Lưu hai lần liên tiếp chỉ thêm một thuốc', (tester) async {
      final repository = InMemoryMedicationRepository();
      final before = (await repository.fetchAll()).length;
      await pumpApp(tester, repository: repository);
      await openAddScreen(tester);

      await tester.tap(find.text('Tìm tên thuốc, hoạt chất…'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'amlo');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Amlodipin 5mg'));
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
      expect(find.text('Thuốc của tôi'), findsOneWidget);
    });

    testWidgets('hỏi xác nhận trước khi bỏ thông tin đã nhập', (tester) async {
      await pumpApp(tester);
      await openAddScreen(tester);

      await tapVisible(tester, find.text('3 lần/ngày'));
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Bỏ thông tin đã nhập?'), findsOneWidget);

      await tester.tap(find.text('Tiếp tục nhập'));
      await tester.pumpAndSettle();
      expect(find.text('Thêm thuốc mới'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bỏ'));
      await tester.pumpAndSettle();
      expect(find.text('Thuốc của tôi'), findsOneWidget);
    });
  });

  group('Nối API: lỗi, client_uuid, tối đa lần/ngày', () {
    testWidgets('lưu lỗi mạng: báo lỗi, giữ form; lưu lại dùng cùng client_uuid (AC9, AC10)',
        (tester) async {
      final repository = RecordingRepository();
      final before = (await repository.fetchAll()).length;
      await pumpApp(tester, repository: repository);
      await openAddScreen(tester);
      await pickDrug(tester, 'amlo', 'Amlodipin 5mg');

      repository.failNextAdd = const MedicationFailure(MedicationFailureKind.network);
      await tester.tap(find.text('Lưu thuốc'));
      await tester.pumpAndSettle();

      expect(find.text('Thêm thuốc mới'), findsOneWidget);
      expect(find.text('Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.'), findsOneWidget);
      expect(find.text('Amlodipin 5mg'), findsOneWidget); // thuốc đã chọn vẫn còn

      await tester.tap(find.text('Lưu thuốc'));
      await tester.pumpAndSettle();

      expect(find.text('Thuốc của tôi'), findsOneWidget);
      expect(repository.addCalls, hasLength(2));
      expect(repository.addCalls[0].$2, repository.addCalls[1].$2);
      expect(await repository.fetchAll(), hasLength(before + 1));
    });

    testWidgets('lỗi danh mục 422 hiện câu tiếng Việt tương ứng (AC10)', (tester) async {
      final repository = RecordingRepository();
      await pumpApp(tester, repository: repository);
      await openAddScreen(tester);
      await pickDrug(tester, 'amlo', 'Amlodipin 5mg');

      repository.failNextAdd = const MedicationFailure(MedicationFailureKind.catalogNotFound);
      await tester.tap(find.text('Lưu thuốc'));
      await tester.pumpAndSettle();

      expect(
        find.text('Thuốc này không còn trong danh mục. Vui lòng chọn thuốc khác.'),
        findsOneWidget,
      );
      expect(find.text('Thêm thuốc mới'), findsOneWidget);
    });

    testWidgets('"Khi cần" hiện ô tối đa lần/ngày 1–6, mặc định 3; đổi về theo giờ thì ẩn (AC14f)',
        (tester) async {
      final repository = RecordingRepository();
      await pumpApp(tester, repository: repository);
      await openAddScreen(tester);
      await pickDrug(tester, 'para', 'Paracetamol 500mg');

      expect(find.text('Tối đa mỗi ngày'), findsNothing);
      await tapVisible(tester, find.text('Khi cần'));
      expect(find.text('Tối đa mỗi ngày'), findsOneWidget);
      final stepper = find.byKey(const ValueKey('max-doses-stepper'));
      expect(find.descendant(of: stepper, matching: find.text('3 lần/ngày')), findsOneWidget);

      for (var i = 0; i < 5; i++) {
        await tapVisible(tester, find.byTooltip('Tăng số lần tối đa'));
      }
      expect(find.descendant(of: stepper, matching: find.text('6 lần/ngày')), findsOneWidget);
      final increase = tester.widget<IconButton>(
        find.ancestor(
          of: find.byTooltip('Tăng số lần tối đa'),
          matching: find.byType(IconButton),
        ),
      );
      expect(increase.onPressed, isNull, reason: 'không vượt quá 6');

      await tester.tap(find.text('Lưu thuốc'));
      await tester.pumpAndSettle();
      final draft = repository.addCalls.single.$1;
      expect(draft.frequency, DoseFrequency.asNeeded);
      expect(draft.maxDosesPerDay, 6);
    });

    testWidgets('chọn lại tần suất theo giờ thì ẩn ô và không gửi số lần tối đa', (tester) async {
      final repository = RecordingRepository();
      await pumpApp(tester, repository: repository);
      await openAddScreen(tester);
      await pickDrug(tester, 'para', 'Paracetamol 500mg');

      await tapVisible(tester, find.text('Khi cần'));
      await tapVisible(tester, find.text('2 lần/ngày'));
      expect(find.text('Tối đa mỗi ngày'), findsNothing);

      await tester.tap(find.text('Lưu thuốc'));
      await tester.pumpAndSettle();
      expect(repository.addCalls.single.$1.maxDosesPerDay, isNull);
    });

    testWidgets('S06 không tải được: thẻ lỗi + Thử lại, không báo "Chưa có thuốc nào"',
        (tester) async {
      final repository = RecordingRepository()
        ..failNextFetch = const MedicationFailure(MedicationFailureKind.network);
      await pumpApp(tester, repository: repository);

      expect(find.text('Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.'), findsOneWidget);
      expect(find.text('Chưa có thuốc nào'), findsNothing);

      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.text('Thử lại'), findsNothing);
      expect(find.text('4 thuốc đang dùng'), findsOneWidget);
    });

    testWidgets('sheet danh mục: chưa gõ thì gợi ý, không tìm', (tester) async {
      await pumpApp(tester);
      await openAddScreen(tester);
      await tester.tap(find.text('Tìm tên thuốc, hoạt chất…'));
      await tester.pumpAndSettle();

      expect(find.text('Gõ có dấu hay không dấu đều được, ví dụ: thuoc ho.'), findsOneWidget);
      expect(find.text('Metformin 500mg'), findsNothing);
    });
  });

  testWidgets('hàng chip S06 không rớt dòng khi phóng chữ 1.5x', (tester) async {
    await pumpApp(tester, textScale: 1.5);

    final tops = [
      for (final label in ['Tất cả · 5', 'Đang dùng · 4', 'Đã ngừng · 1'])
        tester.getRect(find.ancestor(of: find.text(label), matching: find.byType(InkWell)).first).top,
    ];
    expect(tops.toSet(), hasLength(1), reason: 'chip rớt xuống dòng khác: $tops');
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
