import 'dart:async';

import 'package:drugtime_mobile/features/medication/data/repositories/in_memory_medication_repository.dart';
import 'package:drugtime_mobile/features/medication/domain/entities/medication.dart';
import 'package:drugtime_mobile/features/medication/domain/entities/medication_failure.dart';
import 'package:drugtime_mobile/features/medication/presentation/screens/medication_detail_screen.dart';
import 'package:drugtime_mobile/features/medication/presentation/state/medication_controller.dart';
import 'package:drugtime_mobile/features/medication/presentation/widgets/drug_catalog_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _TestMedicationRepo extends InMemoryMedicationRepository {
  _TestMedicationRepo({super.seed});

  final queries = <String>[];
  final pendingSearchRequests = <Completer<List<DrugCatalogItem>>>[];
  final stopCalls = <(String, bool)>[];

  MedicationFailure? failNextStop;

  @override
  Future<List<DrugCatalogItem>> searchCatalog(String query) {
    queries.add(query);
    final completer = Completer<List<DrugCatalogItem>>();
    pendingSearchRequests.add(completer);
    return completer.future;
  }

  @override
  Future<Medication> setStopped(String id, bool stopped) {
    stopCalls.add((id, stopped));
    final failure = failNextStop;
    if (failure != null) {
      failNextStop = null;
      throw failure;
    }
    return super.setStopped(id, stopped);
  }
}

DrugCatalogItem _catalogItem({
  required String id,
  required String name,
  String activeIngredient = 'Paracetamol',
  String strength = '500 mg',
  String dosageForm = 'Viên nén',
  String unit = 'viên',
}) {
  return DrugCatalogItem(
    id: id,
    name: name,
    activeIngredient: activeIngredient,
    strength: strength,
    dosageForm: dosageForm,
    unit: unit,
  );
}

Medication _medication({
  String id = 'med-1',
  String catalogId = 'cat-1',
  String name = 'Amoxicillin 500mg',
  String activeIngredient = 'Amoxicillin',
  String strength = '500 mg',
  String dosageForm = 'Viên nang cứng',
  String unit = 'viên',
  double dosePerIntake = 2.0,
  DoseFrequency frequency = DoseFrequency.twice,
  IntakeTiming timing = IntakeTiming.afterMeal,
  List<DoseTime> times = const [DoseTime(8, 0), DoseTime(20, 0)],
  MedicationStatus status = MedicationStatus.active,
  int? stockRemaining = 20,
  int? maxDosesPerDay,
}) {
  return Medication(
    id: id,
    catalogId: catalogId,
    name: name,
    activeIngredient: activeIngredient,
    strength: strength,
    dosageForm: dosageForm,
    unit: unit,
    dosePerIntake: dosePerIntake,
    frequency: frequency,
    timing: timing,
    times: times,
    status: status,
    stockRemaining: stockRemaining,
    maxDosesPerDay: maxDosesPerDay,
  );
}

Future<(_TestMedicationRepo, MedicationController)> _mountCatalogSheet(
  WidgetTester tester, {
  _TestMedicationRepo? repo,
}) async {
  tester.view.physicalSize = const Size(375, 812);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final repository = repo ?? _TestMedicationRepo();
  final controller = MedicationController(repository);
  addTearDown(controller.dispose);

  await tester.pumpWidget(
    MaterialApp(
      home: MedicationScope(
        controller: controller,
        child: const Scaffold(body: DrugCatalogSheet()),
      ),
    ),
  );
  await tester.pump();
  return (repository, controller);
}

Future<(_TestMedicationRepo, MedicationController)> _mountDetailScreen(
  WidgetTester tester, {
  required Medication medication,
  String? dosageForm,
  _TestMedicationRepo? repo,
}) async {
  tester.view.physicalSize = const Size(375, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final repository = repo ?? _TestMedicationRepo(seed: [medication]);
  final controller = MedicationController(repository);
  addTearDown(controller.dispose);

  await tester.pumpWidget(
    MaterialApp(
      home: MedicationScope(
        controller: controller,
        child: MedicationDetailScreen(
          medication: medication,
          dosageForm: dosageForm,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (repository, controller);
}

Future<void> _scrollIntoView(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    150,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Subtask 4.a — Debounce tìm kiếm danh mục thuốc', () {
    testWidgets('gõ nhanh liên tiếp nhiều ký tự chỉ gọi API đúng 1 lần sau 300ms',
        (tester) async {
      final (repo, _) = await _mountCatalogSheet(tester);

      // Gõ nhanh 'P', 'Pa', 'Par', 'Para' mỗi 100ms (< 300ms debounce)
      await tester.enterText(find.byType(TextField), 'P');
      await tester.pump(const Duration(milliseconds: 100));
      expect(repo.queries, isEmpty, reason: 'Chưa đủ debounce, chưa được gọi');

      await tester.enterText(find.byType(TextField), 'Pa');
      await tester.pump(const Duration(milliseconds: 100));
      expect(repo.queries, isEmpty, reason: 'Chưa đủ debounce, chưa được gọi');

      await tester.enterText(find.byType(TextField), 'Par');
      await tester.pump(const Duration(milliseconds: 100));
      expect(repo.queries, isEmpty, reason: 'Chưa đủ debounce, chưa được gọi');

      await tester.enterText(find.byType(TextField), 'Para');
      await tester.pump(const Duration(milliseconds: 299));
      expect(repo.queries, isEmpty, reason: '299ms vẫn chưa đủ debounce');

      // Đến đúng 300ms debounce
      await tester.pump(const Duration(milliseconds: 1));
      expect(repo.queries, ['Para'], reason: 'Chỉ gọi đúng 1 lần với chuỗi cuối');

      // Trả về kết quả và kiểm tra hiển thị
      repo.pendingSearchRequests.single.complete([
        _catalogItem(id: 'c1', name: 'Paracetamol 500mg'),
      ]);
      await tester.pump();
      expect(find.text('Paracetamol 500mg'), findsOneWidget);
    });

    testWidgets('gõ chậm hơn debounce gọi repository nhiều lần theo đúng số lần',
        (tester) async {
      final (repo, _) = await _mountCatalogSheet(tester);

      // Nhập 'P' và đợi quá debounce
      await tester.enterText(find.byType(TextField), 'P');
      await tester.pump(const Duration(milliseconds: 300));
      expect(repo.queries, ['P']);
      repo.pendingSearchRequests[0].complete([]);
      await tester.pump();

      // Nhập 'Pa' và đợi quá debounce
      await tester.enterText(find.byType(TextField), 'Pa');
      await tester.pump(const Duration(milliseconds: 300));
      expect(repo.queries, ['P', 'Pa']);
      repo.pendingSearchRequests[1].complete([]);
      await tester.pump();

      // Nhập 'Par' và đợi quá debounce
      await tester.enterText(find.byType(TextField), 'Par');
      await tester.pump(const Duration(milliseconds: 300));
      expect(repo.queries, ['P', 'Pa', 'Par']);
      repo.pendingSearchRequests[2].complete([
        _catalogItem(id: 'c1', name: 'Panadol'),
      ]);
      await tester.pump();
      expect(find.text('Panadol'), findsOneWidget);
    });

    testWidgets('xóa hết ô tìm trong lúc đang debounce huỷ timer và không gọi API',
        (tester) async {
      final (repo, _) = await _mountCatalogSheet(tester);

      // Gõ 'Para', đợi 150ms (< 300ms) rồi xoá hết
      await tester.enterText(find.byType(TextField), 'Para');
      await tester.pump(const Duration(milliseconds: 150));
      expect(repo.queries, isEmpty);

      // Xoá trắng ô tìm kiếm
      await tester.enterText(find.byType(TextField), '');
      await tester.pump(const Duration(milliseconds: 400));

      // Không có cuộc gọi API nào được thực hiện
      expect(repo.queries, isEmpty);
      // Hiển thị lời nhắc tìm kiếm ban đầu
      expect(
        find.text('Gõ có dấu hay không dấu đều được, ví dụ: thuoc ho.'),
        findsOneWidget,
      );
    });

    testWidgets(
        'sau khi có kết quả, xóa hết ô tìm kiếm đặt lại danh sách rỗng và không gọi thêm API',
        (tester) async {
      final (repo, _) = await _mountCatalogSheet(tester);

      // Gõ và nhận kết quả
      await tester.enterText(find.byType(TextField), 'Para');
      await tester.pump(const Duration(milliseconds: 300));
      expect(repo.queries, ['Para']);
      repo.pendingSearchRequests.single.complete([
        _catalogItem(id: 'c1', name: 'Paracetamol 500mg'),
      ]);
      await tester.pump();
      expect(find.text('Paracetamol 500mg'), findsOneWidget);

      // Xoá ô tìm kiếm
      await tester.enterText(find.byType(TextField), '');
      await tester.pump(const Duration(milliseconds: 400));

      // Kết quả cũ bị xoá, không phát sinh lệnh gọi API mới
      expect(find.text('Paracetamol 500mg'), findsNothing);
      expect(repo.queries, ['Para']);
      expect(
        find.text('Gõ có dấu hay không dấu đều được, ví dụ: thuoc ho.'),
        findsOneWidget,
      );
    });
  });

  group('Subtask 4.c — Các trạng thái tìm kiếm (rỗng, đang tải, lỗi mạng / offline)', () {
    testWidgets('trạng thái ban đầu rỗng hiện hướng dẫn và không gọi API',
        (tester) async {
      final (repo, _) = await _mountCatalogSheet(tester);

      expect(repo.queries, isEmpty);
      expect(find.text('Chọn thuốc từ danh mục'), findsOneWidget);
      expect(
        find.text('Gõ có dấu hay không dấu đều được, ví dụ: thuoc ho.'),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('trạng thái đang tải hiển thị CircularProgressIndicator',
        (tester) async {
      final (repo, _) = await _mountCatalogSheet(tester);

      await tester.enterText(find.byType(TextField), 'Aspirin');
      await tester.pump(const Duration(milliseconds: 300));
      expect(repo.queries, ['Aspirin']);

      // Khi API chưa trả lời, CircularProgressIndicator hiển thị
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Khi API trả về, indicator biến mất
      repo.pendingSearchRequests.single.complete([]);
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('trạng thái rỗng không có kết quả hiển thị thông báo không tìm thấy',
        (tester) async {
      final (repo, _) = await _mountCatalogSheet(tester);

      await tester.enterText(find.byType(TextField), 'ThuocKhongCo');
      await tester.pump(const Duration(milliseconds: 300));
      repo.pendingSearchRequests.single.complete([]);
      await tester.pump();

      expect(find.text('Không tìm thấy thuốc phù hợp'), findsOneWidget);
      expect(
        find.text(
          'Kiểm tra lại chính tả, hoặc thử tìm bằng tên hoạt chất (ví dụ: Paracetamol).',
        ),
        findsOneWidget,
      );
    });

    testWidgets('từ khoá vượt quá 100 ký tự hiển thị cảnh báo và không gọi API',
        (tester) async {
      final (repo, _) = await _mountCatalogSheet(tester);

      final over100 = 'a' * 101;
      await tester.enterText(find.byType(TextField), over100);
      await tester.pump(const Duration(milliseconds: 300));

      expect(repo.queries, isEmpty, reason: 'Quá 100 ký tự không được gọi API');
      expect(find.text('Từ khóa quá dài'), findsOneWidget);
      expect(
        find.text('Nhập tối đa 100 ký tự sau khi bỏ khoảng trắng đầu và cuối.'),
        findsOneWidget,
      );
    });

    testWidgets(
        'lỗi mạng (offline) hiển thị Chưa tìm được + thông báo lỗi mạng + nút Thử lại',
        (tester) async {
      final (repo, _) = await _mountCatalogSheet(tester);

      await tester.enterText(find.byType(TextField), 'Para');
      await tester.pump(const Duration(milliseconds: 300));
      repo.pendingSearchRequests[0]
          .completeError(const MedicationFailure(MedicationFailureKind.network));
      await tester.pump();

      expect(find.text('Chưa tìm được'), findsOneWidget);
      expect(
        find.text('Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.'),
        findsOneWidget,
      );
      expect(find.text('Thử lại'), findsOneWidget);

      // Bấm nút Thử lại
      await tester.tap(find.text('Thử lại'));
      await tester.pump();

      // Kiểm tra gọi lại đúng từ khóa 'Para'
      expect(repo.queries, ['Para', 'Para']);

      // Lần 2 thành công
      repo.pendingSearchRequests[1].complete([
        _catalogItem(id: 'c1', name: 'Paracetamol 500mg'),
      ]);
      await tester.pump();

      expect(find.text('Chưa tìm được'), findsNothing);
      expect(find.text('Paracetamol 500mg'), findsOneWidget);
    });

    testWidgets('lỗi unauthorized không hiển thị nút Thử lại', (tester) async {
      final (repo, _) = await _mountCatalogSheet(tester);

      await tester.enterText(find.byType(TextField), 'Para');
      await tester.pump(const Duration(milliseconds: 300));
      repo.pendingSearchRequests.single
          .completeError(const MedicationFailure(MedicationFailureKind.unauthorized));
      await tester.pump();

      expect(find.text('Chưa tìm được'), findsOneWidget);
      expect(
        find.text('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.'),
        findsOneWidget,
      );
      expect(find.text('Thử lại'), findsNothing);
    });
  });

  group('Subtask 4.b — Màn chi tiết thuốc hiển thị ĐỦ các trường theo model thực tế', () {
    testWidgets('hiển thị đầy đủ mọi trường dữ liệu: tên, dạng bào chế, hoạt chất, hàm lượng, liều, tần suất, giờ, tồn kho',
        (tester) async {
      final med = _medication(
        name: 'Amoxicillin 500mg',
        activeIngredient: 'Amoxicillin trihydrat',
        strength: '500 mg',
        dosageForm: 'Viên nang cứng',
        unit: 'viên',
        dosePerIntake: 2.0,
        frequency: DoseFrequency.twice,
        timing: IntakeTiming.afterMeal,
        times: const [DoseTime(8, 0), DoseTime(20, 0)],
        status: MedicationStatus.active,
        stockRemaining: 30,
      );

      await _mountDetailScreen(tester, medication: med);

      // Tiêu đề AppBar
      expect(find.text('Chi tiết thuốc'), findsOneWidget);

      // 1. Thẻ tiêu đề
      expect(find.text('Amoxicillin 500mg'), findsWidgets);
      expect(
        find.text('Amoxicillin trihydrat · Viên nang cứng'),
        findsOneWidget,
      );
      expect(find.text('Đang dùng'), findsOneWidget);

      // 2. Thẻ chỉ định liều lượng (Metrics)
      expect(find.text('Số lượng/lần'), findsOneWidget);
      expect(find.text('2 viên'), findsWidgets);
      expect(find.text('Tần suất'), findsOneWidget);
      expect(find.text('2 lần/ngày'), findsOneWidget);
      expect(find.text('Cách uống'), findsOneWidget);
      expect(find.text('Sau ăn'), findsOneWidget);

      // 3. Giờ uống trong ngày
      expect(find.text('Giờ uống trong ngày'), findsOneWidget);
      expect(find.text('Nhắc uống lúc 08:00'), findsOneWidget);
      expect(find.text('Nhắc uống lúc 20:00'), findsOneWidget);

      // 4. Bảng thông tin chi tiết dược lý & tồn kho (cuộn đến bảng chi tiết)
      await _scrollIntoView(tester, find.text('Thông tin chi tiết'));
      expect(find.text('Thông tin chi tiết'), findsOneWidget);
      expect(find.text('Tên biệt dược'), findsOneWidget);
      expect(find.text('Hoạt chất chính'), findsOneWidget);
      expect(find.text('Amoxicillin trihydrat'), findsOneWidget);
      expect(find.text('Hàm lượng'), findsOneWidget);
      expect(find.text('500 mg'), findsOneWidget);
      expect(find.text('Dạng bào chế'), findsOneWidget);
      expect(find.text('Viên nang cứng'), findsWidgets);
      expect(find.text('Đơn vị tính'), findsOneWidget);
      expect(find.text('Số lượng tồn kho'), findsOneWidget);
      expect(find.text('Còn 30 viên'), findsOneWidget);

      // 5. Lưu ý an toàn
      await _scrollIntoView(tester, find.textContaining('Luôn uống thuốc đúng giờ'));
      expect(
        find.textContaining('Luôn uống thuốc đúng giờ và theo đúng liều lượng'),
        findsOneWidget,
      );

      // 6. Nút thao tác
      expect(find.text('Sửa thông tin thuốc'), findsOneWidget);
      expect(find.text('Tạm ngừng thuốc này'), findsOneWidget);

      // Xác minh KHÔNG có trường nhà sản xuất (hợp đồng API và model không hỗ trợ)
      expect(find.textContaining('nhà sản xuất', findRichText: true), findsNothing);
      expect(find.textContaining('Nhà sản xuất', findRichText: true), findsNothing);
    });

    testWidgets('trường hoạt chất trống hiển thị Chưa có thông tin', (tester) async {
      final med = _medication(
        name: 'Thuốc Không Rõ Hoạt Chất',
        activeIngredient: '',
        strength: '10 mg',
      );

      await _mountDetailScreen(tester, medication: med);
      await _scrollIntoView(tester, find.text('Thông tin chi tiết'));

      expect(find.text('Chưa có thông tin'), findsOneWidget);
    });

    testWidgets('trường tồn kho null hiển thị Chưa theo dõi', (tester) async {
      final med = _medication(
        name: 'Vitamin tổng hợp',
        stockRemaining: null,
      );

      await _mountDetailScreen(tester, medication: med);
      await _scrollIntoView(tester, find.text('Thông tin chi tiết'));

      expect(find.text('Chưa theo dõi'), findsOneWidget);
    });

    testWidgets('tồn kho sắp hết (<= 5) hiển thị cảnh báo Sắp hết thuốc',
        (tester) async {
      final med = _medication(
        name: 'Losartan 50mg',
        stockRemaining: 3,
      );

      await _mountDetailScreen(tester, medication: med);
      await _scrollIntoView(tester, find.text('Thông tin chi tiết'));

      expect(find.text('Còn 3 viên'), findsOneWidget);
      expect(find.text('Sắp hết thuốc'), findsOneWidget);
    });

    testWidgets(
        'thuốc Khi cần hiển thị tối đa lần/ngày và nhắc nhở không có giờ cố định',
        (tester) async {
      final med = _medication(
        name: 'Paracetamol 500mg',
        frequency: DoseFrequency.asNeeded,
        maxDosesPerDay: 4,
        times: const [],
      );

      await _mountDetailScreen(tester, medication: med);

      expect(find.text('Tối đa 4 lần/ngày'), findsOneWidget);
      expect(
        find.text(
          'Uống khi cần thiết theo chỉ định. Không có giờ nhắc cố định.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('thuốc đã ngừng hiển thị badge Đã ngừng và nút Tiếp tục dùng thuốc này',
        (tester) async {
      final med = _medication(
        name: 'Thuốc Cũ',
        status: MedicationStatus.stopped,
      );

      await _mountDetailScreen(tester, medication: med);

      expect(find.text('Đã ngừng'), findsOneWidget);
      expect(find.text('Tiếp tục dùng thuốc này'), findsOneWidget);
      expect(find.text('Tạm ngừng thuốc này'), findsNothing);
    });

    testWidgets('thao tác tạm ngừng thuốc hỏi xác nhận; huỷ thì giữ nguyên',
        (tester) async {
      final med = _medication(id: 'm1', name: 'Thuốc Đang Dùng');
      final (repo, _) = await _mountDetailScreen(tester, medication: med);

      await tester.tap(find.text('Tạm ngừng thuốc này'));
      await tester.pumpAndSettle();

      expect(find.text('Ngừng dùng thuốc?'), findsOneWidget);
      expect(
        find.textContaining('Thuốc "Thuốc Đang Dùng" sẽ chuyển vào danh sách Đã ngừng'),
        findsOneWidget,
      );

      // Bấm Huỷ
      await tester.tap(find.text('Huỷ'));
      await tester.pumpAndSettle();

      expect(repo.stopCalls, isEmpty);
      expect(find.text('Đang dùng'), findsOneWidget);
    });

    testWidgets(
        'thao tác tạm ngừng thuốc gặp lỗi mạng hiển thị SnackBar lỗi và giữ nguyên trạng thái',
        (tester) async {
      final med = _medication(id: 'm1', name: 'Thuốc Đang Dùng');
      final repo = _TestMedicationRepo(seed: [med])
        ..failNextStop = const MedicationFailure(MedicationFailureKind.network);

      await _mountDetailScreen(tester, medication: med, repo: repo);

      await tester.tap(find.text('Tạm ngừng thuốc này'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Xác nhận ngừng'));
      await tester.pumpAndSettle();

      // Bị lỗi mạng: hiện SnackBar tiếng Việt
      expect(
        find.text('Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.'),
        findsOneWidget,
      );
      // Trạng thái vẫn là Đang dùng
      expect(find.text('Đang dùng'), findsOneWidget);
      expect(find.text('Tạm ngừng thuốc này'), findsOneWidget);
    });
  });
}
