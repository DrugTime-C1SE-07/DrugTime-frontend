import 'package:drugtime_mobile/app/router.dart';
import 'package:drugtime_mobile/features/drug_food_warning/data/repositories/in_memory_food_interaction_repository.dart';
import 'package:drugtime_mobile/features/drug_food_warning/domain/entities/drug_food_interaction.dart';
import 'package:drugtime_mobile/features/interaction_check/domain/entities/interaction_check_result.dart';
import 'package:drugtime_mobile/features/interaction_check/domain/repositories/interaction_check_repository.dart';
import 'package:drugtime_mobile/features/medication/domain/entities/medication.dart';
import 'package:drugtime_mobile/features/medication/domain/entities/medication_failure.dart';
import 'package:drugtime_mobile/features/medication/presentation/screens/add_medication_screen.dart';
import 'package:drugtime_mobile/features/medication/presentation/screens/medication_added_screen.dart';
import 'package:drugtime_mobile/features/medication/presentation/state/medication_controller.dart';
import 'package:drugtime_mobile/features/medication/presentation/widgets/drug_info_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'medication_screens_test.dart' show RecordingRepository;

const _drug = DrugCatalogItem(
  id: '1007',
  name: 'Paracetamol 500mg',
  activeIngredient: 'Paracetamol',
  strength: '500mg',
  dosageForm: 'Viên nén',
);

class _Interactions implements InteractionCheckRepository {
  _Interactions(this.answer);
  final Future<InteractionCheckResult> Function() answer;

  @override
  Future<InteractionCheckResult> checkPatientInteractions({
    required String patientId,
    int? candidateMedicationId,
    double? candidateDoseAmount,
    String? candidateDoseUnit,
    List<int>? medicationIds,
  }) =>
      answer();
}

const _none = InteractionCheckResult(
    status: InteractionCheckStatus.noneFound, interactions: []);

const _finding = InteractionFinding(
  ingredientAId: 1,
  ingredientAName: 'Paracetamol',
  ingredientBName: 'Warfarin',
  severityLevel: 2,
  interactionType: 'pk',
  handlingType: 'monitor',
  description: 'Tăng tác dụng chống đông',
  warningMessage: 'Theo dõi INR',
  source: 'Dược thư Quốc gia',
);

final _noFood = InMemoryFoodInteractionRepository(
  stubResult: const DrugFoodInteractionResult(
      status: FoodInteractionStatus.noneFound, warnings: []),
);

void main() {
  late RecordingRepository repo;

  Future<void> open(WidgetTester tester,
      {Future<InteractionCheckResult> Function()? interactions,
      bool scanned = true,
      double width = 375}) async {
    await tester.binding.setSurfaceSize(Size(width, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    repo = RecordingRepository();
    final controller = MedicationController(repo,
        interactionCheckRepository:
            _Interactions(interactions ?? () async => _none));
    addTearDown(controller.dispose);
    await controller.load();
    await tester.pumpWidget(MedicationScope(
      controller: controller,
      child: MaterialApp(
        routes: {
          AppRoutes.home: (_) => const Scaffold(body: Text('HOME')),
          AppRoutes.scanMedication: (_) => const Scaffold(body: Text('SCAN-ENTRY')),
          AppRoutes.addMedication: (_) => const Scaffold(body: Text('ADD-ENTRY')),
        },
        initialRoute: AppRoutes.home,
      ),
    ));
    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    nav.push(MaterialPageRoute<void>(
        builder: (_) => AddMedicationScreen(
            scannedDrug: scanned ? _drug : null,
            foodInteractionRepository: _noFood)));
    await tester.pumpAndSettle();
  }

  Future<void> toConfirm(WidgetTester tester) async {
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();
  }

  testWidgets('bước 2 "Tiếp tục" sang M3, chưa lưu (AC9)', (tester) async {
    await open(tester);
    expect(find.text('Bước 2/3 · Lịch uống'), findsOneWidget);
    await toConfirm(tester);
    expect(find.byKey(const Key('medication-confirm-view')), findsOneWidget);
    expect(find.text('Bước 3/3 · Xác nhận'), findsOneWidget);
    expect(repo.addCalls, isEmpty);
  });

  testWidgets('bước 2 không còn chip hàm lượng; nút (i) mở thông tin thuốc (AC6)',
      (tester) async {
    await open(tester);
    expect(find.byType(Chip), findsNothing);
    expect(find.text('500 mg · Viên nén'), findsOneWidget);
    await tester.tap(find.byTooltip('Xem thông tin thuốc'));
    await tester.pumpAndSettle();
    expect(find.byType(DrugInfoSheet), findsOneWidget);
  });

  testWidgets('M3 hiện đủ thông tin cần rà và "Sửa" giữ dữ liệu (AC10, QD-39)',
      (tester) async {
    final handle = tester.ensureSemantics();
    await open(tester);
    await tester.tap(find.byTooltip('Tăng liều'));
    await tester.pump();
    await toConfirm(tester);
    expect(find.text('Paracetamol 500mg'), findsOneWidget);
    for (final row in [
      'Hàm lượng: 500 mg',
      'Mỗi lần: 2 viên',
      'Giờ uống: 08:00 · 20:00',
      'Uống khi nào: Sau ăn',
      'Tổng mỗi ngày: 4 viên',
    ]) {
      expect(find.bySemanticsLabel(row), findsOneWidget, reason: row);
    }
    await tester.tap(find.byKey(const Key('confirm-edit')));
    await tester.pumpAndSettle();
    expect(find.text('Bước 2/3 · Lịch uống'), findsOneWidget);
    expect(find.text('2 viên'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('bấm "Thêm thuốc" hai lần chỉ gửi một lần, cùng client_uuid (AC12)',
      (tester) async {
    await open(tester);
    await toConfirm(tester);
    final add = tester
        .widget<ButtonStyleButton>(find.byKey(const Key('confirm-add')))
        .onPressed!;
    add();
    add();
    await tester.pumpAndSettle();
    expect(repo.addCalls, hasLength(1));
    expect(find.byType(MedicationAddedScreen), findsOneWidget);
  });

  testWidgets('lưu lỗi ở lại M3, báo lỗi, giữ dữ liệu; lưu lại cùng client_uuid (AC15)',
      (tester) async {
    await open(tester);
    await toConfirm(tester);
    repo.failNextAdd = const MedicationFailure(MedicationFailureKind.network);
    await tester.tap(find.byKey(const Key('confirm-add')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('medication-confirm-view')), findsOneWidget);
    expect(find.text('Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.'),
        findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm-add')));
    await tester.pumpAndSettle();
    expect(repo.addCalls, hasLength(2));
    expect(repo.addCalls[0].$2, repo.addCalls[1].$2);
    expect(find.byType(MedicationAddedScreen), findsOneWidget);
  });

  group('M4 hiện đúng kết quả kiểm tra tương tác (AC13, QD-37)', () {
    Future<String> outcomeText(WidgetTester tester) async {
      final chip = find.byKey(const Key('interaction-outcome'));
      expect(chip, findsOneWidget);
      return tester
          .widgetList<Text>(find.descendant(of: chip, matching: find.byType(Text)))
          .single
          .data!;
    }

    Future<void> proceedInDialog(WidgetTester tester) async {
      final proceed = find.text('Vẫn tiếp tục lưu');
      if (proceed.evaluate().isNotEmpty) {
        await tester.tap(proceed.last);
      } else {
        await tester.tap(find.byType(ElevatedButton).last);
      }
      await tester.pumpAndSettle();
    }

    testWidgets('đã kiểm tra, không thấy', (tester) async {
      await open(tester);
      await toConfirm(tester);
      await tester.tap(find.byKey(const Key('confirm-add')));
      await tester.pumpAndSettle();
      expect(await outcomeText(tester), 'Không phát hiện tương tác');
    });

    testWidgets('có tương tác, người dùng vẫn thêm', (tester) async {
      // Hộp thoại cảnh báo có sẵn tràn 64 px ở bề ngang 375 (lỗi cũ, xem 04 Phát sinh).
      await open(tester,
          width: 520,
          interactions: () async => const InteractionCheckResult(
              status: InteractionCheckStatus.found, interactions: [_finding]));
      await toConfirm(tester);
      await tester.tap(find.byKey(const Key('confirm-add')));
      await tester.pumpAndSettle();
      await proceedInDialog(tester);
      expect(await outcomeText(tester), 'Có tương tác — bạn đã xác nhận');
    });

    testWidgets('chưa đủ dữ liệu không bao giờ thành "không phát hiện"',
        (tester) async {
      await open(tester,
          interactions: () async => const InteractionCheckResult(
              status: InteractionCheckStatus.insufficientData,
              interactions: []));
      await toConfirm(tester);
      await tester.tap(find.byKey(const Key('confirm-add')));
      await tester.pumpAndSettle();
      await proceedInDialog(tester);
      expect(await outcomeText(tester), 'Chưa đủ dữ liệu để kiểm tra');
    });

    testWidgets('lỗi mạng khi kiểm tra mà vẫn thêm thì "chưa kiểm tra được"',
        (tester) async {
      await open(tester,
          interactions: () async =>
              throw const MedicationFailure(MedicationFailureKind.network));
      await toConfirm(tester);
      await tester.tap(find.byKey(const Key('confirm-add')));
      await tester.pumpAndSettle();
      await proceedInDialog(tester);
      expect(await outcomeText(tester), 'Chưa kiểm tra được tương tác');
    });
  });

  testWidgets('M4 "Về trang chủ" về Trang chủ; "Thêm thuốc khác" mở lại luồng (AC14)',
      (tester) async {
    await open(tester);
    await toConfirm(tester);
    await tester.tap(find.byKey(const Key('confirm-add')));
    await tester.pumpAndSettle();
    expect(find.text('Đã thêm thuốc!'), findsOneWidget);
    expect(find.textContaining('Paracetamol 500mg · 2 lần mỗi ngày'), findsOneWidget);
    await tester.tap(find.byKey(const Key('added-add-another')));
    await tester.pumpAndSettle();
    expect(find.text('SCAN-ENTRY'), findsOneWidget);
    expect(find.byType(AddMedicationScreen), findsNothing);
  });

  testWidgets('M4 "Về trang chủ" bỏ cả luồng thêm thuốc khỏi stack (AC14)',
      (tester) async {
    await open(tester, scanned: false);
    // Luồng tìm tay: chọn thuốc trong sheet danh mục.
    await tester.tap(find.text('Tìm tên thuốc, hoạt chất…'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'para');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paracetamol 500mg').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xác nhận thuốc'));
    await tester.pumpAndSettle();
    await toConfirm(tester);
    await tester.tap(find.byKey(const Key('confirm-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('added-go-home')));
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
    expect(find.byType(MedicationAddedScreen), findsNothing);
    expect(tester.state<NavigatorState>(find.byType(Navigator)).canPop(), isFalse);
  });
}
