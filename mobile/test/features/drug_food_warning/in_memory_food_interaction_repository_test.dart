import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/features/drug_food_warning/data/repositories/in_memory_food_interaction_repository.dart';
import 'package:drugtime_mobile/features/drug_food_warning/domain/entities/drug_food_interaction.dart';

void main() {
  group('InMemoryFoodInteractionRepository', () {
    late InMemoryFoodInteractionRepository repository;

    setUp(() {
      repository = InMemoryFoodInteractionRepository();
    });

    test('Atorvastatin matches grapefruit interaction (Level 2 - Severe)', () async {
      final result = await repository.checkFoodInteractions(
        patientId: 'patient-1',
        medicationName: 'Atorvastatin 20mg',
        activeIngredient: 'Atorvastatin',
      );

      expect(result.status, FoodInteractionStatus.found);
      expect(result.hasWarnings, isTrue);
      expect(result.warnings.length, 1);
      final warning = result.warnings.first;
      expect(warning.severity, FoodInteractionSeverity.severe);
      expect(warning.severityLevel, 2);
      expect(warning.foodName, contains('Bưởi chùm'));
      expect(warning.foodCategory, 'Trái cây có múi');
      expect(warning.mechanismAndRisk, contains('CYP3A4'));
      expect(warning.recommendation, contains('Tránh ăn bưởi chùm'));
      expect(warning.source, contains('Dược thư Quốc gia Việt Nam'));
    });

    test('Metformin matches alcohol interaction (Level 1 - Contraindicated)', () async {
      final result = await repository.checkFoodInteractions(
        patientId: 'patient-1',
        medicationName: 'Metformin 500mg',
        activeIngredient: 'Metformin',
      );

      expect(result.status, FoodInteractionStatus.found);
      expect(result.hasWarnings, isTrue);
      expect(result.hasContraindication, isTrue);
      expect(result.highestSeverityLevel, 1);
      final warning = result.warnings.first;
      expect(warning.severity, FoodInteractionSeverity.contraindicated);
      expect(warning.isContraindicated, isTrue);
      expect(warning.foodName, contains('Rượu bia'));
      expect(warning.mechanismAndRisk, contains('acid lactic'));
    });

    test('Ciprofloxacin matches dairy interaction (Level 3 - Moderate)', () async {
      final result = await repository.checkFoodInteractions(
        patientId: 'patient-1',
        medicationName: 'Ciprofloxacin 500mg',
        activeIngredient: 'Ciprofloxacin',
      );

      expect(result.status, FoodInteractionStatus.found);
      expect(result.hasWarnings, isTrue);
      final warning = result.warnings.first;
      expect(warning.severity, FoodInteractionSeverity.moderate);
      expect(warning.severityLevel, 3);
      expect(warning.foodName, contains('Sữa'));
      expect(warning.mechanismAndRisk, contains('chelate'));
      expect(warning.timingAdvice, contains('2 giờ'));
    });

    test('Warfarin matches Vitamin K interaction (Level 4 - Minor)', () async {
      final result = await repository.checkFoodInteractions(
        patientId: 'patient-1',
        medicationName: 'Warfarin 5mg',
        activeIngredient: 'Warfarin',
      );

      expect(result.status, FoodInteractionStatus.found);
      expect(result.hasWarnings, isTrue);
      final warning = result.warnings.first;
      expect(warning.severity, FoodInteractionSeverity.minor);
      expect(warning.severityLevel, 4);
      expect(warning.foodName, contains('Rau lá xanh'));
      expect(warning.mechanismAndRisk, contains('Vitamin K'));
      expect(warning.recommendation, contains('ổn định'));
    });

    test('Matching by catalogId works correctly', () async {
      final result = await repository.checkFoodInteractions(
        patientId: 'patient-1',
        catalogId: 101, // Atorvastatin
      );

      expect(result.status, FoodInteractionStatus.found);
      expect(result.warnings.first.activeIngredient, 'Atorvastatin');
    });

    test('Matching by medicationIds list works correctly', () async {
      final result = await repository.checkFoodInteractions(
        patientId: 'patient-1',
        medicationIds: [102, 103], // Metformin and Ciprofloxacin
      );

      expect(result.status, FoodInteractionStatus.found);
      expect(result.warnings.length, 2);
      expect(
        result.warnings.map((w) => w.activeIngredient).toSet(),
        containsAll(['Metformin', 'Ciprofloxacin']),
      );
    });

    test('Returns noneFound when drug has no food interaction', () async {
      final result = await repository.checkFoodInteractions(
        patientId: 'patient-1',
        medicationName: 'Paracetamol 500mg',
        activeIngredient: 'Paracetamol',
      );

      expect(result.status, FoodInteractionStatus.noneFound);
      expect(result.hasWarnings, isFalse);
      expect(result.warnings, isEmpty);
      expect(result.highestSeverityLevel, 0);
    });

    test('stubResult overrides default behavior', () async {
      repository.stubResult = const DrugFoodInteractionResult(
        status: FoodInteractionStatus.insufficientData,
        warnings: [],
        insufficientDataMedications: ['Thuốc XYZ'],
      );

      final result = await repository.checkFoodInteractions(
        patientId: 'patient-1',
        medicationName: 'Atorvastatin',
      );

      expect(result.status, FoodInteractionStatus.insufficientData);
      expect(result.insufficientDataMedications, contains('Thuốc XYZ'));
    });

    test('onCheck callback overrides default behavior', () async {
      repository.onCheck = ({
        required String patientId,
        String? medicationName,
        String? activeIngredient,
        int? catalogId,
        List<int>? medicationIds,
      }) async {
        return const DrugFoodInteractionResult(
          status: FoodInteractionStatus.noneFound,
          warnings: [],
          disclaimer: 'Custom disclaimer',
        );
      };

      final result = await repository.checkFoodInteractions(
        patientId: 'patient-1',
        medicationName: 'Atorvastatin',
      );

      expect(result.status, FoodInteractionStatus.noneFound);
      expect(result.disclaimer, 'Custom disclaimer');
    });
  });
}
