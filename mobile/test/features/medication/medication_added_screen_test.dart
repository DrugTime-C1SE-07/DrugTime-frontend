import 'package:drugtime_mobile/features/medication/domain/entities/medication.dart';
import 'package:drugtime_mobile/features/medication/presentation/screens/medication_added_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _med = Medication(
  id: '42',
  catalogId: '1007',
  name: 'Paracetamol 500mg',
  activeIngredient: 'Paracetamol',
  strength: '500mg',
  unit: 'viên',
  dosePerIntake: 1,
  frequency: DoseFrequency.twice,
  timing: IntakeTiming.afterMeal,
  times: [DoseTime(8, 0), DoseTime(20, 0)],
  pillShape: PillShape.capsule,
  pillColor: PillColor.orange,
);

void main() {
  for (final outcome in InteractionOutcome.values) {
    testWidgets('M4 trên màn 320 không tràn: ${outcome.name} (AC13)',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
          home: MedicationAddedScreen(
              medication: _med, outcome: outcome, addAnotherRoute: '/x')));
      await tester.pumpAndSettle();
      expect(find.text('Đã thêm thuốc!'), findsOneWidget);
      expect(find.text(outcome.label), findsOneWidget);
      expect(find.byKey(const Key('added-mascot')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  test('chỉ "không phát hiện" được coi là an toàn (QD-37)', () {
    expect(InteractionOutcome.values.where((o) => o.isSafe),
        [InteractionOutcome.noneFound]);
  });

  testWidgets('thuốc "Khi cần" ghi "Khi cần" thay số lần', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: MedicationAddedScreen(
            medication:
                _med.copyWith(frequency: DoseFrequency.asNeeded, times: const []),
            outcome: InteractionOutcome.noneFound,
            addAnotherRoute: '/x')));
    await tester.pumpAndSettle();
    expect(find.text('Paracetamol 500mg · Khi cần'), findsOneWidget);
  });
}
