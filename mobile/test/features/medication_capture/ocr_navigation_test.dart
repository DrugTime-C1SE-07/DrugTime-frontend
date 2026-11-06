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
    show RecordingRepository, signedInAuth;

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
    final scrollable = find
        .descendant(
            of: find.byType(AddMedicationScreen),
            matching: find.byType(Scrollable))
        .first;
    await tester.scrollUntilVisible(find.byType(TextField), 250,
        scrollable: scrollable);
    await tester.enterText(find.byType(TextField), '37');
    tester.testTextInput.hide();
    await tester.pump();
    await tester.scrollUntilVisible(find.text('Quét vỏ thuốc'), -250,
        scrollable: scrollable);
    await tester.tap(find.text('Quét vỏ thuốc'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Chụp ảnh'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Dùng ảnh này'));
    await tester.tap(find.text('Dùng ảnh này'));
    await tester.pumpAndSettle();
    expect(find.text('Thuốc kiểm thử'), findsOneWidget);
    await tester.tap(find.text('Quay về form'));
    await tester.pumpAndSettle();
    expect(repo.addCalls, isEmpty);
    expect(find.text('Thuốc kiểm thử'), findsNothing);
    await tester.scrollUntilVisible(find.byType(TextField), 250,
        scrollable: scrollable);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '37');
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
    await tester.tap(find.text('Quay về form'));
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
  testWidgets(
      'successful close hands off candidates without an image or selection',
      (tester) async {
    OcrMatchResult? handedOff;
    final services = testServices();
    await services.bindSession('A');
    await tester.pumpWidget(MaterialApp(
        home: OcrFlowScreen(
            image: testLease(),
            services: services,
            onRetake: () {},
            onExit: (result) {
              handedOff = result;
            })));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quay về form'));
    await tester.pumpAndSettle();
    expect(handedOff?.items.single.id, 1);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    services.dispose();
  });
}
