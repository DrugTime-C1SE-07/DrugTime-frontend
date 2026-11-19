import 'package:drugtime_mobile/features/family_link/data/repositories/in_memory_family_link_repository.dart';
import 'package:drugtime_mobile/features/family_link/presentation/screens/enter_link_code_screen.dart';
import 'package:drugtime_mobile/features/family_link/presentation/screens/scan_link_qr_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'family_link_test_helpers.dart';

void main() {
  late ValueChanged<String> detect;
  late InMemoryFamilyLinkRepository repository;

  Future<void> openScanner(WidgetTester tester) async {
    repository = InMemoryFamilyLinkRepository();
    await pumpFamilyLink(
      tester,
      ScanLinkQrScreen(
        scannerBuilder: (_, onDetect) {
          detect = onDetect;
          return const ColoredBox(color: Colors.black);
        },
      ),
      repository: repository,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('AC2: valid QR fills code and waits for explicit confirmation',
      (tester) async {
    await openScanner(tester);

    detect('drugtime://link?code=K7M2Q9XAR4');
    await tester.pumpAndSettle();

    // Keep this expected behavior even while F1 makes the current app fail.
    expect(repository.calls.isEmpty, isTrue,
        reason: 'Redeem request was sent before confirmation');
    expect(find.byType(EnterLinkCodeScreen), findsOneWidget);
    expect(find.byKey(const Key('link-code-submit')), findsOneWidget);

    await tester.tap(find.byKey(const Key('link-code-submit')));
    await tester.pumpAndSettle();
    expect(repository.calls.length, 1);
  });

  testWidgets('AC2: invalid QR never sends a redeem request', (tester) async {
    await openScanner(tester);

    detect('https://invalid.example/link?code=K7M2Q9XAR4');
    await tester.pumpAndSettle();

    expect(find.byType(ScanLinkQrScreen), findsOneWidget);
    expect(find.byKey(const Key('scan-invalid-qr')), findsOneWidget);
    expect(repository.calls.isEmpty, isTrue);
  });
}
