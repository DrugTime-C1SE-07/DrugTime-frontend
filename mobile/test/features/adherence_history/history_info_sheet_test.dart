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
    await _pumpButton(tester);
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
    final c = await _pumpButton(tester);
    await tester.tap(find.byType(HistoryInfoButton));
    await tester.pumpAndSettle();
    c.revoke();
    await tester.pump();
    expect(find.text('Về lịch sử', skipOffstage: false), findsNothing);
    await tester.pumpAndSettle();
    expect(find.byType(HistoryInfoButton), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

/// The Lịch nhắc tab no longer shows the button, so it is mounted on its own, as on the
/// other history pages that still carry it.
Future<AdherenceHistoryController> _pumpButton(WidgetTester tester) async {
  final c = AdherenceHistoryController(FakeHistoryRepository(),
      clock: () => historyNow)
    ..setPatient('one');
  addTearDown(c.dispose);
  await tester.pumpWidget(AdherenceHistoryScope(
      controller: c,
      child: const MaterialApp(home: Scaffold(body: HistoryInfoButton()))));
  await c.load();
  await tester.pump();
  return c;
}
