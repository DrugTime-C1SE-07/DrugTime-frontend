import 'package:drugtime_mobile/features/auth/data/repositories/in_memory_auth_repository.dart';
import 'package:drugtime_mobile/features/auth/domain/entities/auth_session.dart';
import 'package:drugtime_mobile/features/auth/presentation/state/auth_controller.dart';
import 'package:drugtime_mobile/features/drug_food_warning/data/repositories/in_memory_food_interaction_repository.dart';
import 'package:drugtime_mobile/features/interaction_check/data/repositories/in_memory_interaction_check_repository.dart';
import 'package:drugtime_mobile/features/medication/data/repositories/in_memory_medication_repository.dart';
import 'package:drugtime_mobile/features/medication/domain/entities/medication.dart';
import 'package:drugtime_mobile/features/medication/presentation/screens/add_medication_screen.dart';
import 'package:drugtime_mobile/features/medication/presentation/screens/edit_medication_screen.dart';
import 'package:drugtime_mobile/features/medication/presentation/state/medication_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FoodTestMedicationRepository extends InMemoryMedicationRepository {
  FoodTestMedicationRepository({super.seed});

  @override
  Future<List<DrugCatalogItem>> searchCatalog(String query) async {
    return const [
      DrugCatalogItem(
        id: '101',
        name: 'Atorvastatin 20mg',
        activeIngredient: 'Atorvastatin',
        strength: '20 mg',
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

AuthController _signedInAuth({String userId = 'patient-uuid-1'}) =>
    AuthController(
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
  group('Food Warning Flow on Add/Edit Medication', () {
    testWidgets(
        'AddMedicationScreen shows food warning dialog when food interaction found, cancels on back, saves on proceed',
        (tester) async {
      final medRepo = FoodTestMedicationRepository(seed: const []);
      final medController = MedicationController(
        medRepo,
        interactionCheckRepository: InMemoryInteractionCheckRepository(),
      );
      final authController = _signedInAuth();
      final foodRepo = InMemoryFoodInteractionRepository();

      await tester.pumpWidget(
        AuthScope(
          controller: authController,
          child: MedicationScope(
            controller: medController,
            child: MaterialApp(
              home: AddMedicationScreen(
                foodInteractionRepository: foodRepo,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open catalog sheet
      await tester.tap(find.text('Tìm tên thuốc, hoạt chất…'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'ator');
      await tester.pumpAndSettle();

      // Select Atorvastatin (matches grapefruit warning)
      await tester.tap(find.text('Atorvastatin 20mg'));
      await tester.pumpAndSettle();
      await _confirmDrugIfPresent(tester);

      // Scroll to Save button
      await tester.scrollUntilVisible(
        find.text('Lưu thuốc'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Lưu thuốc'));
      await tester.pumpAndSettle();

      // Food warning dialog should appear
      expect(find.text('TƯƠNG TÁC THỨC ĂN NGUY CƠ CAO'), findsOneWidget);
      expect(find.textContaining('Bưởi chùm'), findsOneWidget);

      // Tap "Quay lại chỉnh sửa" -> cancels save
      await tester.tap(find.byKey(const Key('food_warning_back_button')));
      await tester.pumpAndSettle();

      // Still on AddMedicationScreen, medication was not added
      expect(find.text('Thêm thuốc mới'), findsOneWidget);
      expect(medController.medications.any((m) => m.name == 'Atorvastatin 20mg'), isFalse);

      // Tap Save again
      await tester.tap(find.text('Lưu thuốc'));
      await tester.pumpAndSettle();

      // Tap "Tôi đã hiểu và tiếp tục" -> proceeds to save
      await tester.tap(find.byKey(const Key('food_warning_proceed_button')));
      await tester.pumpAndSettle();

      // Medication should now be saved!
      expect(medController.medications.any((m) => m.name == 'Atorvastatin 20mg'), isTrue);
    });

    testWidgets(
        'EditMedicationScreen triggers food warning dialog when saving medication with food interaction',
        (tester) async {
      const existing = Medication(
        id: 'med-atorvastatin-1',
        catalogId: '101',
        name: 'Atorvastatin 20mg',
        activeIngredient: 'Atorvastatin',
        strength: '20 mg',
        unit: 'viên',
        dosePerIntake: 1,
        frequency: DoseFrequency.once,
        timing: IntakeTiming.afterMeal,
      );

      final medRepo = InMemoryMedicationRepository(seed: [existing]);
      final medController = MedicationController(
        medRepo,
        interactionCheckRepository: InMemoryInteractionCheckRepository(),
      );
      await medController.load();

      final authController = _signedInAuth();
      final foodRepo = InMemoryFoodInteractionRepository();

      await tester.pumpWidget(
        AuthScope(
          controller: authController,
          child: MedicationScope(
            controller: medController,
            child: MaterialApp(
              home: EditMedicationScreen(
                medication: existing,
                foodInteractionRepository: foodRepo,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap "Lưu" button in EditMedicationScreen
      await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
      await tester.pumpAndSettle();

      // Food warning dialog should appear
      expect(find.text('TƯƠNG TÁC THỨC ĂN NGUY CƠ CAO'), findsOneWidget);
      expect(find.textContaining('Bưởi chùm'), findsOneWidget);

      // Tap "Tôi đã hiểu và tiếp tục"
      await tester.tap(find.byKey(const Key('food_warning_proceed_button')));
      await tester.pumpAndSettle();

      expect(find.text('TƯƠNG TÁC THỨC ĂN NGUY CƠ CAO'), findsNothing);
    });

    testWidgets(
        'AddMedicationScreen shows network error dialog when food check fails with exception',
        (tester) async {
      final medRepo = FoodTestMedicationRepository(seed: const []);
      final medController = MedicationController(
        medRepo,
        interactionCheckRepository: InMemoryInteractionCheckRepository(),
      );
      final authController = _signedInAuth();
      final foodRepo = InMemoryFoodInteractionRepository(
        onCheck: ({
          required String patientId,
          String? medicationName,
          String? activeIngredient,
          int? catalogId,
          List<int>? medicationIds,
        }) async {
          throw Exception('Connection failed');
        },
      );

      await tester.pumpWidget(
        AuthScope(
          controller: authController,
          child: MedicationScope(
            controller: medController,
            child: MaterialApp(
              home: AddMedicationScreen(
                foodInteractionRepository: foodRepo,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open catalog sheet & select drug
      await tester.tap(find.text('Tìm tên thuốc, hoạt chất…'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'ator');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Atorvastatin 20mg'));
      await tester.pumpAndSettle();
      await _confirmDrugIfPresent(tester);

      // Tap save
      await tester.scrollUntilVisible(
        find.text('Lưu thuốc'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Lưu thuốc'));
      await tester.pumpAndSettle();

      // Network error dialog should appear
      expect(find.text('Không thể kiểm tra thức ăn'), findsOneWidget);
      expect(find.text('Vẫn tiếp tục lưu'), findsOneWidget);

      // Tap "Vẫn tiếp tục lưu"
      await tester.tap(find.text('Vẫn tiếp tục lưu'));
      await tester.pumpAndSettle();

      // Saved successfully
      expect(medController.medications.any((m) => m.name == 'Atorvastatin 20mg'), isTrue);
    });
  });
}
