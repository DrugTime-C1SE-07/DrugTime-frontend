import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/features/adherence_history/presentation/widgets/history_info_sheet.dart';
import 'package:drugtime_mobile/features/adherence_history/presentation/state/adherence_history_controller.dart';
import 'adherence_history_test_helpers.dart';

void main() {
  testWidgets(
      'enabling reduced motion during sheet entrance completes immediately',
      (tester) async {
    final c = AdherenceHistoryController(FakeHistoryRepository(),
        clock: () => historyNow)
      ..setPatient('one');
    addTearDown(c.dispose);
    var reduced = false;
    late StateSetter update;
    await tester.pumpWidget(AdherenceHistoryScope(
        controller: c,
        child: MaterialApp(home: StatefulBuilder(builder: (context, setState) {
          update = setState;
          return MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
              child: const Scaffold(body: HistoryInfoButton()));
        }))));
    await tester.tap(find.byType(HistoryInfoButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    update(() => reduced = true);
    await tester.pump();
    await tester.pump();
    final route = ModalRoute.of(tester.element(find.text('Về lịch sử')))!;
    expect(route.animation!.value, 1);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'info opens, explains short labels, closes and restores opener focus',
      (tester) async {
    await pumpHistory(tester, FakeHistoryRepository());
    final opener = find.byType(HistoryInfoButton);
    await tester.tap(opener);
    await tester.pumpAndSettle();
    expect(find.textContaining('Liều chờ chưa tính'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Về lịch sử'), findsNothing);
    final button = tester.widget<IconButton>(
        find.descendant(of: opener, matching: find.byType(IconButton)));
    expect(button.focusNode!.hasFocus, true);
  });
  testWidgets(
      'revoke removes information at first frame and only closes owned sheet',
      (tester) async {
    final c = await pumpHistory(tester, FakeHistoryRepository());
    await tester.tap(find.byType(HistoryInfoButton));
    await tester.pumpAndSettle();
    c.revoke();
    await tester.pump();
    expect(find.text('Về lịch sử', skipOffstage: false), findsNothing);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('history-title')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
