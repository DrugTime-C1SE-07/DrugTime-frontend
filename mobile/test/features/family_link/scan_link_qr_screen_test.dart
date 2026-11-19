import 'dart:async';

import 'package:drugtime_mobile/features/family_link/data/repositories/in_memory_family_link_repository.dart';
import 'package:drugtime_mobile/features/family_link/data/sources/camera_permission.dart';
import 'package:drugtime_mobile/features/family_link/presentation/screens/enter_link_code_screen.dart';
import 'package:drugtime_mobile/features/family_link/presentation/screens/link_request_result_screen.dart';
import 'package:drugtime_mobile/features/family_link/presentation/screens/scan_link_qr_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'family_link_test_helpers.dart';

void main() {
  late ValueChanged<String> detect;
  late InMemoryFamilyLinkRepository repo;

  Widget fakeScanner(BuildContext context, ValueChanged<String> onDetect) {
    detect = onDetect;
    return const ColoredBox(key: Key('fake-scanner'), color: Colors.black);
  }

  Future<FakeCameraPermission> pumpScan(
    WidgetTester tester, {
    CameraPermissionStatus status = CameraPermissionStatus.granted,
  }) async {
    repo = InMemoryFamilyLinkRepository();
    final permission = FakeCameraPermission(status);
    await pumpFamilyLink(
      tester,
      ScanLinkQrScreen(scannerBuilder: fakeScanner),
      repository: repo,
      cameraPermission: permission,
    );
    await tester.pumpAndSettle();
    return permission;
  }

  testWidgets('AC2: QR không phải mã DrugTime → báo lỗi, không gọi repository', (tester) async {
    await pumpScan(tester);

    for (final raw in [
      'https://drug-time-frontend.vercel.app/link#code=K7M2Q9XAR4',
      'hello',
      'drugtime://link?code=k7m2q9xar4',
    ]) {
      detect(raw);
      await tester.pump();
      expect(find.text('Đây không phải mã liên kết DrugTime.'), findsOneWidget);
    }
    await tester.pumpAndSettle(const Duration(seconds: 4));

    expect(find.byType(ScanLinkQrScreen), findsOneWidget);
    expect(repo.calls, isEmpty);
  });

  testWidgets('AC5: cùng QR hợp lệ đọc 5 lần → sang màn nhập mã, gửi đúng một lần',
      (tester) async {
    await pumpScan(tester);

    for (var i = 0; i < 5; i++) {
      detect('drugtime://link?code=K7M2Q9XAR4');
    }
    await tester.pumpAndSettle();

    expect(repo.calls, hasLength(1));
    expect(repo.calls.single.code, 'K7M2Q9XAR4');
    expect(find.byType(LinkRequestResultScreen), findsOneWidget);
  });

  testWidgets('AC11: từ màn quét có lối sang Nhập mã', (tester) async {
    await pumpScan(tester);

    expect(find.text('Đưa mã QR của người thân vào khung hình'), findsOneWidget);
    await tester.tap(find.byKey(const Key('scan-enter-code')));
    await tester.pumpAndSettle();

    expect(find.byType(EnterLinkCodeScreen), findsOneWidget);
    expect(repo.calls, isEmpty);
  });

  testWidgets('AC10: bị từ chối quyền → giải thích, Nhập mã, xin lại; không có Cài đặt',
      (tester) async {
    final permission = await pumpScan(tester, status: CameraPermissionStatus.denied);

    expect(find.byKey(const Key('fake-scanner')), findsNothing);
    expect(find.byKey(const Key('camera-permission-message')), findsOneWidget);
    expect(find.byKey(const Key('camera-open-settings')), findsNothing);

    permission.status = CameraPermissionStatus.granted;
    await tester.tap(find.byKey(const Key('camera-retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('fake-scanner')), findsOneWidget);
    expect(permission.requests, 2);
  });

  testWidgets('AC10 (M1): app resumed khi hộp thoại quyền còn mở → không xin quyền lần hai',
      (tester) async {
    repo = InMemoryFamilyLinkRepository();
    final permission = FakeCameraPermission(CameraPermissionStatus.granted)
      ..pending = Completer<CameraPermissionStatus>();
    await pumpFamilyLink(tester, ScanLinkQrScreen(scannerBuilder: fakeScanner),
        repository: repo, cameraPermission: permission);
    await tester.pump();
    expect(permission.requests, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(permission.requests, 1);

    permission.pending!.complete(CameraPermissionStatus.granted);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('fake-scanner')), findsOneWidget);
    expect(permission.requests, 1);
  });

  testWidgets('AC10 (M1): xin quyền lỗi nền tảng → màn từ chối có Nhập mã, không kẹt vòng xoay',
      (tester) async {
    repo = InMemoryFamilyLinkRepository();
    final permission = FakeCameraPermission(CameraPermissionStatus.granted)
      ..error = PlatformException(code: 'ERROR_ALREADY_REQUESTING_PERMISSIONS');
    await pumpFamilyLink(tester, ScanLinkQrScreen(scannerBuilder: fakeScanner),
        repository: repo, cameraPermission: permission);
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byKey(const Key('camera-permission-message')), findsOneWidget);
    expect(find.byKey(const Key('camera-denied-enter-code')), findsOneWidget);
  });

  testWidgets('AC10 (M1): chỉ kiểm lại quyền khi quay về từ Cài đặt đã mở', (tester) async {
    final permission = await pumpScan(tester, status: CameraPermissionStatus.permanentlyDenied);
    expect(permission.requests, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(permission.requests, 1);

    await tester.tap(find.byKey(const Key('camera-open-settings')));
    await tester.pump();
    permission.status = CameraPermissionStatus.granted;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(permission.requests, 2);
    expect(find.byKey(const Key('fake-scanner')), findsOneWidget);
  });

  testWidgets('AC10: bị từ chối vĩnh viễn → có Mở Cài đặt và Nhập mã', (tester) async {
    final permission = await pumpScan(tester, status: CameraPermissionStatus.permanentlyDenied);

    await tester.tap(find.byKey(const Key('camera-open-settings')));
    await tester.pump();
    expect(permission.openSettingsCalls, 1);

    await tester.tap(find.byKey(const Key('camera-denied-enter-code')));
    await tester.pumpAndSettle();
    expect(find.byType(EnterLinkCodeScreen), findsOneWidget);
  });
}
