import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/app/theme/app_theme.dart';
import 'package:drugtime_mobile/features/medication_capture/domain/capture_models.dart';
import 'package:drugtime_mobile/features/medication_capture/presentation/state/capture_controller.dart';
import 'package:drugtime_mobile/features/medication_capture/presentation/screens/camera_capture_screen.dart';
import 'package:drugtime_mobile/features/medication_capture/presentation/screens/capture_edit_screen.dart';
import 'package:drugtime_mobile/features/medication_capture/presentation/screens/capture_analyzing_screen.dart';
import 'package:drugtime_mobile/features/medication_capture/presentation/screens/capture_confirmation_screen.dart';
import 'capture_controller_test.dart'
    show TestSource, TestProcessor, TestStore, makeImage;

const candidates = [
  CaptureCandidate(
      id: '1',
      name: 'Paracetamol',
      ingredient: 'Paracetamol',
      strength: '500 mg'),
  CaptureCandidate(
      id: '2',
      name: 'Paracetamol',
      ingredient: 'Paracetamol',
      strength: '650 mg')
];
Future<void> pumpCapture(WidgetTester tester, Widget screen,
    {Size size = const Size(375, 812), double scale = 1}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!),
      home: screen));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('one candidate still requires explicit review and selection',
      (tester) async {
    CaptureCandidate? confirmed;
    var manual = 0;
    await pumpCapture(
        tester,
        CaptureConfirmationScreen(
            candidates: [candidates.first],
            onConfirm: (v) => confirmed = v,
            onManual: () => manual++,
            onRescan: () {}));
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Xác nhận thuốc'))
            .onPressed,
        isNull);
    await tester.tap(find.text('500 mg'));
    await tester.pump();
    await tester.tap(find.text('Xác nhận thuốc'));
    expect(confirmed?.id, '1');
    await tester.tap(find.text('Nhập thủ công'));
    expect(manual, 1);
  });
  testWidgets('ambiguous/empty/error states do not auto-select medication',
      (tester) async {
    await pumpCapture(
        tester,
        CaptureConfirmationScreen(
            candidates: candidates,
            onConfirm: (_) => fail('auto selection'),
            onManual: () {},
            onRescan: () {}));
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Xác nhận thuốc'))
            .onPressed,
        isNull);
    await pumpCapture(
        tester,
        CaptureConfirmationScreen(
            candidates: const [],
            onConfirm: (_) => fail('empty selection'),
            onManual: () {},
            onRescan: () {},
            error: 'Lỗi kết nối',
            onRetry: () {}));
    expect(find.text('Thử lại'), findsOneWidget);
    expect(find.text('Nhập thủ công'), findsOneWidget);
  });
  testWidgets(
      'analyzing has indeterminate progress and stays until caller changes state',
      (tester) async {
    var cancelled = false;
    await pumpCapture(
        tester, CaptureAnalyzingScreen(onCancel: () => cancelled = true));
    expect(
        tester
            .widget<LinearProgressIndicator>(
                find.byType(LinearProgressIndicator))
            .value,
        isNull);
    expect(find.textContaining('%'), findsNothing);
    await tester.pump(const Duration(seconds: 8));
    expect(find.text('Đang đọc thông tin…'), findsOneWidget);
    await tester.tap(find.text('Hủy'));
    expect(cancelled, isTrue);
  });
  testWidgets(
      'permission denial retains gallery and close; permanent denial opens Settings',
      (tester) async {
    final source = TestSource()..access = CapturePermission.permanentlyDenied;
    final c = CaptureController(
        source: source, processor: TestProcessor(), store: TestStore());
    await c.start();
    await pumpCapture(
        tester, CameraCaptureScreen(controller: c, onClose: () {}));
    expect(find.text('Mở cài đặt'), findsOneWidget);
    expect(find.byTooltip('Chọn ảnh từ thư viện'), findsOneWidget);
    expect(find.text('Nhập thủ công'), findsNothing);
    expect(source.initializations, 0);
    await tester.tap(find.text('Mở cài đặt'));
    await tester.pumpAndSettle();
    expect(source.settingsCalls, 1);
    source.access = CapturePermission.granted;
    await c.background();
    await c.resume();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('test-camera')), findsOneWidget);
    expect(source.statusRequests, [false, false]);
    await tester.pumpWidget(const SizedBox());
    await c.close();
    c.dispose();
  });
  testWidgets(
      'permission CTA explicitly requests access; capture stays disabled before grant',
      (tester) async {
    final source = TestSource()..access = CapturePermission.denied;
    final c = CaptureController(
        source: source, processor: TestProcessor(), store: TestStore());
    await c.start();
    await pumpCapture(
        tester, CameraCaptureScreen(controller: c, onClose: () {}));
    final shutter = find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.tooltip == 'Chụp ảnh');
    expect(tester.widget<IconButton>(shutter).onPressed, isNull);
    expect(source.statusRequests, [false]);
    source.access = CapturePermission.granted;
    await tester.tap(find.text('Cho phép camera'));
    await tester.pumpAndSettle();
    expect(source.statusRequests, [false, true]);
    expect(tester.widget<IconButton>(shutter).onPressed, isNotNull);
    await tester.pumpWidget(const SizedBox());
    await c.close();
    c.dispose();
  });
  testWidgets(
      'review shows the complete image, a status and exactly two actions',
      (tester) async {
    final c = CaptureController(
        source: TestSource(), processor: TestProcessor(), store: TestStore());
    await c.accept(makeImage());
    var used = 0, retaken = 0;
    await pumpCapture(
        tester,
        CaptureEditScreen(
            controller: c, onUse: () => used++, onRetake: () => retaken++));
    final displayed = tester.widget<Image>(find.byType(Image));
    expect(displayed.fit, BoxFit.contain);
    expect((displayed.image as MemoryImage).bytes, c.image!.bytes);
    expect(find.text('Ảnh đã sẵn sàng'), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.byType(OutlinedButton), findsOneWidget);
    expect(find.byType(IconButton), findsNothing);
    expect(find.byType(InteractiveViewer), findsNothing);
    expect(find.byType(Slider), findsNothing);
    for (final label in [
      'Đặt lại',
      'Nhập thủ công',
      'Giữ tên, hàm lượng và SĐK'
    ]) {
      expect(find.text(label), findsNothing);
    }
    await tester.tap(find.text('Dùng ảnh này'));
    await tester.tap(find.text('Chụp lại'));
    expect((used, retaken), (1, 1));
    await tester.pumpWidget(const SizedBox());
    await c.close();
    c.dispose();
  });
  testWidgets(
      'image warning stays short; failed image disables Use and keeps Retake',
      (tester) async {
    final processor = TestProcessor()..warnings = [CaptureWarning.dark];
    final c = CaptureController(
        source: TestSource(), processor: processor, store: TestStore());
    await c.accept(makeImage());
    await pumpCapture(tester,
        CaptureEditScreen(controller: c, onUse: () {}, onRetake: () {}));
    expect(
        find.text('Ảnh quá tối. Hãy chụp lại ở nơi đủ sáng.'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    expect(tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNotNull);
    processor.warnings = [CaptureWarning.bright, CaptureWarning.blurred];
    await c.accept(makeImage());
    await tester.pump();
    expect(
        find.text('Ảnh bị mờ. Hãy giữ máy chắc và chụp lại.'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    processor.failProcessing = true;
    await c.accept(makeImage());
    await tester.pump();
    expect(find.text('Không mở được ảnh này.'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    expect(tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNotNull);
    await tester.pumpWidget(const SizedBox());
    await c.close();
    c.dispose();
  });
  for (final size in [const Size(375, 812), const Size(812, 375)]) {
    testWidgets('Settings CTA remains reachable at 200 percent text on $size',
        (tester) async {
      final c = CaptureController(
          source: TestSource()..access = CapturePermission.permanentlyDenied,
          processor: TestProcessor(),
          store: TestStore());
      await c.start();
      await pumpCapture(
          tester, CameraCaptureScreen(controller: c, onClose: () {}),
          size: size, scale: 2);
      expect(find.text('Mở cài đặt').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await c.close();
      c.dispose();
    });
  }
  for (final size in [
    const Size(375, 812),
    const Size(430, 932),
    const Size(812, 375)
  ]) {
    testWidgets('screens support $size and large text without overflow',
        (tester) async {
      final c = CaptureController(
          source: TestSource(), processor: TestProcessor(), store: TestStore());
      await c.start();
      final screens = <Widget>[
        CameraCaptureScreen(controller: c, onClose: () {}),
        CaptureConfirmationScreen(
            candidates: candidates,
            onConfirm: (_) {},
            onManual: () {},
            onRescan: () {}),
        CaptureAnalyzingScreen(onCancel: () {})
      ];
      for (final screen in screens) {
        final reports = <FlutterErrorDetails>[];
        final handler = FlutterError.onError;
        FlutterError.onError = (details) {
          reports.add(details);
          handler?.call(details);
        };
        await pumpCapture(tester, screen, size: size, scale: 2);
        if (screen is CameraCaptureScreen) {
          expect(find.byType(SegmentedButton<PackagingKind>), findsNothing);
          expect(find.text('Hộp'), findsNothing);
          expect(find.text('Vỉ'), findsNothing);
          expect(find.text('Nhập thủ công'), findsNothing);
        }
        FlutterError.onError = handler;
        final error = tester.takeException();
        if (error != null) {
          fail(
              '${screen.runtimeType}: ${reports.map((r) => r.toString()).join('\n')}');
        }
      }
      await c.accept(makeImage());
      await pumpCapture(tester,
          CaptureEditScreen(controller: c, onUse: () {}, onRetake: () {}),
          size: size, scale: 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await c.close();
      c.dispose();
    });
  }
}
