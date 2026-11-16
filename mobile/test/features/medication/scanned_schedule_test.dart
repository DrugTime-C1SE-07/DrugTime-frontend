import 'package:drugtime_mobile/features/medication/domain/entities/medication.dart';
import 'package:drugtime_mobile/features/medication/presentation/screens/add_medication_screen.dart';
import 'package:drugtime_mobile/features/medication/presentation/state/medication_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'medication_screens_test.dart' show RecordingRepository;

void main() {
  testWidgets('schedule fits a small phone and dose controls work',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = MedicationController(RecordingRepository());
    addTearDown(controller.dispose);
    await tester.pumpWidget(MedicationScope(
      controller: controller,
      child: const MaterialApp(
          home: AddMedicationScreen(
              scannedDrug: DrugCatalogItem(
        id: '1',
        name: 'Paracetamol 500mg',
        activeIngredient: 'Paracetamol',
        strength: '500 mg',
        dosageForm: 'Viên nén',
        unit: 'viên',
      ))),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('1 viên'), findsOneWidget);
    final beforeMeal =
        tester.getRect(find.widgetWithText(ChoiceChip, 'Trước ăn'));
    final afterMeal = tester.getRect(find.widgetWithText(ChoiceChip, 'Sau ăn'));
    final anytime = tester.getRect(find.widgetWithText(ChoiceChip, 'Bất kỳ'));
    expect(beforeMeal.width, closeTo(afterMeal.width, 0.1));
    expect(afterMeal.width, closeTo(anytime.width, 0.1));
    expect(beforeMeal.top, closeTo(anytime.top, 0.1));
    expect(tester.getCenter(find.text('Trước ăn')).dy,
        closeTo(beforeMeal.center.dy, 1));
    expect(tester.getCenter(find.text('Sau ăn')).dy,
        closeTo(afterMeal.center.dy, 1));
    expect(tester.getCenter(find.text('Bất kỳ')).dy,
        closeTo(anytime.center.dy, 1));
    final timeChip = tester.getRect(find.widgetWithText(InputChip, '08:00'));
    final addTime =
        tester.getRect(find.widgetWithText(ActionChip, '+ Thêm giờ'));
    expect(timeChip.height, closeTo(addTime.height, 0.1));
    expect(tester.getCenter(find.text('Mỗi lần uống')).dy,
        closeTo(tester.getCenter(find.text('1 viên')).dy, 2));
    expect(tester.getCenter(find.text('Giờ uống')).dy,
        greaterThan(tester.getCenter(find.text('Mỗi lần uống')).dy));
    expect(tester.getCenter(find.text('Uống khi nào')).dy,
        greaterThan(tester.getCenter(find.text('Giờ uống')).dy));
    await tester.tap(find.byTooltip('Tăng liều'));
    await tester.pump();
    expect(find.text('2 viên'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('scanned medicine with missing strength cannot be saved',
      (tester) async {
    final repo = RecordingRepository();
    final controller = MedicationController(repo);
    addTearDown(controller.dispose);
    await tester.pumpWidget(MedicationScope(
        controller: controller,
        child: const MaterialApp(
            home: AddMedicationScreen(
                scannedDrug: DrugCatalogItem(
                    id: '1',
                    name: 'Thuốc',
                    activeIngredient: '',
                    strength: '',
                    dosageForm: 'Viên nén')))));
    await tester.pump();
    await tester.tap(find.text('Tiếp tục'));
    await tester.pump();
    expect(repo.addCalls, isEmpty);
    expect(find.textContaining('Hãy chọn thuốc có đủ'), findsOneWidget);
  });
}
