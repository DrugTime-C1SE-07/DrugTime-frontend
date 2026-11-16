import 'dart:async';
import 'package:drugtime_mobile/features/consent/data/repositories/in_memory_consent_repository.dart';
import 'package:drugtime_mobile/features/consent/domain/entities/consent.dart';
import 'package:drugtime_mobile/features/consent/presentation/state/consent_controller.dart';
import 'package:drugtime_mobile/features/medication/data/repositories/in_memory_medication_repository.dart';
import 'package:drugtime_mobile/features/medication/presentation/state/medication_controller.dart';
import 'package:drugtime_mobile/core/preview/app_preview_scope.dart';
import 'package:drugtime_mobile/features/medication_capture/data/capture_services.dart';
import 'package:drugtime_mobile/features/medication_capture/domain/capture_models.dart';
import 'package:drugtime_mobile/features/medication_capture/domain/ocr_models.dart';
import 'package:drugtime_mobile/features/medication_capture/presentation/state/capture_scope.dart';
import 'capture_controller_test.dart'
    show TestSource, TestStore, TestProcessor, makeImage;
import 'ocr_controller_test.dart' show FakeReader, FakeMatcher;
import 'package:drugtime_mobile/features/medication_capture/presentation/screens/scan_medication_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> openScan(WidgetTester tester, TestSource source,
      FakeReader reader, FakeMatcher matcher,
      {TestProcessor? processor}) async {
    final services = CaptureServices(
        store: TestStore(),
        processor: processor ?? TestProcessor(),
        newSource: () => source,
        reader: reader,
        matching: matcher);
    await services.bindSession('test-session');
    addTearDown(services.dispose);
    final medication = MedicationController(InMemoryMedicationRepository());
    addTearDown(medication.dispose);
    await tester.pumpWidget(MedicationScope(
        controller: medication,
        child: CaptureScope(
            services: services,
            child: const MaterialApp(home: ScanMedicationScreen()))));
    await tester.pumpAndSettle();
  }

  testWidgets('canceling gallery keeps the scan open without running OCR',
      (tester) async {
    final source = TestSource()..access = CapturePermission.denied;
    final reader = FakeReader();
    await openScan(tester, source, reader, FakeMatcher());
    await tester.tap(find.byTooltip('Thư viện'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Thư viện'), findsOneWidget);
    expect(reader.calls, 0);
    source.picked = makeImage();
    await tester.tap(find.byTooltip('Thư viện'));
    await tester.pumpAndSettle();
    expect(reader.calls, 1);
    expect(find.text('Thuốc kiểm thử'), findsOneWidget);
  });

  testWidgets('permanent camera denial opens app settings', (tester) async {
    final source = TestSource()..access = CapturePermission.permanentlyDenied;
    await openScan(tester, source, FakeReader(), FakeMatcher());
    await tester.tap(find.text('Mở cài đặt'));
    await tester.pumpAndSettle();
    expect(source.settingsCalls, 1);
  });

  testWidgets('camera asks for permission only after tapping allow',
      (tester) async {
    final source = TestSource()..access = CapturePermission.denied;
    await openScan(tester, source, FakeReader(), FakeMatcher());
    expect(source.statusRequests, isNot(contains(true)));
    source.access = CapturePermission.granted;
    await tester.tap(find.text('Cho phép camera'));
    await tester.pumpAndSettle();
    expect(source.statusRequests, contains(true));
    expect(find.byKey(const Key('test-camera')), findsOneWidget);
  });

  testWidgets('gallery can retry after an image processing error',
      (tester) async {
    final source = TestSource()..picked = makeImage();
    final processor = TestProcessor()..failProcessing = true;
    final reader = FakeReader();
    await openScan(tester, source, reader, FakeMatcher(), processor: processor);
    await tester.tap(find.byTooltip('Thư viện'));
    await tester.pumpAndSettle();
    expect(find.text('Không mở được ảnh'), findsOneWidget);
    expect(reader.calls, 0);
    processor.failProcessing = false;
    await tester.tap(find.text('Chọn ảnh khác'));
    await tester.pumpAndSettle();
    expect(find.text('Thuốc kiểm thử'), findsOneWidget);
  });

  testWidgets('gallery no match is distinct from unreadable text',
      (tester) async {
    final matcher = FakeMatcher()
      ..result = OcrMatchResult(
          status: OcrMatchStatus.noMatch,
          items: [],
          preselectedId: null,
          suggestedQuery: 'Strepsils Original',
          reasons: []);
    await openScan(
        tester, TestSource()..picked = makeImage(), FakeReader(), matcher);
    await tester.tap(find.byTooltip('Thư viện'));
    await tester.pumpAndSettle();
    expect(find.text('Không tìm thấy thuốc phù hợp'), findsOneWidget);
    await tester.tap(find.text('Tìm thuốc thủ công'));
    await tester.pumpAndSettle();
    final query = tester.widget<TextField>(find.byType(TextField));
    expect(query.controller!.text, 'Strepsils Original');
  });

  testWidgets('low confidence does not offer direct confirmation',
      (tester) async {
    final matcher = FakeMatcher()
      ..result = OcrMatchResult(
          status: OcrMatchStatus.lowConfidence,
          items: const [
            OcrCandidate(
                id: 1,
                name: 'Metformin',
                activeIngredient: 'Metformin',
                strengthText: '500 mg',
                dosageForm: 'Viên nén',
                hasActiveIngredients: true,
                score: 0.65),
            OcrCandidate(
                id: 2,
                name: 'Thuốc khác',
                activeIngredient: null,
                strengthText: '850 mg',
                dosageForm: null,
                hasActiveIngredients: false,
                score: 0.45),
          ],
          preselectedId: null,
          suggestedQuery: null,
          reasons: ['below_threshold']);
    await openScan(
        tester, TestSource()..picked = makeImage(), FakeReader(), matcher);
    await tester.tap(find.byTooltip('Thư viện'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Đúng thuốc này'), findsNothing);
    Navigator.of(tester.element(find.byType(TextField))).pop();
    await tester.pumpAndSettle();
    expect(find.text('Xem gợi ý khác'), findsOneWidget);
    expect(find.text('Thuốc khác'), findsNothing);
    await tester.tap(find.text('Xem gợi ý khác'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Thuốc khác'), 150);
    final confirm = find.text('Đúng thuốc này').last;
    await tester.ensureVisible(confirm);
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(find.text('Lịch uống'), findsOneWidget);
    expect(find.text('Thuốc khác'), findsOneWidget);
  });

  Future<void> openPreview(WidgetTester tester) async {
    await tester.pumpWidget(AppPreviewScope(
        clock: DateTime.utc(2026),
        child: const MaterialApp(home: ScanMedicationScreen())));
    await tester.pump();
  }

  testWidgets(
      'real flow waits for backend and invalidates late response on tap',
      (tester) async {
    final matcher = FakeMatcher()..pending = Completer<OcrMatchResult>();
    final source = TestSource();
    final store = TestStore();
    final services = CaptureServices(
        store: store,
        processor: TestProcessor(),
        newSource: () => source,
        reader: FakeReader(),
        matching: matcher);
    await services.bindSession('real-session');
    await tester.pumpWidget(CaptureScope(
        services: services,
        child: const MaterialApp(home: ScanMedicationScreen())));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Chụp ảnh'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(matcher.calls, 1);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Đang nhận diện thuốc...'), findsOneWidget);
    await tester.tap(find.byKey(const Key('scan-recognizing')));
    await tester.pump();
    expect(find.text('Chưa đọc được vỏ hộp'), findsOneWidget);
    matcher.pending!.complete(matcher.result);
    await tester.pump();
    expect(find.text('Thuốc kiểm thử'), findsNothing);
    expect(store.releases, 1);
    await tester.pumpWidget(const SizedBox());
    services.dispose();
  });

  testWidgets('preview waits 1.5 seconds before showing its sample result',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await openPreview(tester);
    await tester.tap(find.byTooltip('Chụp ảnh'));
    await tester.pump();
    expect(find.text('Đang nhận diện thuốc...'), findsOneWidget);
    final frame = tester.getRect(find.byKey(const Key('scan-frame')));
    final processingSheet =
        tester.getRect(find.byKey(const Key('scan-result-sheet')));
    expect(frame.bottom, lessThan(processingSheet.top));
    expect(frame.top, lessThan(220));
    await tester.pump(const Duration(milliseconds: 1499));
    expect(find.text('Đang nhận diện thuốc...'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('Paracetamol 500mg'), findsOneWidget);
    expect(find.text('Có đúng thuốc trên vỏ hộp không?'), findsOneWidget);
    expect(tester.getRect(find.byKey(const Key('scan-frame'))).top, frame.top);
    expect(
        frame.bottom,
        lessThan(
            tester.getRect(find.byKey(const Key('scan-result-sheet'))).top));
  });

  testWidgets('tapping recognition requires a retake, even after timer expires',
      (tester) async {
    await openPreview(tester);
    await tester.tap(find.byTooltip('Chụp ảnh'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('scan-recognizing')));
    await tester.pump();
    expect(find.text('Chưa đọc được vỏ hộp'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Paracetamol 500mg'), findsNothing);
    await tester.tap(find.text('Quét lại'));
    await tester.pump();
    expect(find.byTooltip('Chụp ảnh'), findsOneWidget);
  });
  testWidgets('confirming preview candidate opens new schedule form',
      (tester) async {
    final medication = MedicationController(InMemoryMedicationRepository());
    addTearDown(medication.dispose);
    await tester.pumpWidget(MedicationScope(
        controller: medication,
        child: AppPreviewScope(
            clock: DateTime.utc(2026),
            child: const MaterialApp(home: ScanMedicationScreen()))));
    await tester.pump();
    await tester.tap(find.byTooltip('Chụp ảnh'));
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.tap(find.text('Đúng thuốc này'));
    await tester.pumpAndSettle();
    expect(find.text('Lịch uống'), findsOneWidget);
    expect(find.text('Paracetamol 500mg'), findsOneWidget);
    expect(find.text('Mỗi lần uống'), findsOneWidget);
    expect(find.text('Tiếp tục'), findsOneWidget);
  });
  testWidgets('revoking consent during recognition clears the pending result',
      (tester) async {
    final matcher = FakeMatcher()..pending = Completer<OcrMatchResult>();
    final store = TestStore();
    final services = CaptureServices(
        store: store,
        processor: TestProcessor(),
        newSource: TestSource.new,
        reader: FakeReader(),
        matching: matcher);
    final consent = ConsentController(InMemoryConsentRepository());
    await services.bindSession('real-session');
    await consent.load();
    await tester.pumpWidget(ConsentScope(
        controller: consent,
        child: CaptureScope(
            services: services,
            child: const MaterialApp(home: ScanMedicationScreen()))));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Chụp ảnh'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(matcher.calls, 1);
    await consent.withdraw(ConsentPurpose.healthData);
    await tester.pump();
    matcher.pending!.complete(matcher.result);
    await tester.pump();
    expect(find.text('Thuốc kiểm thử'), findsNothing);
    expect(store.releases, 1);
    await tester.pumpWidget(const SizedBox());
    consent.dispose();
    services.dispose();
  });
}
