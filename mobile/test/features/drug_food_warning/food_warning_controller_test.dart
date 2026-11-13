import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/features/drug_food_warning/data/repositories/in_memory_food_interaction_repository.dart';
import 'package:drugtime_mobile/features/drug_food_warning/presentation/controllers/food_warning_controller.dart';

void main() {
  group('FoodWarningController', () {
    late InMemoryFoodInteractionRepository repository;
    late FoodWarningController controller;

    setUp(() {
      repository = InMemoryFoodInteractionRepository();
      controller = FoodWarningController(repository);
    });

    test('Initial state is FoodWarningInitial', () {
      expect(controller.state, isA<FoodWarningInitial>());
      expect(controller.isLoading, isFalse);
      expect(controller.result, isNull);
    });

    test('Transitions to FoodWarningSuccess when warnings found', () async {
      final states = <FoodWarningState>[];
      controller.addListener(() => states.add(controller.state));

      final result = await controller.checkFoodInteractions(
        patientId: 'patient-1',
        medicationName: 'Atorvastatin 20mg',
        activeIngredient: 'Atorvastatin',
      );

      expect(result.hasWarnings, isTrue);
      expect(states.length, 2);
      expect(states[0], isA<FoodWarningLoading>());
      expect(states[1], isA<FoodWarningSuccess>());
      expect(controller.state, isA<FoodWarningSuccess>());
      expect(controller.result?.warnings.length, 1);
      expect(controller.isLoading, isFalse);
    });

    test('Transitions to FoodWarningEmpty when no warnings found', () async {
      final states = <FoodWarningState>[];
      controller.addListener(() => states.add(controller.state));

      final result = await controller.checkFoodInteractions(
        patientId: 'patient-1',
        medicationName: 'Paracetamol 500mg',
        activeIngredient: 'Paracetamol',
      );

      expect(result.hasWarnings, isFalse);
      expect(states.length, 2);
      expect(states[0], isA<FoodWarningLoading>());
      expect(states[1], isA<FoodWarningEmpty>());
      expect(controller.state, isA<FoodWarningEmpty>());
      expect(controller.result, isNull);
    });

    test('Transitions to FoodWarningError when repository throws exception', () async {
      repository.onCheck = ({
        required String patientId,
        String? medicationName,
        String? activeIngredient,
        int? catalogId,
        List<int>? medicationIds,
      }) async {
        throw Exception('Network timeout');
      };

      final states = <FoodWarningState>[];
      controller.addListener(() => states.add(controller.state));

      expect(
        () => controller.checkFoodInteractions(
          patientId: 'patient-1',
          medicationName: 'Atorvastatin',
        ),
        throwsException,
      );

      // Wait a microtask for listener notifications
      await Future.delayed(Duration.zero);

      expect(states.length, 2);
      expect(states[0], isA<FoodWarningLoading>());
      expect(states[1], isA<FoodWarningError>());
      final errorState = states[1] as FoodWarningError;
      expect(errorState.message, contains('Network timeout'));
    });

    test('reset clears state back to FoodWarningInitial', () async {
      await controller.checkFoodInteractions(
        patientId: 'patient-1',
        medicationName: 'Atorvastatin',
      );
      expect(controller.state, isA<FoodWarningSuccess>());

      controller.reset();
      expect(controller.state, isA<FoodWarningInitial>());
    });
  });
}
