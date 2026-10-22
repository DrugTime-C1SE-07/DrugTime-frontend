import 'package:drugtime_mobile/features/family/presentation/screens/family_link_code_screen.dart';
import 'package:drugtime_mobile/features/family_link/data/repositories/in_memory_family_link_repository.dart';
import 'package:drugtime_mobile/features/family_link/presentation/screens/enter_link_code_screen.dart';
import 'package:drugtime_mobile/features/family_link/presentation/screens/family_tab_screen.dart';
import 'package:drugtime_mobile/features/family_link/presentation/screens/scan_link_qr_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/features/family/presentation/state/family_alert_controller.dart';
import 'package:drugtime_mobile/features/family/presentation/state/family_alert_scope.dart';
import '../family/family_alert_controller_test.dart' show AlertRepo;

import 'family_link_test_helpers.dart';

void main() {
  testWidgets(
      'alert entry displays server unread count and removes it after clear',
      (tester) async {
    final c = FamilyAlertController(AlertRepo())..setSession('A', ready: true);
    await c.load();
    await tester.pumpWidget(FamilyAlertScope(
        controller: c, child: const MaterialApp(home: FamilyTabScreen())));
    expect(find.text('1 chưa đọc'), findsOneWidget);
    expect(find.byKey(const Key('family-alerts')), findsOneWidget);
    c.clear();
    await tester.pump();
    expect(find.text('1 chưa đọc'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  Future<void> pumpTab(WidgetTester tester) => pumpFamilyLink(
        tester,
        const FamilyTabScreen(),
        repository: InMemoryFamilyLinkRepository(),
      );

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('family-follow')));
    await tester.pumpAndSettle();
  }

  testWidgets('AC11: Theo dõi người thân → hai lựa chọn Quét mã QR và Nhập mã',
      (tester) async {
    await pumpTab(tester);

    expect(find.text('Theo dõi người thân'), findsOneWidget);
    await openSheet(tester);

    expect(find.byKey(const Key('follow-method-scan')), findsOneWidget);
    expect(find.byKey(const Key('follow-method-enter')), findsOneWidget);
  });

  testWidgets('AC11: Quét mã QR mở màn quét', (tester) async {
    await pumpTab(tester);
    await openSheet(tester);

    await tester.tap(find.byKey(const Key('follow-method-scan')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(ScanLinkQrScreen), findsOneWidget);
  });

  testWidgets('AC11: Nhập mã mở màn nhập mã', (tester) async {
    await pumpTab(tester);
    await openSheet(tester);

    await tester.tap(find.byKey(const Key('follow-method-enter')));
    await tester.pumpAndSettle();

    expect(find.byType(EnterLinkCodeScreen), findsOneWidget);
  });

  testWidgets('Mã liên kết của tôi mở màn QR của 3.11', (tester) async {
    await pumpTab(tester);

    await tester.tap(find.byKey(const Key('family-my-code')));
    await tester.pumpAndSettle();

    expect(find.byType(FamilyLinkCodeScreen), findsOneWidget);
    expect(find.byKey(const Key('family-link-code')), findsOneWidget);
  });
}
