import 'dart:async';
import 'package:drugtime_mobile/app/theme/app_theme.dart';
import 'package:drugtime_mobile/features/consent/data/repositories/in_memory_consent_repository.dart';
import 'package:drugtime_mobile/features/consent/domain/entities/consent.dart';
import 'package:drugtime_mobile/features/consent/presentation/state/consent_controller.dart';
import 'package:drugtime_mobile/features/medication/data/repositories/in_memory_medication_repository.dart';
import 'package:drugtime_mobile/features/medication/presentation/state/medication_controller.dart';
import 'package:drugtime_mobile/features/medication_capture/data/capture_services.dart';
import 'package:drugtime_mobile/features/medication_capture/domain/capture_models.dart';
import 'package:drugtime_mobile/features/medication_capture/domain/ocr_models.dart';
import 'package:drugtime_mobile/features/medication_capture/presentation/state/capture_scope.dart';
import 'package:drugtime_mobile/features/medication_capture/presentation/widgets/scan_camera_overlay.dart';
import 'capture_controller_test.dart'
    show TestSource, TestStore, TestProcessor, makeImage;
import 'ocr_controller_test.dart' show FakeReader, FakeMatcher;
import 'package:drugtime_mobile/features/medication_capture/presentation/screens/scan_medication_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FailingInitSource extends TestSource {
  @override
  Future<void> initialize() async {
    initializations++;
    throw const CaptureFailure('Camera đang bận ở ứng dụng khác.');
  }
}

class _ConfigurableStore extends TestStore {
  _ConfigurableStore({
    this.ttl = const Duration(hours: 24),
    this.failRelease = false,
  });

  Duration ttl;
  bool failRelease;

  @override
  Future<PreparedMedicationImage> save(
      ProcessedCapture image, PackagingKind kind) async {
    final id = 'cfg-${saves++}';
    live[id] = image.bytes;
    final now = DateTime.now();
    return PreparedMedicationImage(
      id: id,
      kind: kind,
      width: image.width,
      height: image.height,
      createdAt: now,
      expiresAt: now.add(ttl),
      read: () async {
        final bytes = live[id];
        if (bytes == null) throw const CaptureFailure('Hết phiên');
        return bytes;
      },
      release: () async {
        if (failRelease) throw StateError('disk busy');
        releases++;
        live.remove(id);
      },
    );
  }
}

void main() {
  Future<void> openScan(WidgetTester tester, TestSource source,
      FakeReader reader, FakeMatcher matcher,
      {TestProcessor? processor,
      TestStore? store,
      TextScaler? textScaler}) async {
    final services = CaptureServices(
        store: store ?? TestStore(),
        processor: processor ?? TestProcessor(),
        newSource: () => source,
        reader: reader,
        matching: matcher);
    await services.bindSession('test-session');
    addTearDown(services.dispose);
    final medication = MedicationController(InMemoryMedicationRepository());
    addTearDown(medication.dispose);
    Widget app = MaterialApp(home: ScanMedicationScreen(key: UniqueKey()));
    if (textScaler != null) {
      app = MediaQuery(
        data: MediaQueryData(textScaler: textScaler),
        child: app,
      );
    }
    await tester.pumpWidget(MedicationScope(
        controller: medication,
        child: CaptureScope(services: services, child: app)));
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

  testWidgets('permanent camera denial opens app settings without allow button',
      (tester) async {
    final source = TestSource()..access = CapturePermission.permanentlyDenied;
    await openScan(tester, source, FakeReader(), FakeMatcher());
    expect(source.statusRequests, [true]);
    expect(find.text('Cho phép camera'), findsNothing);
    await tester.tap(find.text('Mở cài đặt'));
    await tester.pumpAndSettle();
    expect(source.settingsCalls, 1);
  });

  testWidgets(
      'camera requests permission automatically on open without allow button',
      (tester) async {
    final source = TestSource()..access = CapturePermission.denied;
    await openScan(tester, source, FakeReader(), FakeMatcher());
    expect(source.statusRequests, [true]);
    expect(find.text('Cho phép camera'), findsNothing);
    expect(find.text('Mở cài đặt'), findsNothing);
    expect(find.byTooltip('Thư viện'), findsOneWidget);
    expect(find.byTooltip('Nhập tay'), findsOneWidget);
    expect(find.byKey(const Key('test-camera')), findsNothing);
  });

  testWidgets('camera opens preview automatically when permission is granted',
      (tester) async {
    final source = TestSource()..access = CapturePermission.granted;
    await openScan(tester, source, FakeReader(), FakeMatcher());
    expect(source.statusRequests, [true]);
    expect(find.text('Cho phép camera'), findsNothing);
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

  testWidgets(
      'scan beam sweeps down to bottom and reverses back up in camera mode (AC1)',
      (tester) async {
    final services = CaptureServices(
        store: TestStore(),
        processor: TestProcessor(),
        newSource: TestSource.new,
        reader: FakeReader(),
        matching: FakeMatcher());
    await services.bindSession('test-session');
    addTearDown(services.dispose);
    final medication = MedicationController(InMemoryMedicationRepository());
    addTearDown(medication.dispose);
    await tester.pumpWidget(MedicationScope(
        controller: medication,
        child: CaptureScope(
            services: services,
            child: const MaterialApp(home: ScanMedicationScreen()))));
    await tester.pump();

    double beamY() => (tester
            .widget<Align>(find.byKey(const Key('scan-beam')))
            .alignment as Alignment)
        .y;

    expect(beamY(), closeTo(-1.0, 0.05));
    await tester.pump(const Duration(milliseconds: 700));
    expect(beamY(), greaterThan(-0.2));
    expect(beamY(), lessThan(0.2));
    await tester.pump(const Duration(milliseconds: 700));
    expect(beamY(), closeTo(1.0, 0.05));
    // Reverses back up instead of staying stuck at the bottom.
    await tester.pump(const Duration(milliseconds: 700));
    expect(beamY(), lessThan(0.2));
    expect(beamY(), greaterThan(-0.2));
    await tester.pump(const Duration(milliseconds: 700));
    expect(beamY(), closeTo(-1.0, 0.05));
  });

  testWidgets(
      'scan beam stays still when disableAnimations is true and stops cleanly on screen change (AC2)',
      (tester) async {
    final services = CaptureServices(
        store: TestStore(),
        processor: TestProcessor(),
        newSource: TestSource.new,
        reader: FakeReader(),
        matching: FakeMatcher());
    await services.bindSession('test-session');
    addTearDown(services.dispose);
    final medication = MedicationController(InMemoryMedicationRepository());
    addTearDown(medication.dispose);
    await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MedicationScope(
            controller: medication,
            child: CaptureScope(
                services: services,
                child: const MaterialApp(home: ScanMedicationScreen())))));
    await tester.pump();

    double beamY() => (tester
            .widget<Align>(find.byKey(const Key('scan-beam')))
            .alignment as Alignment)
        .y;

    expect(beamY(), closeTo(0.0, 0.01));
    await tester.pump(const Duration(milliseconds: 700));
    expect(beamY(), closeTo(0.0, 0.01));
    await tester.tap(find.byTooltip('Chụp ảnh'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('scan-beam')), findsNothing);
    expect(find.text('Thuốc kiểm thử'), findsOneWidget);
  });

  testWidgets(
      'camera capture passes scan frame crop while gallery pick passes null crop (AC3, AC4)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final source = TestSource()..picked = makeImage();
    final processor = TestProcessor();
    await openScan(tester, source, FakeReader(), FakeMatcher(),
        processor: processor);

    await tester.tap(find.byTooltip('Chụp ảnh'));
    await tester.pumpAndSettle();
    expect(processor.crops.length, 1);
    final cameraCrop = processor.crops.first;
    expect(cameraCrop, isNotNull);
    expect(cameraCrop!.left, greaterThan(0));
    expect(cameraCrop.top, greaterThan(0));
    expect(cameraCrop.width, greaterThan(0));
    expect(cameraCrop.width, lessThan(1));
    expect(cameraCrop.height, greaterThan(0));
    expect(cameraCrop.height, lessThan(1));
    expect(cameraCrop.viewportAspectRatio, greaterThan(0));

    await tapVisible(tester, 'Chụp lại');
    await tester.tap(find.byTooltip('Thư viện'));
    await tester.pumpAndSettle();
    expect(processor.crops.length, 2);
    expect(processor.crops.last, isNull);
  });

  testWidgets(
      'camera renders 4-side cameraScrim aligned with crop frame, guide pill below frame, no overflow at 360x640 1.3x (AC1)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await openScan(tester, TestSource(), FakeReader(), FakeMatcher(),
        textScaler: const TextScaler.linear(1.3));
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('scan-scrim')), findsOneWidget);
    final scrimPaint =
        tester.widget<CustomPaint>(find.byKey(const Key('scan-scrim')));
    final scrimPainter = scrimPaint.painter as ScanScrimPainter;
    expect(scrimPainter.scrimColor, AppColors.cameraScrim);
    final cornersRect =
        tester.getRect(find.byKey(const Key('scan-camera-corners')));
    final pillRect = tester.getRect(find.byKey(const Key('scan-hint')));
    expect(pillRect.top, greaterThanOrEqualTo(cornersRect.bottom));
    expect(tester.getSize(find.byTooltip('Thư viện')).height,
        greaterThanOrEqualTo(48));
    expect(tester.getSize(find.byTooltip('Nhập tay')).height,
        greaterThanOrEqualTo(48));
    expect(
        find.text('Ảnh chỉ xử lý trên điện thoại của bạn'), findsOneWidget);
  });

  testWidgets(
      'denied, permanentlyDenied, and camera error show elderly guidance and hide overlay without allow button (AC2)',
      (tester) async {
    await openScan(tester, TestSource()..access = CapturePermission.denied,
        FakeReader(), FakeMatcher());
    expect(find.byKey(const Key('scan-camera-issue')), findsOneWidget);
    expect(find.byKey(const Key('scan-scrim')), findsNothing);
    expect(find.text('Cho phép camera'), findsNothing);
    expect(find.text('Mở cài đặt'), findsNothing);
    expect(
        find.text(
            'Bạn vẫn có thể chọn ảnh từ Thư viện hoặc Nhập tay ở bên dưới.'),
        findsOneWidget);

    final permanent = TestSource()
      ..access = CapturePermission.permanentlyDenied;
    await openScan(tester, permanent, FakeReader(), FakeMatcher());
    expect(find.byKey(const Key('scan-camera-issue')), findsOneWidget);
    expect(find.byKey(const Key('scan-scrim')), findsNothing);
    expect(find.text('Mở cài đặt'), findsOneWidget);
    await tester.tap(find.text('Mở cài đặt'));
    await tester.pumpAndSettle();
    expect(permanent.settingsCalls, 1);

    await openScan(tester, _FailingInitSource(), FakeReader(), FakeMatcher());
    expect(find.byKey(const Key('scan-camera-issue')), findsOneWidget);
    expect(find.byKey(const Key('scan-scrim')), findsNothing);
    expect(find.text('Camera đang bận ở ứng dụng khác.'), findsOneWidget);
  });

  testWidgets(
      'recognizing sheet shows 14px privacy banner, brand progress, no overflow at 360x640 1.3x, and cancelling resets stale _nameMissed (AC3)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final matcher = FakeMatcher()..result = noMatch('paracetamol');
    final source = TestSource()..picked = makeImage();
    await openScan(tester, source, FakeReader(), matcher,
        textScaler: const TextScaler.linear(1.3));
    // First scan produces no_match (sets _nameMissed = true).
    await tester.tap(find.byTooltip('Thư viện'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa thấy tên thuốc'), findsOneWidget);

    // Retake and start a second pending scan.
    await tapVisible(tester, 'Chụp lại');
    matcher.pending = Completer<OcrMatchResult>();
    source.picked = makeImage();
    await tester.tap(find.byTooltip('Thư viện'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);

    final privacy =
        tester.widget<Text>(find.text('Ảnh chỉ xử lý trên máy, không gửi đi'));
    expect(privacy.style?.fontSize, 14);
    expect(privacy.style?.fontWeight, FontWeight.w500);
    final progress = tester.widget<LinearProgressIndicator>(
        find.byKey(const Key('scan-progress')));
    expect(progress.color, AppColors.brand);

    // Cancel mid-recognition: _nameMissed must be reset and Retry hidden.
    await tester.tap(find.byKey(const Key('scan-recognizing')));
    await tester.pumpAndSettle();
    expect(find.text('Chưa đọc được vỏ hộp'), findsOneWidget);
    expect(find.text('Chưa thấy tên thuốc'), findsNothing);
    expect(find.text('Thử lại'), findsNothing);
    expect(find.text('Tìm thuốc thủ công'), findsOneWidget);
    expect(find.text('Chọn ảnh khác'), findsOneWidget);
    expect(find.text('Chụp lại'), findsOneWidget);
    matcher.pending!.complete(matcher.result);
    await tester.pump();
  });

  testWidgets(
      'matched and low_confidence result sheets show status pills without overflow at 360x640 1.3x (AC4, AC5)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await openScan(tester, TestSource()..picked = makeImage(), FakeReader(),
        FakeMatcher(),
        textScaler: const TextScaler.linear(1.3));
    await tester.tap(find.byTooltip('Thư viện'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Đã nhận diện · 80% khớp'), findsOneWidget);
    expect(find.text('Đúng thuốc này').hitTestable(), findsOneWidget);

    await openScan(tester, TestSource()..picked = makeImage(), FakeReader(),
        FakeMatcher()..result = lowConfidence(),
        textScaler: const TextScaler.linear(1.3));
    await tester.tap(find.byTooltip('Thư viện'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Cần đối chiếu · 65% khớp'), findsOneWidget);
    expect(find.text('Đúng thuốc này').hitTestable(), findsOneWidget);
  });

  testWidgets(
      'no_match failure uses AppColors.brand header, 160x160 illus, 40x40 tips badges 17px, no Retry, no overflow at 360x640 1.3x (AC6)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await openScan(tester, TestSource()..picked = makeImage(), FakeReader(),
        FakeMatcher()..result = noMatch('zyrtec'),
        textScaler: const TextScaler.linear(1.3));
    await tester.tap(find.byTooltip('Thư viện'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final stepLabel =
        tester.widget<Text>(find.byKey(const Key('scan-step-label')));
    expect(stepLabel.style?.color, AppColors.brand);
    expect(tester.getSize(find.byKey(const Key('scan-failure-illus'))),
        const Size(160, 160));
    expect(tester.getSize(find.byKey(const Key('tip-badge-light'))),
        const Size(40, 40));
    expect(tester.getSize(find.byKey(const Key('tip-badge-frame'))),
        const Size(40, 40));
    final tipText = tester.widget<Text>(find.text('Đủ ánh sáng, không bị loá'));
    expect(tipText.style?.fontSize, 17);
    expect(find.text('Thử lại'), findsNothing);
    expect(find.text('Tìm thuốc thủ công'), findsOneWidget);
    expect(find.text('Chọn ảnh khác'), findsOneWidget);
    expect(find.text('Chụp lại'), findsOneWidget);
  });

  testWidgets(
      'blurred and invalidImage failures offer manual search, gallery, retake without Retry (AC7)',
      (tester) async {
    final processor = TestProcessor()..warnings = [CaptureWarning.blurred];
    await openScan(
        tester, TestSource()..picked = makeImage(), FakeReader(), FakeMatcher(),
        processor: processor);
    await tester.tap(find.byTooltip('Thư viện'));
    await tester.pumpAndSettle();
    expect(find.text('Thử lại'), findsNothing);
    expect(find.text('Tìm thuốc thủ công'), findsOneWidget);
    expect(find.text('Chọn ảnh khác'), findsOneWidget);
    expect(find.text('Chụp lại'), findsOneWidget);

    await openScan(
        tester,
        TestSource()..picked = makeImage(),
        FakeReader()..failureKind = OcrFailureKind.invalidImage,
        FakeMatcher());
    await tester.tap(find.byTooltip('Thư viện'));
    await tester.pumpAndSettle();
    expect(find.text('Không mở được ảnh'), findsOneWidget);
    expect(find.text('Thử lại'), findsNothing);
    expect(find.text('Tìm thuốc thủ công'), findsOneWidget);
    expect(find.text('Chọn ảnh khác'), findsOneWidget);
    expect(find.text('Chụp lại'), findsOneWidget);
  });

  testWidgets(
      'network and recognition failures show Retry that re-runs OcrController.start() without retaking (AC8)',
      (tester) async {
    final reader = FakeReader();
    final matcher = FakeMatcher()..failureKind = OcrFailureKind.network;
    await openScan(
        tester, TestSource()..picked = makeImage(), reader, matcher);
    await tester.tap(find.byTooltip('Thư viện'));
    await tester.pumpAndSettle();
    expect(find.text('Thử lại'), findsOneWidget);
    expect(find.text('Tìm thuốc thủ công'), findsOneWidget);
    expect(find.text('Chọn ảnh khác'), findsOneWidget);
    expect(find.text('Chụp lại'), findsOneWidget);

    matcher.failureKind = null;
    await tapVisible(tester, 'Thử lại');
    expect(reader.calls, 1);
    expect(matcher.calls, 2);
    expect(find.text('Thuốc kiểm thử'), findsOneWidget);

    final reader2 = FakeReader()..failureKind = OcrFailureKind.recognition;
    final matcher2 = FakeMatcher();
    await openScan(
        tester, TestSource()..picked = makeImage(), reader2, matcher2);
    await tester.tap(find.byTooltip('Thư viện'));
    await tester.pumpAndSettle();
    expect(find.text('Thử lại'), findsOneWidget);

    reader2.failureKind = null;
    await tapVisible(tester, 'Thử lại');
    expect(reader2.calls, 2);
    expect(matcher2.calls, 1);
    expect(find.text('Thuốc kiểm thử'), findsOneWidget);
  });

  testWidgets(
      'expiring encrypted image on failure screen hides Retry and shows expired message (AC8, AC9)',
      (tester) async {
    final store = _ConfigurableStore(ttl: const Duration(milliseconds: 80));
    final matcher = FakeMatcher()..failureKind = OcrFailureKind.network;
    await openScan(tester, TestSource()..picked = makeImage(), FakeReader(),
        matcher,
        store: store);
    await tester.tap(find.byTooltip('Thư viện'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.text('Thử lại'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 120));
    await tester.pumpAndSettle();
    expect(store.releases, 1);
    expect(find.text('Thử lại'), findsNothing);
    expect(find.text('Ảnh đã hết hạn'), findsOneWidget);
    expect(find.text('Chụp lại'), findsOneWidget);
  });

  testWidgets(
      'unauthorized (401) and cleanup failure release/lock UI fail-closed without Retry/Manual/Gallery/Retake (AC9)',
      (tester) async {
    final store = _ConfigurableStore();
    await openScan(
        tester,
        TestSource()..picked = makeImage(),
        FakeReader(),
        FakeMatcher()..failureKind = OcrFailureKind.unauthorized,
        store: store);
    await tester.tap(find.byTooltip('Thư viện'));
    await tester.pumpAndSettle();
    expect(store.releases, 1);
    expect(find.text('Phiên đăng nhập đã hết hạn'), findsOneWidget);
    expect(find.text('Thử lại'), findsNothing);
    expect(find.text('Tìm thuốc thủ công'), findsNothing);
    expect(find.text('Chọn ảnh khác'), findsNothing);
    expect(find.text('Chụp lại'), findsNothing);
    expect(find.text('Đóng'), findsOneWidget);

    // Cleanup failure during exit stays fail-closed with "Thử dọn lại" until cleanup succeeds.
    final stickyStore = _ConfigurableStore(failRelease: true);
    final matcher = FakeMatcher()..pending = Completer<OcrMatchResult>();
    final services = CaptureServices(
        store: stickyStore,
        processor: TestProcessor(),
        newSource: () => TestSource()..picked = makeImage(),
        reader: FakeReader(),
        matching: matcher);
    await services.bindSession('session-clean');
    addTearDown(services.dispose);
    var popped = false;
    await tester.pumpWidget(CaptureScope(
      services: services,
      child: MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ScanMedicationScreen()),
              );
              popped = true;
            },
            child: const Text('Open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Thư viện'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const Key('scan-recognizing')));
    await tester.pumpAndSettle();
    expect(find.text('Chưa dọn được ảnh tạm'), findsOneWidget);
    expect(find.text('Thử lại'), findsNothing);
    expect(find.text('Tìm thuốc thủ công'), findsNothing);
    expect(find.text('Chọn ảnh khác'), findsNothing);
    expect(find.text('Chụp lại'), findsNothing);
    expect(find.text('Thử dọn lại'), findsOneWidget);
    expect(popped, isFalse);

    stickyStore.failRelease = false;
    await tester.tap(find.text('Thử dọn lại'));
    await tester.pumpAndSettle();
    expect(stickyStore.releases, 1);
    expect(popped, isTrue);
    matcher.pending!.complete(matcher.result);
    await tester.pump();
  });
}
