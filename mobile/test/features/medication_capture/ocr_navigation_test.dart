import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/features/medication_capture/domain/ocr_models.dart';
import 'package:drugtime_mobile/features/medication_capture/presentation/screens/ocr_flow_screen.dart';
import 'ocr_controller_test.dart'
    show FakeMatcher, FakeReader, testServices, testLease;
import 'package:drugtime_mobile/app/app.dart';
import 'package:drugtime_mobile/features/medication/presentation/screens/add_medication_screen.dart';
import '../medication/medication_screens_test.dart'
    show RecordingRepository, pickDrug, signedInAuth;

void main() {
  testWidgets(
      'camera result does not change an edited form or create medication',
      (tester) async {
    final services = testServices(), repo = RecordingRepository();
    await tester.pumpWidget(DrugTimeApp(
        authController: signedInAuth(),
        medicationRepository: repo,
        captureServices: services));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Thêm'));
    await tester.pumpAndSettle();
    await pickDrug(tester, 'amlo', 'Amlodipin 5mg');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    final scan = find.text('Quét vỏ hộp để tự điền');
    await tester.ensureVisible(scan);
    await tester.tap(scan);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Chụp ảnh'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Dùng ảnh này'));
    await tester.tap(find.text('Dùng ảnh này'));
    await tester.pumpAndSettle();
    expect(find.text('Thuốc kiểm thử'), findsOneWidget);
    await tester.tap(find.byTooltip('Quay về form'));
    await tester.pumpAndSettle();
    expect(repo.addCalls, isEmpty);
    expect(find.text('Thuốc kiểm thử'), findsNothing);
    expect(find.byType(AddMedicationScreen), findsOneWidget);
    expect(find.text('Amlodipin 5mg'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    services.dispose();
  });
  testWidgets('back cancels a busy scan; late native result cannot match',
      (tester) async {
    final reader = FakeReader()..pending = Completer<String>(),
        matcher = FakeMatcher();
    final services = testServices(reader: reader, matcher: matcher);
    await services.bindSession('A');
    var exits = 0, releases = 0;
    await tester.pumpWidget(MaterialApp(
        home: OcrFlowScreen(
            image: testLease(release: () async {
              releases++;
            }),
            services: services,
            onRetake: () {},
            onExit: (_) {
              exits++;
            })));
    await tester.pump();
    await tester.pump();
    expect(find.text('Đang đọc thông tin…'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(exits, 1);
    expect(releases, 1);
    reader.pending!.complete('PRIVATE OCR');
    await tester.pumpAndSettle();
    expect(matcher.calls, 0);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    services.dispose();
  });
  testWidgets(
      'cleanup failure offers retry rather than falsely claiming deletion',
      (tester) async {
    var fail = true, exits = 0;
    final services = testServices();
    await services.bindSession('A');
    await tester.pumpWidget(MaterialApp(
        home: OcrFlowScreen(
            image: testLease(release: () async {
              if (fail) throw StateError('test');
            }),
            services: services,
            onRetake: () {},
            onExit: (_) {
              exits++;
            })));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Quay về form'));
    await tester.pumpAndSettle();
    expect(exits, 0);
    expect(find.text('Thử dọn lại'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('Thử dọn lại'));
    await tester.pumpAndSettle();
    expect(exits, 1);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    services.dispose();
  });
  testWidgets('only the second confirmed candidate is returned after cleanup',
      (tester) async {
    final matcher = FakeMatcher();
    matcher.result = OcrMatchResult(
      status: OcrMatchStatus.lowConfidence,
      items: [
        ...matcher.result.items,
        const OcrCandidate(
            id: 2,
            name: 'Thuốc thứ hai',
            activeIngredient: null,
            strengthText: null,
            dosageForm: 'Dung dịch',
            hasActiveIngredients: false,
            score: .7),
      ],
      preselectedId: null,
      suggestedQuery: null,
      reasons: [],
    );
    final services = testServices(matcher: matcher);
    await services.bindSession('A');
    final cleanup = Completer<void>();
    int? selectedId;
    await tester.pumpWidget(MaterialApp(
      home: OcrFlowScreen(
        image: testLease(release: () => cleanup.future),
        services: services,
        onRetake: () {},
        onExit: (_) => fail('Confirmation cancelled'),
        onConfirmed: (_, candidate) => selectedId = candidate.id,
      ),
    ));
    await tester.pumpAndSettle();
    final confirmSecond = find.byKey(const ValueKey('ocr-confirm-2'));
    await tester.scrollUntilVisible(confirmSecond, 150);
    await tester.pumpAndSettle();
    await tester.tap(confirmSecond);
    await tester.pump();
    expect(selectedId, isNull);
    cleanup.complete();
    await tester.pumpAndSettle();
    expect(selectedId, 2);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    services.dispose();
  });
}
