import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/app/app.dart';
import 'package:drugtime_mobile/features/medication_capture/data/capture_services.dart';
import 'package:drugtime_mobile/features/medication_capture/presentation/screens/camera_capture_screen.dart';
import 'package:drugtime_mobile/features/medication_capture/presentation/screens/capture_edit_screen.dart';
import 'package:drugtime_mobile/features/medication/presentation/screens/add_medication_screen.dart';
import '../medication/medication_screens_test.dart'
    show RecordingRepository, signedInAuth;
import 'capture_controller_test.dart' show TestSource, TestStore, TestProcessor;

void main() {
  testWidgets(
      'real route preserves form; prepared image never fills a sample drug or creates medication',
      (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final source = TestSource(),
        store = TestStore(),
        repo = RecordingRepository();
    final services = CaptureServices(
        store: store, processor: TestProcessor(), newSource: () => source);
    await tester.pumpWidget(DrugTimeApp(
        authController: signedInAuth(),
        medicationRepository: repo,
        captureServices: services));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Thêm'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quét vỏ thuốc'));
    await tester.pumpAndSettle();
    expect(find.byType(CameraCaptureScreen), findsOneWidget);
    expect(find.text('Nhập thủ công'), findsNothing);
    expect(find.byType(SegmentedButton), findsNothing);
    await tester.tap(find.byTooltip('Chụp ảnh'));
    await tester.pumpAndSettle();
    expect(find.byType(CaptureEditScreen), findsOneWidget);
    await tester.tap(find.text('Chụp lại'));
    await tester.pumpAndSettle();
    expect(find.byType(CameraCaptureScreen), findsOneWidget);
    await tester.tap(find.byTooltip('Chụp ảnh'));
    await tester.pumpAndSettle();
    expect(find.byType(CaptureEditScreen), findsOneWidget);
    await tester.ensureVisible(find.text('Dùng ảnh này'));
    await tester.tap(find.text('Dùng ảnh này'));
    await tester.pumpAndSettle();
    expect(find.text('Thêm thuốc mới'), findsOneWidget);
    expect(find.text('Ảnh đã sẵn sàng'), findsOneWidget);
    expect(find.text('Xem ảnh'), findsOneWidget);
    expect(repo.addCalls, isEmpty);
    expect(store.live, hasLength(1));
    await tester.tap(find.byTooltip('Bỏ ảnh'));
    await tester.pumpAndSettle();
    expect(store.live, isEmpty);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(AddMedicationScreen), findsNothing);
    final navigation = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navigation.destinations, hasLength(5));
    await tester.tap(find.text('Lịch nhắc').last);
    await tester.pumpAndSettle();
    expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        2);
    await tester.tap(find.text('Thuốc').last);
    await tester.pumpAndSettle();
    expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    services.dispose();
  });
  testWidgets('logout/session invalidation closes capture and stops camera',
      (tester) async {
    final source = TestSource(), store = TestStore();
    final services = CaptureServices(
        store: store, processor: TestProcessor(), newSource: () => source);
    await tester.pumpWidget(DrugTimeApp(
        authController: signedInAuth(),
        medicationRepository: RecordingRepository(),
        captureServices: services));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Thêm'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quét vỏ thuốc'));
    await tester.pumpAndSettle();
    await services.invalidate();
    await tester.pumpAndSettle();
    expect(find.byType(CameraCaptureScreen), findsNothing);
    expect(source.ready, isFalse);
    expect(store.live, isEmpty);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    services.dispose();
  });
}
