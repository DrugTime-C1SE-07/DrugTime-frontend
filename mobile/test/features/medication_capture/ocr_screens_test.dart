import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/features/medication_capture/domain/ocr_models.dart';
import 'package:drugtime_mobile/features/medication_capture/presentation/screens/ocr_candidates_screen.dart';
import 'package:drugtime_mobile/features/medication_capture/presentation/screens/ocr_flow_screen.dart';
import 'ocr_controller_test.dart'
    show FakeMatcher, FakeReader, testServices, testLease;

void main() {
  testWidgets(
      'read-only candidates, strength warning, nulls and text200% are accessible',
      (tester) async {
    final sample = FakeMatcher().result;
    final result = OcrMatchResult(
        status: OcrMatchStatus.lowConfidence,
        items: sample.items,
        preselectedId: null,
        suggestedQuery: 'test',
        reasons: ['strength_unverified']);
    var exits = 0;
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
            data: const MediaQueryData(
                textScaler: TextScaler.linear(2), disableAnimations: true),
            child: OcrCandidatesScreen(
                result: result,
                onRetake: () {},
                onExit: () {
                  exits++;
                }))));
    expect(find.text('Có thể là'), findsOneWidget);
    expect(find.textContaining('Chưa xác minh được hàm lượng'), findsOneWidget);
    expect(find.byType(RadioListTile), findsNothing);
    expect(find.text('Xác nhận thuốc'), findsNothing);
    await tester.scrollUntilVisible(find.text('Quay về form'), 200);
    await tester.tap(find.text('Quay về form'));
    expect(exits, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('no-match is distinct from no-text and offers rescan',
      (tester) async {
    final result = OcrMatchResult(
        status: OcrMatchStatus.noMatch,
        items: [],
        preselectedId: null,
        suggestedQuery: 'test',
        reasons: []);
    var retakes = 0;
    await tester.pumpWidget(MaterialApp(
        home: OcrCandidatesScreen(
            result: result,
            onRetake: () {
              retakes++;
            },
            onExit: () {})));
    expect(find.text('Chưa tìm thấy thuốc phù hợp'), findsOneWidget);
    expect(find.text('Thử lại'), findsNothing);
    await tester.tap(find.text('Chụp lại'));
    expect(retakes, 1);
  });
  testWidgets('OCR empty has safe error and no matching call', (tester) async {
    final reader = FakeReader()..text = ' \n', matcher = FakeMatcher();
    final services = testServices(reader: reader, matcher: matcher);
    await services.bindSession('A');
    await tester.pumpWidget(MaterialApp(
        home: OcrFlowScreen(
            image: testLease(),
            services: services,
            onRetake: () {},
            onExit: (_) {})));
    await tester.pumpAndSettle();
    expect(find.textContaining('Chưa đọc được chữ'), findsOneWidget);
    expect(matcher.calls, 0);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    services.dispose();
  });
}
