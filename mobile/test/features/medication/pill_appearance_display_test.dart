import 'package:drugtime_mobile/features/medication/data/repositories/in_memory_medication_repository.dart';
import 'package:drugtime_mobile/features/medication/domain/entities/medication.dart';
import 'package:drugtime_mobile/features/medication/presentation/screens/medication_detail_screen.dart';
import 'package:drugtime_mobile/features/medication/presentation/state/medication_controller.dart';
import 'package:drugtime_mobile/features/medication/presentation/widgets/drug_info_sheet.dart';
import 'package:drugtime_mobile/features/medication/presentation/widgets/medication_card.dart';
import 'package:drugtime_mobile/features/medication/presentation/widgets/pill_appearance_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _plain = Medication(
  id: '42',
  catalogId: 'amlodipin-5',
  name: 'Amlodipin 5mg',
  activeIngredient: 'Amlodipin besilat',
  strength: '5 mg',
  unit: 'viên',
  dosePerIntake: 1,
  frequency: DoseFrequency.twice,
  timing: IntakeTiming.afterMeal,
  times: [DoseTime(8, 0), DoseTime(20, 0)],
  dosageForm: 'Viên nén',
);

void main() {
  final chosen = _plain.withAppearance(PillShape.capsule, PillColor.orange);

  Future<void> pumpCard(WidgetTester tester, Medication m) => tester.pumpWidget(
      MaterialApp(home: Scaffold(body: MedicationCard(medication: m, onTap: () {}))));

  testWidgets('thẻ thuốc vẽ theo hình/màu đã chọn (AC23)', (tester) async {
    await pumpCard(tester, chosen);
    final tile = tester
        .widget<PillAppearanceTile>(find.byKey(const Key('medication-card-appearance')));
    expect((tile.shape, tile.color), (PillShape.capsule, PillColor.orange));
  });

  testWidgets('thẻ thuốc chưa chọn giữ icon cũ (AC23)', (tester) async {
    await pumpCard(tester, _plain);
    expect(find.byKey(const Key('medication-card-appearance')), findsNothing);
  });

  testWidgets('chi tiết thuốc: icon theo lựa chọn và nút (i) mở thông tin (AC6, AC23)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = MedicationController(InMemoryMedicationRepository(seed: [chosen]));
    addTearDown(controller.dispose);
    await tester.pumpWidget(MedicationScope(
        controller: controller,
        child: MaterialApp(home: MedicationDetailScreen(medication: chosen))));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('detail-appearance')), findsOneWidget);
    await tester.tap(find.byKey(const Key('detail-drug-info')));
    await tester.pumpAndSettle();
    expect(find.byType(DrugInfoSheet), findsOneWidget);
    expect(find.text('Amlodipin 5mg'), findsWidgets);
  });

  test('PillAppearanceIcon: chỉ chọn màu thì hình theo dạng bào chế', () {
    const icon = PillAppearanceIcon(color: PillColor.red, dosageForm: 'Viên nang');
    expect(icon.shape, isNull);
    expect(PillShape.suggestFor(icon.dosageForm), PillShape.capsule);
  });
}
