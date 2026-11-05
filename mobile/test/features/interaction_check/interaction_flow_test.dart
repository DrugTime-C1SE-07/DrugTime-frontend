import 'package:drugtime_mobile/app/app.dart';
import 'package:drugtime_mobile/features/auth/data/repositories/in_memory_auth_repository.dart';
import 'package:drugtime_mobile/features/auth/domain/entities/auth_session.dart';
import 'package:drugtime_mobile/features/auth/presentation/state/auth_controller.dart';
import 'package:drugtime_mobile/features/interaction_check/data/repositories/in_memory_interaction_check_repository.dart';
import 'package:drugtime_mobile/features/interaction_check/domain/entities/interaction_check_result.dart';
import 'package:drugtime_mobile/features/medication/data/repositories/in_memory_medication_repository.dart';
import 'package:drugtime_mobile/features/medication/domain/entities/medication.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class NumericCatalogMedicationRepository extends InMemoryMedicationRepository {
  NumericCatalogMedicationRepository({super.seed});

  @override
  Future<List<DrugCatalogItem>> searchCatalog(String query) async {
    return const [
      DrugCatalogItem(
        id: '102',
        name: 'Amlor 5mg',
        activeIngredient: 'Amlodipin',
        strength: '5 mg',
        dosageForm: 'Viên nén',
      ),
      DrugCatalogItem(
        id: '201',
        name: 'Paracetamol 500mg',
        activeIngredient: 'Paracetamol',
        strength: '500 mg',
        dosageForm: 'Viên nén',
      ),
    ];
  }
}

AuthController signedInAuth({String userId = 'patient-uuid-1'}) => AuthController(
      InMemoryAuthRepository(
        simulatedDelay: Duration.zero,
        initialSession: AuthSession(
          userId: userId,
          accessToken: 'test-token',
          expiresAt: DateTime.now().add(const Duration(days: 10)),
          profileComplete: true,
        ),
      ),
    );

Future<void> _confirmDrugIfPresent(WidgetTester tester) async {
  final confirmBtn = find.text('Xác nhận thuốc');
  if (confirmBtn.evaluate().isNotEmpty) {
    await tester.tap(confirmBtn);
    await tester.pumpAndSettle();
  }
}

void main() {
  group('Interaction Check Flow on Add Medication', () {
    testWidgets(
        'shows warning dialog when interaction found, cancels on cancel, saves on confirm',
        (tester) async {
      const existingMed = Medication(
        id: 'user-med-1',
        catalogId: '101',
        name: 'Simvastatin 20mg',
        activeIngredient: 'Simvastatin',
        strength: '20 mg',
        unit: 'viên',
        dosePerIntake: 1,
        frequency: DoseFrequency.once,
        timing: IntakeTiming.afterMeal,
      );

      final medRepo = NumericCatalogMedicationRepository(seed: [existingMed]);
      final interactionRepo = InMemoryInteractionCheckRepository(
        onCheck: ({
          required String patientId,
          int? candidateMedicationId,
          double? candidateDoseAmount,
          String? candidateDoseUnit,
          List<int>? medicationIds,
        }) async {
          if (candidateMedicationId == 102) {
            return const InteractionCheckResult(
              status: InteractionCheckStatus.found,
              interactions: [
                InteractionFinding(
                  ingredientAId: 1,
                  ingredientAName: 'Simvastatin',
                  ingredientBId: 2,
                  ingredientBName: 'Amlodipin',
                  medicationAName: 'Simvastatin 20mg',
                  medicationBName: 'Amlor 5mg',
                  severityLevel: 2,
                  interactionType: 'phu_thuoc_lieu',
                  handlingType: 'can_theo_doi',
                  description: 'Amlodipin làm tăng nồng độ Simvastatin.',
                  warningMessage: '[THẬN TRỌNG] Tăng nguy cơ tổn thương cơ khi dùng cùng.',
                  source: 'Dược thư Quốc gia',
                )
              ],
              disclaimer: nfr03Disclaimer,
            );
          }
          return const InteractionCheckResult(
            status: InteractionCheckStatus.noneFound,
            interactions: [],
            disclaimer: nfr03Disclaimer,
          );
        },
      );

      await tester.pumpWidget(
        DrugTimeApp(
          authController: signedInAuth(),
          medicationRepository: medRepo,
          interactionCheckRepository: interactionRepo,
        ),
      );
      await tester.pumpAndSettle();

      // Mở màn hình Thêm thuốc
      await tester.tap(find.widgetWithText(FilledButton, 'Thêm'));
      await tester.pumpAndSettle();
      expect(find.text('Thêm thuốc mới'), findsOneWidget);

      // Chọn thuốc Amlor 5mg (id 102) từ danh mục
      await tester.tap(find.text('Tìm tên thuốc, hoạt chất…'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'amlor');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Amlor 5mg'));
      await tester.pumpAndSettle();
      await _confirmDrugIfPresent(tester);

      // Bấm Lưu thuốc
      await tester.scrollUntilVisible(
        find.text('Lưu thuốc'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Lưu thuốc'));
      await tester.pumpAndSettle();

      // Hộp thoại cảnh báo xuất hiện
      expect(find.text('CẦN THẬN TRỌNG PHỐI HỢP'), findsOneWidget);
      expect(find.text(nfr03Disclaimer), findsOneWidget);
      expect(find.textContaining('Amlodipin làm tăng nồng độ Simvastatin'), findsOneWidget);

      // Nhấn "Quay lại chỉnh sửa"
      await tester.tap(find.text('Quay lại chỉnh sửa'));
      await tester.pumpAndSettle();

      // Vẫn đang ở màn hình Thêm thuốc
      expect(find.text('Thêm thuốc mới'), findsOneWidget);

      // Bấm Lưu thuốc lần 2
      await tester.tap(find.text('Lưu thuốc'));
      await tester.pumpAndSettle();

      // Hộp thoại cảnh báo xuất hiện lại, lần này bấm "Đã hiểu & Tiếp tục"
      expect(find.text('CẦN THẬN TRỌNG PHỐI HỢP'), findsOneWidget);
      await tester.tap(find.text('Đã hiểu & Tiếp tục'));
      await tester.pumpAndSettle();

      // Đã lưu thành công và quay về danh sách thuốc
      expect(find.text('Amlor 5mg'), findsOneWidget);
      expect(find.text('Simvastatin 20mg'), findsOneWidget);
    });

    testWidgets('saves directly without dialog when no interaction found',
        (tester) async {
      final medRepo = NumericCatalogMedicationRepository(seed: []);
      final interactionRepo = InMemoryInteractionCheckRepository(
        stubResult: const InteractionCheckResult(
          status: InteractionCheckStatus.noneFound,
          interactions: [],
          disclaimer: nfr03Disclaimer,
        ),
      );

      await tester.pumpWidget(
        DrugTimeApp(
          authController: signedInAuth(userId: 'patient-uuid-2'),
          medicationRepository: medRepo,
          interactionCheckRepository: interactionRepo,
        ),
      );
      await tester.pumpAndSettle();

      // Khi danh sách trống, bấm nút Thêm thuốc mới ở giữa
      await tester.tap(find.widgetWithText(FilledButton, 'Thêm thuốc mới'));
      await tester.pumpAndSettle();
      expect(find.text('Thêm thuốc mới'), findsOneWidget);

      // Chọn thuốc Paracetamol 500mg
      await tester.tap(find.text('Tìm tên thuốc, hoạt chất…'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'para');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Paracetamol 500mg'));
      await tester.pumpAndSettle();
      await _confirmDrugIfPresent(tester);

      // Bấm Lưu thuốc
      await tester.scrollUntilVisible(
        find.text('Lưu thuốc'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Lưu thuốc'));
      await tester.pumpAndSettle();

      // Không xuất hiện dialog cảnh báo
      expect(find.text('CẦN THẬN TRỌNG PHỐI HỢP'), findsNothing);
      expect(find.text('CẢNH BÁO CHỐNG CHỈ ĐỊNH'), findsNothing);

      // Thuốc được lưu trực tiếp và hiển thị ở danh sách
      expect(find.text('Paracetamol 500mg'), findsOneWidget);
    });

    testWidgets(
        'shows insufficient data dialog when candidate lacks active ingredients',
        (tester) async {
      final medRepo = NumericCatalogMedicationRepository(seed: []);
      final interactionRepo = InMemoryInteractionCheckRepository(
        stubResult: const InteractionCheckResult(
          status: InteractionCheckStatus.insufficientData,
          interactions: [],
          insufficientDataMedications: [
            InsufficientDataMedication(
              medicationId: 201,
              medicationName: 'Paracetamol 500mg',
              reason: 'Chưa có hoạt chất liên kết trong dược thư',
            ),
          ],
          disclaimer: nfr03Disclaimer,
        ),
      );

      await tester.pumpWidget(
        DrugTimeApp(
          authController: signedInAuth(userId: 'patient-uuid-3'),
          medicationRepository: medRepo,
          interactionCheckRepository: interactionRepo,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Thêm thuốc mới'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tìm tên thuốc, hoạt chất…'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'para');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Paracetamol 500mg'));
      await tester.pumpAndSettle();
      await _confirmDrugIfPresent(tester);

      await tester.scrollUntilVisible(
        find.text('Lưu thuốc'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Lưu thuốc'));
      await tester.pumpAndSettle();

      // Xuất hiện dialog thiếu dữ liệu
      expect(find.text('THIẾU DỮ LIỆU ĐỐI SOÁT TƯƠNG TÁC'), findsOneWidget);
      expect(find.textContaining('Chưa có hoạt chất liên kết'), findsOneWidget);

      // Bấm "Quay lại chỉnh sửa"
      await tester.tap(find.text('Quay lại chỉnh sửa'));
      await tester.pumpAndSettle();
      expect(find.text('Thêm thuốc mới'), findsOneWidget);

      // Bấm Lưu lần 2 và chọn "Vẫn tiếp tục lưu"
      await tester.tap(find.text('Lưu thuốc'));
      await tester.pumpAndSettle();
      expect(find.text('THIẾU DỮ LIỆU ĐỐI SOÁT TƯƠNG TÁC'), findsOneWidget);
      await tester.tap(find.text('Vẫn tiếp tục lưu'));
      await tester.pumpAndSettle();

      // Lưu thành công
      expect(find.text('Paracetamol 500mg'), findsOneWidget);
    });

    testWidgets(
        'shows both interaction findings and insufficient data warnings on mixed response',
        (tester) async {
      const existingMed = Medication(
        id: 'user-med-1',
        catalogId: '101',
        name: 'Simvastatin 20mg',
        activeIngredient: 'Simvastatin',
        strength: '20 mg',
        unit: 'viên',
        dosePerIntake: 1,
        frequency: DoseFrequency.once,
        timing: IntakeTiming.afterMeal,
      );

      final medRepo = NumericCatalogMedicationRepository(seed: [existingMed]);
      final interactionRepo = InMemoryInteractionCheckRepository(
        onCheck: ({
          required String patientId,
          int? candidateMedicationId,
          double? candidateDoseAmount,
          String? candidateDoseUnit,
          List<int>? medicationIds,
        }) async {
          return const InteractionCheckResult(
            status: InteractionCheckStatus.found,
            interactions: [
              InteractionFinding(
                ingredientAId: 1,
                ingredientAName: 'Simvastatin',
                ingredientBId: 2,
                ingredientBName: 'Amlodipin',
                medicationAName: 'Simvastatin 20mg',
                medicationBName: 'Amlor 5mg',
                severityLevel: 2,
                interactionType: 'phu_thuoc_lieu',
                handlingType: 'can_theo_doi',
                description: 'Amlodipin làm tăng nồng độ Simvastatin.',
                warningMessage: '[THẬN TRỌNG] Tăng nguy cơ tổn thương cơ khi dùng cùng.',
                source: 'Dược thư Quốc gia',
              )
            ],
            insufficientDataMedications: [
              InsufficientDataMedication(
                medicationId: 888,
                medicationName: 'Thuốc nam gia truyền',
                reason: 'Chưa liên kết dữ liệu hoạt chất',
              ),
            ],
            disclaimer: nfr03Disclaimer,
          );
        },
      );

      await tester.pumpWidget(
        DrugTimeApp(
          authController: signedInAuth(userId: 'patient-uuid-5'),
          medicationRepository: medRepo,
          interactionCheckRepository: interactionRepo,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Thêm'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tìm tên thuốc, hoạt chất…'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'amlor');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Amlor 5mg'));
      await tester.pumpAndSettle();
      await _confirmDrugIfPresent(tester);

      await tester.scrollUntilVisible(
        find.text('Lưu thuốc'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Lưu thuốc'));
      await tester.pumpAndSettle();

      // Kiểm tra hộp thoại hiển thị trọn vẹn:
      // 1. Cảnh báo tương tác
      expect(find.text('CẦN THẬN TRỌNG PHỐI HỢP'), findsOneWidget);
      expect(find.textContaining('Amlodipin làm tăng nồng độ Simvastatin'), findsOneWidget);

      // 2. Không bị che mất cảnh báo thuốc thiếu dữ liệu
      expect(find.text('Thuốc chưa đủ dữ liệu hoạt chất để đối soát:'), findsOneWidget);
      expect(find.textContaining('Thuốc nam gia truyền'), findsOneWidget);

      // 3. Disclaimer pháp lý
      await tester.scrollUntilVisible(
        find.text(nfr03Disclaimer),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text(nfr03Disclaimer), findsOneWidget);

      // Bấm "Đã hiểu & Tiếp tục"
      await tester.tap(find.text('Đã hiểu & Tiếp tục'));
      await tester.pumpAndSettle();

      expect(find.text('Amlor 5mg'), findsOneWidget);
    });

    testWidgets(
        'shows network error dialog when interaction check throws, user can cancel or proceed',
        (tester) async {
      final medRepo = NumericCatalogMedicationRepository(seed: []);
      final interactionRepo = InMemoryInteractionCheckRepository(
        onCheck: ({
          required String patientId,
          int? candidateMedicationId,
          double? candidateDoseAmount,
          String? candidateDoseUnit,
          List<int>? medicationIds,
        }) async {
          throw Exception('Network connection failed');
        },
      );

      await tester.pumpWidget(
        DrugTimeApp(
          authController: signedInAuth(userId: 'patient-uuid-4'),
          medicationRepository: medRepo,
          interactionCheckRepository: interactionRepo,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Thêm thuốc mới'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tìm tên thuốc, hoạt chất…'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'para');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Paracetamol 500mg'));
      await tester.pumpAndSettle();
      await _confirmDrugIfPresent(tester);

      await tester.scrollUntilVisible(
        find.text('Lưu thuốc'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Lưu thuốc'));
      await tester.pumpAndSettle();

      // Xuất hiện dialog lỗi mạng
      expect(find.text('KHÔNG THỂ KIỂM TRA TƯƠNG TÁC'), findsOneWidget);
      expect(find.textContaining('Không thể kết nối đến máy chủ'), findsOneWidget);

      // Bấm "Quay lại"
      await tester.tap(find.text('Quay lại'));
      await tester.pumpAndSettle();
      expect(find.text('Thêm thuốc mới'), findsOneWidget);

      // Bấm Lưu lần 2 và chọn "Vẫn tiếp tục lưu"
      await tester.tap(find.text('Lưu thuốc'));
      await tester.pumpAndSettle();
      expect(find.text('KHÔNG THỂ KIỂM TRA TƯƠNG TÁC'), findsOneWidget);
      await tester.tap(find.text('Vẫn tiếp tục lưu'));
      await tester.pumpAndSettle();

      // Lưu thành công
      expect(find.text('Paracetamol 500mg'), findsOneWidget);
    });
  });
}
