import 'package:drugtime_mobile/features/medication/domain/entities/medication.dart';
import 'package:drugtime_mobile/features/medication/presentation/screens/add_medication_screen.dart';
import 'package:drugtime_mobile/features/medication/presentation/state/medication_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'medication_screens_test.dart' show RecordingRepository;

void main() {
  Future<void> openScreen(WidgetTester tester) async {
    final controller = MedicationController(RecordingRepository());
    addTearDown(controller.dispose);
    await tester.pumpWidget(MedicationScope(
      controller: controller,
      child: MaterialApp(home: Builder(builder: (context) {
        return Scaffold(
            body: TextButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => const AddMedicationScreen(
              scannedDrug: DrugCatalogItem(
                id: '1',
                name: 'Paracetamol',
                activeIngredient: 'Paracetamol',
                strength: '500 mg',
                dosageForm: 'Viên nén',
                unit: 'viên',
              ),
            ),
          )),
          child: const Text('Mở'),
        ));
      })),
    ));
    await tester.tap(find.text('Mở'));
    await tester.pumpAndSettle();
  }

  testWidgets('unchanged scan schedule exits without a dialog', (tester) async {
    await openScreen(tester);
    await tester.tap(find.byTooltip('Quay lại'));
    await tester.pumpAndSettle();
    expect(find.text('Mở'), findsOneWidget);
    expect(find.text('Bỏ thông tin đã nhập?'), findsNothing);
  });

  testWidgets('changed scan schedule stays on cancel and exits on confirm',
      (tester) async {
    await openScreen(tester);
    await tester.tap(find.byTooltip('Tăng liều'));
    await tester.pump();
    await tester.tap(find.byTooltip('Quay lại'));
    await tester.pumpAndSettle();
    expect(find.text('Bỏ thông tin đã nhập?'), findsOneWidget);
    await tester.tap(find.text('Tiếp tục nhập'));
    await tester.pumpAndSettle();
    expect(find.text('2 viên'), findsOneWidget);
    await tester.tap(find.byTooltip('Quay lại'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bỏ'));
    await tester.pumpAndSettle();
    expect(find.text('Mở'), findsOneWidget);
    expect(find.text('Bỏ thông tin đã nhập?'), findsNothing);
  });
}
