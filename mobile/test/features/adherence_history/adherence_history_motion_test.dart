import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/features/adherence_history/data/models/adherence_history_api_mapper.dart';
import 'package:drugtime_mobile/features/adherence_history/presentation/screens/adherence_month_screen.dart';
import 'package:drugtime_mobile/features/adherence_history/presentation/widgets/dose_history_tile.dart';
import 'package:drugtime_mobile/features/adherence_history/presentation/widgets/history_feedback.dart';
import 'package:drugtime_mobile/features/adherence_history/presentation/widgets/history_motion.dart';
import 'package:drugtime_mobile/features/adherence_history/presentation/widgets/medication_history_list.dart';
import 'adherence_history_test_helpers.dart';

void main() {
  testWidgets(
      'reduced motion displays the destination immediately with stable percentage semantics',
      (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      final c = await pumpHistory(tester, FakeHistoryRepository(),
          reducedMotion: true);
      await c.selectDay(DateTime.utc(2026, 10, 19));
      await tester.pump();
      final summary = find.byKey(const Key('history-summary'));
      final position = tester.getTopLeft(summary);
      final rate =
          find.bySemanticsLabel('Tỷ lệ tuân thủ trên các liều đã có kết quả');
      final node = tester.getSemantics(rate);
      expect(node.value, '66,67%');
      final id = node.id;
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.getTopLeft(summary), position);
      expect(tester.getSemantics(rate).id, id);
      expect(tester.getSemantics(rate).value, '66,67%');
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.getTopLeft(summary), position);
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });
  testWidgets(
      'incoming content settles within 500ms and does not replay on expansion',
      (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      final c = await pumpHistory(tester, FakeHistoryRepository());
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final focus = FocusManager.instance.primaryFocus;
      expect(focus, isNotNull);
      expect(focus, isNot(FocusManager.instance.rootScope));
      await c.selectDay(DateTime.utc(2026, 10, 19));
      await tester.pump();
      final summary = find.byKey(const Key('history-summary'));
      final initial = tester.getTopLeft(summary);
      expect(find.text('66,67%'), findsOneWidget);
      final rate =
          find.bySemanticsLabel('Tỷ lệ tuân thủ trên các liều đã có kết quả');
      final rateId = tester.getSemantics(rate).id;
      for (final milliseconds in [80, 160, 260]) {
        await tester.pump(Duration(milliseconds: milliseconds));
        expect(FocusManager.instance.primaryFocus, same(focus));
        expect(tester.getSemantics(rate).id, rateId);
        expect(tester.getSemantics(rate).value, '66,67%');
      }
      final finalPosition = tester.getTopLeft(summary);
      expect(initial.dy, greaterThan(finalPosition.dy));
      c.toggleMedication(7);
      await tester.pump();
      expect(tester.getTopLeft(summary), finalPosition);
      await c.selectDay(DateTime.utc(2026, 10, 20));
      await tester.pump();
      expect(find.text('Metformin 500 mg', skipOffstage: false), findsNothing);
      expect(find.text('Chưa có lịch sử'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets(
      'revoke and changed account remove incoming content on the first frame',
      (tester) async {
    final repo = FakeHistoryRepository();
    final c = await pumpHistory(tester, repo);
    await c.selectDay(DateTime.utc(2026, 10, 19));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    c.revoke();
    await tester.pump();
    expect(find.byType(DoseHistoryTile, skipOffstage: false), findsNothing);
    expect(find.byKey(const Key('history-summary'), skipOffstage: false),
        findsNothing);
    c.allowFreshRead();
    repo.delayed = true;
    final pending = c.load();
    await tester.pump();
    expect(find.byType(HistoryLoading), findsOneWidget);
    c.setPatient('two');
    repo.pending.single
        .complete(AdherenceHistoryApiMapper.parse(historyFixture()));
    await pending;
    await tester.pump();
    expect(find.text('Metformin 500 mg', skipOffstage: false), findsNothing);
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'route clear during navigation does not retain the outgoing day or child',
      (tester) async {
    final c = await pumpHistory(tester, FakeHistoryRepository());
    await c.selectDay(DateTime.utc(2026, 10, 19));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Mở lịch tháng'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    c.revoke();
    await tester.pump();
    expect(find.byType(DoseHistoryTile, skipOffstage: false), findsNothing);
    expect(find.text('Metformin 500 mg', skipOffstage: false), findsNothing);
    await tester.pump();
    expect(
        find.byType(AdherenceMonthScreen, skipOffstage: false), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'expanded group animates its height, clear removes rows immediately',
      (tester) async {
    final c = await pumpHistory(tester, FakeHistoryRepository());
    await openMedicationHistory(tester);
    final list = find.byType(MedicationHistoryList);
    final collapsed = tester.getSize(list).height;
    c.toggleMedication(7);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final middle = tester.getSize(list).height;
    await tester.pump(const Duration(milliseconds: 400));
    expect(middle, greaterThan(collapsed));
    expect(tester.getSize(list).height, greaterThanOrEqualTo(middle));
    c.toggleMedication(7);
    await tester.pump();
    c.revoke();
    await tester.pump();
    expect(find.byType(DoseHistoryTile, skipOffstage: false), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shimmer stops when hidden, inactive, reduced, or removed',
      (tester) async {
    var active = true, reduced = false, visible = true;
    late StateSetter update;
    await tester.pumpWidget(
        MaterialApp(home: StatefulBuilder(builder: (context, setState) {
      update = setState;
      return MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
          child: HistoryMotionScope(
              active: active,
              child:
                  visible ? const HistoryLoading() : const Text('Finished')));
    })));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    update(() => active = false);
    await tester.pump();
    expect(find.byType(ShaderMask), findsNothing);
    expect(tester.binding.transientCallbackCount, 0);
    update(() => active = true);
    await tester.pump();
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    update(() => reduced = true);
    await tester.pump();
    expect(find.byType(ShaderMask), findsNothing);
    expect(tester.binding.transientCallbackCount, 0);
    update(() => visible = false);
    await tester.pump();
    expect(find.text('Finished'), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });
}
