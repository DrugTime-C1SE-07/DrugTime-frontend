import 'package:drugtime_mobile/app/app.dart';
import 'package:drugtime_mobile/features/medication/data/repositories/in_memory_medication_repository.dart';
import 'package:drugtime_mobile/features/medication/presentation/screens/add_medication_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
    DrugTimeApp(medicationRepository: repository ?? InMemoryMedicationRepository()),
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
