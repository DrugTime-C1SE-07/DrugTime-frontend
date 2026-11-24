import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/features/adherence_history/data/models/adherence_history_api_mapper.dart';
import 'package:drugtime_mobile/features/adherence_history/domain/entities/adherence_history.dart';
import 'package:drugtime_mobile/features/adherence_history/domain/entities/adherence_history_failure.dart';
import 'package:drugtime_mobile/features/adherence_history/presentation/screens/adherence_month_screen.dart';
import 'package:drugtime_mobile/features/adherence_history/presentation/widgets/dose_history_tile.dart';
import 'package:drugtime_mobile/features/adherence_history/presentation/widgets/history_feedback.dart';
import 'package:drugtime_mobile/features/adherence_history/presentation/widgets/history_motion.dart';
import 'package:drugtime_mobile/features/adherence_history/presentation/widgets/medication_history_list.dart';
import 'adherence_history_test_helpers.dart';

void main() {
  testWidgets(
      'reduced motion displays the destination immediately with stable ratio semantics (AC15)',
      (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      final c = await pumpHistory(tester, FakeHistoryRepository(),
          reducedMotion: true);
      await c.selectDay(DateTime.utc(2026, 10, 19));
      await tester.pump();
      final summary = find.byKey(const Key('history-summary'));
      final position = tester.getTopLeft(summary);
      // The overview shows the day's taken/total count, never an adherence percentage (QD-42).
      expect(find.text('2/4 liều'), findsOneWidget);
      final ratio = find.bySemanticsLabel(RegExp('2/4 liều'));
      final id = tester.getSemantics(ratio).id;
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.getTopLeft(summary), position);
      expect(tester.getSemantics(ratio).id, id);
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
      final ratio = find.bySemanticsLabel(RegExp('2/4 liều'));
      final ratioId = tester.getSemantics(ratio).id;
      for (final milliseconds in [80, 160, 260]) {
        await tester.pump(Duration(milliseconds: milliseconds));
        expect(FocusManager.instance.primaryFocus, same(focus));
        expect(tester.getSemantics(ratio).id, ratioId);
      }
      final finalPosition = tester.getTopLeft(summary);
      expect(find.text('2/4 liều'), findsOneWidget);
      // 21 → 19 is an earlier day: the content came in from the left (AC1).
      expect(initial.dx, lessThan(finalPosition.dx));
      expect(initial.dy, finalPosition.dy);
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
  testWidgets('next day enters from the right, previous from the left (AC1)',
      (tester) async {
    final c = await pumpHistory(tester, FakeHistoryRepository());
    final summary = find.byKey(const Key('history-summary'));
    await c.selectDay(DateTime.utc(2026, 10, 19));
    await tester.pumpAndSettle();
    final rest = tester.getTopLeft(summary).dx;

    await c.selectDay(DateTime.utc(2026, 10, 20));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(tester.getTopLeft(summary).dx, greaterThan(rest));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.getTopLeft(summary).dx, closeTo(rest, .01));

    await c.selectDay(DateTime.utc(2026, 10, 19));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(tester.getTopLeft(summary).dx, lessThan(rest));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(summary).dx, closeTo(rest, .01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('period groups enter one after another (AC2)', (tester) async {
    final repo = FakeHistoryRepository()
      ..transform =
          (h) => spreadDay(h, DateTime.utc(2026, 10, 19), [8, 12, 15, 20]);
    final c = await pumpHistory(tester, repo);
    await c.selectDay(DateTime.utc(2026, 10, 19));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    double opacityOf(String period) => tester
        .widget<Opacity>(find
            .ancestor(
                of: find.byKey(ValueKey('period-$period')),
                matching: find.byType(Opacity))
            .first)
        .opacity;
    final morning = opacityOf('BUỔI SÁNG');
    final evening = opacityOf('BUỔI TỐI');
    expect(morning, greaterThan(evening));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('period-BUỔI TỐI')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'swipe on the dose list changes day; today and the strip ignore it (AC3, AC20)',
      (tester) async {
    final haptics = recordHaptics(tester);
    final c = await pumpHistory(tester, FakeHistoryRepository());
    final list = find.byKey(const Key('history-day-swipe'));

    // Today (21/10): swiping to a later day does nothing and does not buzz.
    await tester.fling(list, const Offset(-200, 0), 1200);
    await tester.pumpAndSettle();
    expect(c.selectedDay, DateTime.utc(2026, 10, 21));
    expect(haptics, isEmpty);

    await tester.fling(list, const Offset(200, 0), 1200);
    await tester.pumpAndSettle();
    expect(c.selectedDay, DateTime.utc(2026, 10, 20));
    expect(haptics, ['HapticFeedbackType.selectionClick']);

    await tester.fling(list, const Offset(200, 0), 1200);
    await tester.pumpAndSettle();
    expect(c.selectedDay, DateTime.utc(2026, 10, 19));

    // Dragging the overview's hour strip only scrolls the strip.
    await tester.fling(find.byKey(const Key('history-dose-timeline-scroll')),
        const Offset(200, 0), 1200);
    await tester.pumpAndSettle();
    expect(c.selectedDay, DateTime.utc(2026, 10, 19));

    await tester.fling(list, const Offset(-200, 0), 1200);
    await tester.pumpAndSettle();
    expect(c.selectedDay, DateTime.utc(2026, 10, 20));
    expect(haptics, hasLength(3));

    // A change coming from data (not a gesture) does not buzz.
    await c.load();
    await tester.pumpAndSettle();
    expect(haptics, hasLength(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'reduced motion: swipe, week change and detail settle in one pump (AC15)',
      (tester) async {
    final c =
        await pumpHistory(tester, FakeHistoryRepository(), reducedMotion: true);
    await tester.fling(
        find.byKey(const Key('history-day-swipe')), const Offset(200, 0), 1200);
    await tester.pump();
    expect(c.selectedDay, DateTime.utc(2026, 10, 20));
    expect(tester.hasRunningAnimations, isFalse);
    // Week cell selected from code (a tap would start Material's ink ripple, which is not
    // part of this screen's motion).
    await c.selectDay(DateTime.utc(2026, 10, 19));
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
    expect(find.text('2/4 liều'), findsOneWidget);
    expect(
        tester.getCenter(find.byKey(const Key('history-week-indicator'))).dx,
        closeTo(
            tester.getCenter(find.byKey(const ValueKey('history-week-19'))).dx,
            1));
    await tester.tap(find.byType(DoseHistoryTile).first);
    await tester.pump();
    await tester.pump();
    // The detail page is fully in place right away (zero-length route, no hero flight).
    expect(find.text('Chi tiết liều dùng'), findsOneWidget);
    expect(find.byType(DoseHistoryTile), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'failed cross-month load shows the error, retry enters normally (AC18)',
      (tester) async {
    final repo = FakeHistoryRepository();
    final c = await pumpHistory(tester, repo);
    repo.failure = const HistoryFailure(HistoryFailureKind.network);
    await c.selectDay(DateTime.utc(2026, 9, 30));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text(const HistoryFailure(HistoryFailureKind.network).message),
        findsOneWidget);
    expect(find.byKey(const Key('history-summary')), findsNothing);
    expect(find.byType(DoseHistoryTile, skipOffstage: false), findsNothing);
    await tester.pumpAndSettle();
    repo.failure = null;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(c.selectedDay, DateTime.utc(2026, 9, 30));
    expect(find.byKey(const Key('history-summary')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

/// Moves the seeded doses of [day] to the given Vietnam hours, one dose per hour.
AdherenceHistory spreadDay(AdherenceHistory h, DateTime day, List<int> hours) =>
    AdherenceHistory(
      patientId: h.patientId,
      from: h.from,
      to: h.to,
      asOf: h.asOf,
      mode: h.mode,
      summary: h.summary,
      dates: [
        for (final g in h.dates)
          g.date == day
              ? DateHistoryGroup(g.date, g.summary, [
                  for (final (i, d) in g.doses.indexed)
                    HistoryDose(
                      medicationId: d.medicationId,
                      medicationName: d.medicationName,
                      scheduleId: d.scheduleId,
                      scheduledAt: DateTime.utc(day.year, day.month, day.day,
                          hours[i % hours.length] - 7),
                      takenAt: d.takenAt,
                      status: d.status,
                      statusSource: d.statusSource,
                    )
                ])
              : g,
      ],
    );
