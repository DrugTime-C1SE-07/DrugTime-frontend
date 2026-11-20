import 'package:drugtime_mobile/features/medication_capture/domain/ocr_models.dart';
import 'package:drugtime_mobile/features/medication_capture/presentation/widgets/recognition_steps.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> mount(WidgetTester tester, OcrStage stage) => tester.pumpWidget(
      MaterialApp(home: Scaffold(body: RecognitionSteps(stage: stage))));

  testWidgets('mọi bước cùng kích thước vòng, chỉ khác trạng thái (AC1)',
      (tester) async {
    await mount(tester, OcrStage.recognizing);
    final rows = find.byType(RecognitionStepRow);
    expect(rows, findsNWidgets(3));
    final sizes = [
      for (final e in rows.evaluate())
        tester.getSize(find.descendant(
            of: find.byWidget(e.widget), matching: find.byType(SizedBox)).first)
    ];
    expect(sizes.toSet(), {const Size.square(RecognitionStepRow.markSize)});
    expect(find.byKey(const Key('recognition-mark-done')), findsOneWidget);
    expect(find.byKey(const Key('recognition-mark-active')), findsOneWidget);
    expect(find.byKey(const Key('recognition-mark-pending')), findsOneWidget);
    expect(find.text('Đang đọc chữ trên vỏ'), findsOneWidget);
  });

  testWidgets('đọc chữ xong thì bước đối chiếu đang chạy (AC1)', (tester) async {
    await mount(tester, OcrStage.matching);
    expect(find.byKey(const Key('recognition-mark-done')), findsNWidgets(2));
    expect(find.byKey(const Key('recognition-mark-active')), findsOneWidget);
    expect(find.byKey(const Key('recognition-mark-pending')), findsNothing);
    expect(find.text('Đã đọc chữ trên vỏ'), findsOneWidget);
    expect(find.text('Đang đối chiếu danh mục thuốc'), findsOneWidget);
  });

  testWidgets('bước đã xong dùng cùng một màu nền', (tester) async {
    await mount(tester, OcrStage.result);
    final colors = {
      for (final e in find.byKey(const Key('recognition-mark-done')).evaluate())
        ((e.widget as Container).decoration as BoxDecoration).color
    };
    expect(colors, hasLength(1));
  });

  test('tiến trình theo giai đoạn thật, không cố định (AC2)', () {
    expect(recognitionProgress(OcrStage.recognizing),
        lessThan(recognitionProgress(OcrStage.matching)));
    expect(recognitionProgress(OcrStage.matching),
        lessThan(recognitionProgress(OcrStage.result)));
    expect(recognitionProgress(OcrStage.result), 1);
  });
}
