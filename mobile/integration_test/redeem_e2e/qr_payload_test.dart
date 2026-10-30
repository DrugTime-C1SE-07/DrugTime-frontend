import 'dart:io';

import 'package:drugtime_mobile/app/router.dart';
import 'package:drugtime_mobile/core/api/api_client.dart';
import 'package:drugtime_mobile/core/config/app_config.dart';
import 'package:drugtime_mobile/features/family_link/data/repositories/in_memory_caregiver_repository.dart';
import 'package:drugtime_mobile/features/family_link/data/repositories/remote_family_link_repository.dart';
import 'package:drugtime_mobile/features/family_link/data/sources/camera_permission.dart';
import 'package:drugtime_mobile/features/family_link/presentation/screens/enter_link_code_screen.dart';
import 'package:drugtime_mobile/features/family_link/presentation/screens/link_request_result_screen.dart';
import 'package:drugtime_mobile/features/family_link/presentation/screens/scan_link_qr_screen.dart';
import 'package:drugtime_mobile/features/family_link/presentation/state/family_link_scope.dart';
import 'package:drugtime_mobile/features/family_link/presentation/state/invite_link_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';

import 'redeem_helpers.dart';

class _GrantedCamera implements CameraPermission {
  @override
  Future<CameraPermissionStatus> request() async =>
      CameraPermissionStatus.granted;

  @override
  Future<void> openSettings() async {}
}

/// Counts only redeem requests. Requests still go to the real local backend.
class _CountingClient extends http.BaseClient {
  _CountingClient(this._inner);

  final http.Client _inner;
  int redeemPosts = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (request.method == 'POST' &&
        request.url.path == '/family/link-requests') {
      redeemPosts++;
    }
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('QR payload requires confirmation before a remote redeem POST',
      (tester) async {
    final fixture = await RedeemFixture.read();
    final httpClient = _CountingClient(http.Client());
    final invites = InviteLinkController();
    try {
      expect({'qr_valid', 'qr_invalid'}, contains(fixture.scenario),
          reason: 'Unknown QR scenario');
      expect(AppConfig.isConfigured, isTrue,
          reason: 'Local backend URL is required');

      final api = ApiClient(
        baseUrl: Uri.parse(AppConfig.apiBaseUrl),
        httpClient: httpClient,
        authTokenProvider: () async => fixture.session.accessToken,
      );
      late ValueChanged<String> detect;
      await tester.pumpWidget(FamilyLinkScope(
        repository: RemoteFamilyLinkRepository(api),
        caregivers: InMemoryCaregiverRepository(),
        invites: invites,
        cameraPermission: _GrantedCamera(),
        child: MaterialApp(
          home: ScanLinkQrScreen(
            scannerBuilder: (_, onDetect) {
              detect = onDetect;
              return const ColoredBox(
                  key: Key('redeem-fake-scanner'), color: Colors.black);
            },
          ),
          onGenerateRoute: onGenerateRoute,
        ),
      ));
      await waitForRedeem(tester, find.byKey(const Key('redeem-fake-scanner')),
          step: 'scanner-ready');
      await tester.pump(const Duration(milliseconds: 200));

      detect(fixture.scenario == 'qr_valid' ? fixture.qrPayload : 'invalid');
      await tester.pump(const Duration(milliseconds: 300));
      if (fixture.scenario == 'qr_invalid') {
        expect(find.byType(ScanLinkQrScreen), findsOneWidget);
        expect(find.byKey(const Key('scan-invalid-qr')), findsOneWidget);
        expect(httpClient.redeemPosts, 0);
      } else {
        await waitForRedeem(tester, find.byType(EnterLinkCodeScreen),
            step: 'qr-prefilled-code');
        // AC2: the scanner may fill the code, but no request may leave until
        // the person presses the visible confirmation button. F1 makes this red.
        expect(httpClient.redeemPosts, 0);
        expect(find.byType(LinkRequestResultScreen), findsNothing);
        await tapRedeem(tester, find.byKey(const Key('link-code-submit')));
        await waitForRedeem(tester, find.byType(LinkRequestResultScreen),
            step: 'qr-pending-result');
        expect(find.text('Đang chờ xác nhận'), findsOneWidget);
        expect(httpClient.redeemPosts, 1);
      }
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      httpClient.close();
      invites.dispose();
      await File(redeemFixturePath).delete();
    }
  });
}
