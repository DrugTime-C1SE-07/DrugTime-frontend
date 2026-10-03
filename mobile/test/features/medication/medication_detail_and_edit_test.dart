import 'package:drugtime_mobile/app/app.dart';
import 'package:drugtime_mobile/features/auth/data/repositories/in_memory_auth_repository.dart';
import 'package:drugtime_mobile/features/auth/domain/entities/auth_session.dart';
import 'package:drugtime_mobile/features/auth/presentation/state/auth_controller.dart';
import 'package:drugtime_mobile/features/medication/data/models/medication_api_mapper.dart';
import 'package:drugtime_mobile/features/medication/data/repositories/in_memory_medication_repository.dart';
import 'package:drugtime_mobile/features/medication/domain/entities/medication_failure.dart';
import 'package:drugtime_mobile/features/medication/presentation/screens/edit_medication_screen.dart';
import 'package:drugtime_mobile/features/medication/presentation/screens/medication_detail_screen.dart';
import 'package:drugtime_mobile/features/medication/presentation/screens/my_medications_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'medication_screens_test.dart' show RecordingRepository;


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
      await tester.tap(find.text('Trước ăn'));
      await tester.pumpAndSettle();

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
}
