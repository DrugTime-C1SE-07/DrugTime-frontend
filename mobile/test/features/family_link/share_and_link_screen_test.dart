import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/app/router.dart';
import 'package:drugtime_mobile/features/family_link/presentation/screens/share_and_link_screen.dart';

void main() {
  for (final entry in [
    (const Key('share-own-qr'), AppRoutes.familyMyCode),
    (const Key('share-scan-qr'), AppRoutes.familyScanCode),
    (const Key('share-invite-link'), AppRoutes.familyShareLink),
  ]) {
    testWidgets('${entry.$1} opens the existing route and returns',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: const ShareAndLinkScreen(),
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
            builder: (_) =>
                Scaffold(appBar: AppBar(title: Text(settings.name!)))),
      ));
      await tester.tap(find.byKey(entry.$1));
      await tester.pumpAndSettle();
      expect(find.text(entry.$2), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Mời người thân'), findsOneWidget);
    });
  }

  testWidgets('options remain accessible with larger text', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: child!),
        home: const ShareAndLinkScreen()));
    await tester.scrollUntilVisible(
        find.byKey(const Key('share-invite-link')), 200);
    expect(find.byKey(const Key('share-invite-link')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
