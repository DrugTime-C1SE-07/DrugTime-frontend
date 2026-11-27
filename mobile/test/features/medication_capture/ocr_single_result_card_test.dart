import 'package:drugtime_mobile/app/theme/app_theme.dart';
import 'package:drugtime_mobile/features/medication_capture/domain/ocr_models.dart';
import 'package:drugtime_mobile/features/medication_capture/presentation/widgets/ocr_single_result_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _drug = OcrCandidate(
    id: 7,
    name: 'Glucophage 500 mg',
    activeIngredient: 'Metformin hydroclorid',
    strengthText: '500mg',
    dosageForm: 'Viên nén bao phim',
    hasActiveIngredients: true,
    score: 0.82);

void main() {
  Future<void> mount(WidgetTester tester,
      {OcrCandidate candidate = _drug,
      bool strengthUnverified = false,
      bool checkReminder = false}) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: OcrSingleResultCard(
                    candidate: candidate,
                    strengthUnverified: strengthUnverified,
                    checkReminder: checkReminder)))));
  }

  String valueOf(WidgetTester tester, String label) {
    final row = tester.widget<OcrInfoRow>(find.ancestor(
        of: find.text(label), matching: find.byType(OcrInfoRow)));
    return row.value ?? 'Chưa có thông tin';
  }

  testWidgets('shows one medicine as label/value rows with matched pill & shadow (AC4)',
      (tester) async {
    await mount(tester);
    expect(find.byKey(const Key('ocr-single-result')), findsOneWidget);
    expect(find.text('Glucophage 500 mg'), findsOneWidget);
    expect(valueOf(tester, 'Hàm lượng'), '500 mg');
    expect(valueOf(tester, 'Dạng bào chế'), 'Viên nén bao phim');
    expect(valueOf(tester, 'Hoạt chất'), 'Metformin hydroclorid');
    expect(find.byKey(const Key('ocr-status-pill')), findsOneWidget);
    expect(find.text('Đã nhận diện · 82% khớp'), findsOneWidget);
    // Old corner badge is replaced (never duplicated).
    expect(find.text('82% khớp'), findsNothing);
    final pill = tester.widget<Container>(find.byKey(const Key('ocr-status-pill')));
    expect((pill.decoration as BoxDecoration).color, AppColors.safeBg);
    final pillText = tester.widget<Text>(find.text('Đã nhận diện · 82% khớp'));
    expect(pillText.style?.color, AppColors.safe);
    final card = tester.widget<Container>(find.descendant(
      of: find.byKey(const Key('ocr-single-result')),
      matching: find.byType(Container),
    ).first);
    expect((card.decoration as BoxDecoration).boxShadow, AppShadows.cardElevation);
    expect(find.text('Hãy xem số mg trên vỏ hộp'), findsNothing);
    expect(find.text('Hãy đối chiếu tên và số mg với vỏ hộp'), findsNothing);
    // Nút không còn nằm trong thẻ: chúng được ghim ở đáy sheet.
    expect(find.text('Đúng thuốc này'), findsNothing);
  });

  testWidgets('matched with score 0 shows "Đã nhận diện" without percentage (AC4)',
      (tester) async {
    await mount(
      tester,
      candidate: const OcrCandidate(
        id: 9,
        name: 'Paracetamol 500 mg',
        activeIngredient: 'Paracetamol',
        strengthText: '500mg',
        dosageForm: 'Viên nén',
        hasActiveIngredients: true,
        score: 0,
      ),
    );
    expect(find.text('Đã nhận diện'), findsOneWidget);
  });

  testWidgets('missing fields keep their row and say so', (tester) async {
    await mount(tester,
        candidate: const OcrCandidate(
            id: 8,
            name: 'Thuốc thiếu dữ liệu',
            activeIngredient: null,
            strengthText: ' ',
            dosageForm: null,
            hasActiveIngredients: false,
            score: 0.6));
    expect(find.byType(OcrInfoRow), findsNWidgets(3));
    expect(find.text('Chưa có thông tin'), findsNWidgets(3));
  });

  testWidgets('strength_unverified asks to read the mg (AC4)', (tester) async {
    await mount(tester, strengthUnverified: true);
    expect(find.text('Hãy xem số mg trên vỏ hộp'), findsOneWidget);
  });

  testWidgets(
      'low confidence shows caution pill with cautionText (#92400E) and single reminder (AC5)',
      (tester) async {
    await mount(tester, strengthUnverified: true, checkReminder: true);
    expect(find.text('Cần đối chiếu · 82% khớp'), findsOneWidget);
    final pill = tester.widget<Container>(find.byKey(const Key('ocr-status-pill')));
    expect((pill.decoration as BoxDecoration).color, AppColors.cautionBg);
    final pillText = tester.widget<Text>(find.text('Cần đối chiếu · 82% khớp'));
    expect(pillText.style?.color, AppColors.cautionText);
    expect(find.text('Hãy đối chiếu tên và số mg với vỏ hộp'), findsOneWidget);
    expect(find.text('Hãy xem số mg trên vỏ hộp'), findsNothing);
  });

  testWidgets('actions call back and are large enough to tap', (tester) async {
    final calls = <String>[];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: OcrResultActions(
                onConfirm: () => calls.add('confirm'),
                onNotThis: () => calls.add('not-this'),
                onRetake: () => calls.add('retake')))));
    await tester.tap(find.text('Đúng thuốc này'));
    await tester.tap(find.text('Không phải thuốc này'));
    await tester.tap(find.text('Chụp lại'));
    expect(calls, ['confirm', 'not-this', 'retake']);
    expect(tester.getSize(find.byType(FilledButton)).height,
        greaterThanOrEqualTo(48));
  });
}
