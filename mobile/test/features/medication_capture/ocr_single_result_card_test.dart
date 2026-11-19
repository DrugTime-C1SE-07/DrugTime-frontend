import 'package:drugtime_mobile/features/medication_capture/domain/ocr_models.dart';
import 'package:drugtime_mobile/features/medication_capture/presentation/widgets/ocr_single_result_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _drug = OcrCandidate(
    id: 7,
    name: 'Glucophage 500 mg',
    activeIngredient: 'Metformin hydroclorid',
    strengthText: '500 mg',
    dosageForm: 'Viên nén bao phim',
    hasActiveIngredients: true,
    score: 0.82);

void main() {
  Future<List<String>> mount(WidgetTester tester,
      {bool strengthUnverified = false, bool checkReminder = false}) async {
    final calls = <String>[];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: OcrSingleResultCard(
                    candidate: _drug,
                    strengthUnverified: strengthUnverified,
                    checkReminder: checkReminder,
                    onConfirm: () => calls.add('confirm'),
                    onNotThis: () => calls.add('not-this'))))));
    return calls;
  }

  testWidgets('shows one medicine with large strength and both actions (AC1)',
      (tester) async {
    final calls = await mount(tester);
    expect(find.byKey(const Key('ocr-single-result')), findsOneWidget);
    expect(find.text('Glucophage 500 mg'), findsOneWidget);
    expect(find.text('Hàm lượng: 500 mg'), findsOneWidget);
    expect(find.text('Dạng: Viên nén bao phim'), findsOneWidget);
    expect(find.text('Hoạt chất: Metformin hydroclorid'), findsOneWidget);
    expect(find.text('Hãy xem số mg trên vỏ hộp'), findsNothing);
    expect(find.text('Hãy đối chiếu tên và số mg với vỏ hộp'), findsNothing);
    await tester.tap(find.text('Đúng thuốc này'));
    await tester.tap(find.text('Không phải thuốc này'));
    expect(calls, ['confirm', 'not-this']);
    expect(tester.getSize(find.byType(FilledButton)).height,
        greaterThanOrEqualTo(48));
  });

  testWidgets('strength_unverified asks to read the mg (AC1)', (tester) async {
    await mount(tester, strengthUnverified: true);
    expect(find.text('Hãy xem số mg trên vỏ hộp'), findsOneWidget);
  });

  testWidgets('low confidence asks to compare name and mg, one hint only (AC2)',
      (tester) async {
    await mount(tester, strengthUnverified: true, checkReminder: true);
    expect(find.text('Hãy đối chiếu tên và số mg với vỏ hộp'), findsOneWidget);
    expect(find.text('Hãy xem số mg trên vỏ hộp'), findsNothing);
  });
}
