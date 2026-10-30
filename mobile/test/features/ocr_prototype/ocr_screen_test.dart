import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/features/ocr_prototype/ocr_controller.dart';
import 'package:drugtime_mobile/features/ocr_prototype/ocr_screen.dart';
import 'ocr_controller_test.dart'
    show FakeEngine, FakePicker, FakeStore, FakeExporter;

void main() {
  testWidgets('metadata form, run, raw history and export origin',
      (tester) async {
    final engine = FakeEngine();
    final store = FakeStore();
    final exporter = FakeExporter();
    final controller = OcrController(
        engine: engine,
        picker: FakePicker(),
        store: store,
        rootPath: '.',
        validateImage: (_) async {});
    await tester.pumpWidget(MaterialApp(
        home: OcrPrototypeScreen(controller: controller, exporter: exporter)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pick-image')));
    await tester.pumpAndSettle();
    for (final key in [
      'imageId',
      'platform',
      'deviceModel',
      'osVersion',
      'appRevision',
      'nativeSdkVersion'
    ]) {
      await tester.ensureVisible(find.byKey(ValueKey(key)));
      await tester.enterText(find.byKey(ValueKey(key)), 'test-$key');
    }
    await tester.ensureVisible(find.byKey(const Key('run-ocr')));
    await tester.tap(find.byKey(const Key('run-ocr')));
    await tester.pumpAndSettle();
    expect(engine.calls, 1);
    expect(store.runs.single.rawText, engine.text);
    final export = find.byKey(ValueKey('export-${store.runs.single.id}'));
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(export, 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(export);
    await tester.pumpAndSettle();
    expect(exporter.origin!.width, greaterThan(0));
    expect(exporter.origin!.height, greaterThan(0));
    // Prototype has no medication repository or mutation button.
    expect(find.text('Lưu thuốc'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await controller.closed;
    expect(engine.closes, 1);
  });
  testWidgets('unsupported platform exposes no picker or run action',
      (tester) async {
    final controller = OcrController(
        engine: FakeEngine(),
        picker: FakePicker(),
        store: FakeStore(),
        rootPath: '.',
        supported: false);
    await tester.pumpWidget(MaterialApp(
        home: OcrPrototypeScreen(
            controller: controller, exporter: FakeExporter())));
    expect(find.text('Prototype OCR chỉ hỗ trợ Android.'), findsOneWidget);
    expect(find.byKey(const Key('run-ocr')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await controller.closed;
  });
}
