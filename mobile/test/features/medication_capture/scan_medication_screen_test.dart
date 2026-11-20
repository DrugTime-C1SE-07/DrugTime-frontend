import 'dart:async';
import 'package:drugtime_mobile/features/consent/data/repositories/in_memory_consent_repository.dart';
import 'package:drugtime_mobile/features/consent/domain/entities/consent.dart';
import 'package:drugtime_mobile/features/consent/presentation/state/consent_controller.dart';
import 'package:drugtime_mobile/features/medication/data/repositories/in_memory_medication_repository.dart';
import 'package:drugtime_mobile/features/medication/presentation/state/medication_controller.dart';
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

  Future<void> scanGallery(WidgetTester tester, FakeMatcher matcher,
      {FakeReader? reader, TestSource? source}) async {
    await openScan(tester, source ?? (TestSource()..picked = makeImage()),
        reader ?? FakeReader(), matcher);
    await tester.tap(find.byTooltip('Thư viện'));
    await tester.pumpAndSettle();
  }

  Future<void> tapVisible(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.pump();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  OcrMatchResult lowConfidence() => OcrMatchResult(
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
      suggestedQuery: 'metformin',
      reasons: ['below_threshold']);

  OcrMatchResult noMatch(String? query) => OcrMatchResult(
      status: OcrMatchStatus.noMatch,
      items: [],
      preselectedId: null,
      suggestedQuery: query,
      reasons: ['below_threshold']);

  testWidgets('matched shows one large medicine and requires confirm (AC1)',
      (tester) async {
    await scanGallery(tester, FakeMatcher());
    expect(find.byKey(const Key('ocr-single-result')), findsOneWidget);
    expect(find.text('Thuốc kiểm thử'), findsOneWidget);
    expect(find.text('Hãy đối chiếu tên và số mg với vỏ hộp'), findsNothing);
    expect(find.text('Lịch uống'), findsNothing);
    await tapVisible(tester, 'Đúng thuốc này');
    expect(find.text('Lịch uống'), findsOneWidget);
    expect(find.text('Thuốc kiểm thử'), findsOneWidget);
    expect(find.text('Mỗi lần uống'), findsOneWidget);
  });

  testWidgets('"not this medicine" opens manual search (AC1)', (tester) async {
    await scanGallery(tester, FakeMatcher());
    await tapVisible(tester, 'Không phải thuốc này');
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('matched without a read strength reminds to check mg (AC1)',
      (tester) async {
    final sample = FakeMatcher().result;
    await scanGallery(
        tester,
        FakeMatcher()
          ..result = OcrMatchResult(
              status: OcrMatchStatus.matched,
              items: sample.items,
              preselectedId: 1,
              suggestedQuery: null,
              reasons: ['strength_unverified']));
    expect(find.text('Hãy xem số mg trên vỏ hộp'), findsOneWidget);
  });

  testWidgets(
      'low confidence shows the first medicine with a check reminder, no search (AC2)',
      (tester) async {
    await scanGallery(tester, FakeMatcher()..result = lowConfidence());
    expect(find.byType(TextField), findsNothing);
    expect(find.byKey(const Key('ocr-single-result')), findsOneWidget);
    // Tên và dòng "Hoạt chất" cùng là "Metformin"; chỉ ứng viên đầu tiên được hiện.
    expect(find.text('Metformin'), findsNWidgets(2));
    expect(find.text('Thuốc khác'), findsNothing);
    expect(find.text('Hãy đối chiếu tên và số mg với vỏ hộp'), findsOneWidget);
    expect(find.text('Lịch uống'), findsNothing);
    await tapVisible(tester, 'Đúng thuốc này');
    expect(find.text('Lịch uống'), findsOneWidget);
    expect(find.text('Metformin'), findsOneWidget);
  });

  testWidgets('low confidence "not this medicine" searches the read name (AC2)',
      (tester) async {
    await scanGallery(tester, FakeMatcher()..result = lowConfidence());
    await tapVisible(tester, 'Không phải thuốc này');
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'metformin');
  });

  testWidgets(
      'no match asks to retake and offers manual search, never opens it (AC10)',
      (tester) async {
    await scanGallery(tester, FakeMatcher()..result = noMatch('zyrtec'));
    expect(find.text('Chưa thấy tên thuốc'), findsOneWidget);
    expect(find.text('Hãy chụp mặt có tên thuốc'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.byKey(const Key('ocr-single-result')), findsNothing);
    await tapVisible(tester, 'Tìm thuốc thủ công');
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'zyrtec');
  });

  testWidgets('no match without a name opens an empty manual search (AC10)',
      (tester) async {
    await scanGallery(tester, FakeMatcher()..result = noMatch(null));
    expect(find.text('Chưa thấy tên thuốc'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    await tapVisible(tester, 'Tìm thuốc thủ công');
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty);
  });

  testWidgets(
      'no text twice in a row still asks to retake, never opens search (AC10)',
      (tester) async {
    final matcher = FakeMatcher();
    final source = TestSource()..picked = makeImage();
    await scanGallery(tester, matcher,
        reader: FakeReader()..text = ' ', source: source);
    for (var attempt = 0; attempt < 2; attempt++) {
      expect(find.text('Chưa thấy tên thuốc'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Tìm thuốc thủ công'), findsOneWidget);
      await tapVisible(tester, 'Chụp lại');
      source.picked = makeImage();
      await tester.tap(find.byTooltip('Thư viện'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Chưa thấy tên thuốc'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(matcher.calls, 0);
  });

  testWidgets('camera asks to put the medicine name in the frame (AC9)',
      (tester) async {
    await openScan(tester, TestSource(), FakeReader(), FakeMatcher());
    expect(find.text('Đặt tên thuốc vào trong khung'), findsOneWidget);
  });

  testWidgets('a blurred photo says why and offers a retake (AC9)',
      (tester) async {
    final processor = TestProcessor()..warnings = [CaptureWarning.blurred];
    final reader = FakeReader();
    await openScan(
        tester, TestSource()..picked = makeImage(), reader, FakeMatcher(),
        processor: processor);
    await tester.tap(find.byTooltip('Thư viện'));
    await tester.pumpAndSettle();
    expect(
        find.text('Ảnh bị mờ. Hãy giữ máy chắc và chụp lại.'), findsOneWidget);
    expect(find.text('Chụp lại'), findsOneWidget);
    expect(reader.calls, 0);
  });

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

  testWidgets('recognition and result sheets stay below the photo frame',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final matcher = FakeMatcher()..pending = Completer<OcrMatchResult>();
    await openScan(tester, TestSource(), FakeReader(), matcher);
    await tester.tap(find.byTooltip('Chụp ảnh'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Đang nhận diện thuốc...'), findsOneWidget);
    final frame = tester.getRect(find.byKey(const Key('scan-frame')));
    expect(frame.top, lessThan(220));
    expect(
        frame.bottom,
        lessThan(
            tester.getRect(find.byKey(const Key('scan-result-sheet'))).top));
    matcher.pending!.complete(matcher.result);
    await tester.pumpAndSettle();
    expect(find.text('Có đúng thuốc trên vỏ hộp không?'), findsOneWidget);
    expect(tester.getRect(find.byKey(const Key('scan-frame'))).top, frame.top);
    expect(
        frame.bottom,
        lessThan(
            tester.getRect(find.byKey(const Key('scan-result-sheet'))).top));
  });

  testWidgets('tapping recognition requires a retake, even after the result',
      (tester) async {
    final matcher = FakeMatcher()..pending = Completer<OcrMatchResult>();
    await openScan(tester, TestSource(), FakeReader(), matcher);
    await tester.tap(find.byTooltip('Chụp ảnh'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const Key('scan-recognizing')));
    await tester.pump();
    expect(find.text('Chưa đọc được vỏ hộp'), findsOneWidget);
    matcher.pending!.complete(matcher.result);
    await tester.pumpAndSettle();
    expect(find.text('Thuốc kiểm thử'), findsNothing);
    await tapVisible(tester, 'Chụp lại');
    expect(find.byTooltip('Chụp ảnh'), findsOneWidget);
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

  testWidgets('result buttons stay pinned while the card scrolls (AC4)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final long = 'Vitamin B1 (Thiamin nitrat) 125mg; Vitamin B12 (Mecobalamin) '
        '500µg; Vitamin B6 (Pyridoxin HCl) 125mg; ' * 3;
    await scanGallery(
        tester,
        FakeMatcher()
          ..result = OcrMatchResult(
              status: OcrMatchStatus.lowConfidence,
              items: [
                OcrCandidate(
                    id: 5,
                    name: 'Me2B',
                    activeIngredient: long,
                    strengthText: '125mg',
                    dosageForm: 'Viên nén bao phim',
                    hasActiveIngredients: true,
                    score: 0.7),
              ],
              preselectedId: null,
              suggestedQuery: 'me2b',
              reasons: const ['below_threshold']));
    final scroll = find.byKey(const Key('scan-result-scroll'));
    expect(scroll, findsOneWidget);
    await tester.drag(scroll, const Offset(0, -600));
    await tester.pumpAndSettle();
    final sheet = tester.getRect(find.byKey(const Key('scan-result-sheet')));
    for (final label in ['Đúng thuốc này', 'Không phải thuốc này', 'Chụp lại']) {
      final button = find.text(label);
      expect(button.hitTestable(), findsOneWidget, reason: label);
      expect(sheet.contains(tester.getCenter(button)), isTrue, reason: label);
    }
    await tester.tap(find.text('Không phải thuốc này'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
  });
}
