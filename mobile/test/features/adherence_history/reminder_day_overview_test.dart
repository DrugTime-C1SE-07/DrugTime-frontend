import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/features/adherence_history/presentation/widgets/history_motion.dart';
import 'package:drugtime_mobile/features/adherence_history/domain/entities/adherence_history.dart';
import 'package:drugtime_mobile/features/adherence_history/presentation/widgets/reminder_day_overview.dart';

void main() {
  testWidgets('timeline shows selected-day count and scheduled instants',
      (tester) async {
    final group = DateHistoryGroup(
      DateTime.utc(2026, 10, 19),
      const AdherenceSummary(
        total: 2,
        taken: 1,
        late: 0,
        missed: 0,
        pending: 1,
        counted: 1,
        rate: 100,
      ),
      [
        _dose(1, 8, HistoryDoseStatus.taken),
        _dose(2, 20, HistoryDoseStatus.pending),
      ],
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ReminderDayOverview(
          day: DateTime.utc(2026, 10, 19),
          today: DateTime.utc(2026, 10, 21),
          group: group,
        ),
      ),
    ));
    // The taken count runs up from 0 (AC6); the final value is checked once it settles.
    await tester.pumpAndSettle();

    expect(find.text('Hộp thuốc 19/10'), findsOneWidget);
    expect(find.text('1/2 liều'), findsOneWidget);
    expect(find.text('08:00'), findsOneWidget);
    expect(find.text('20:00'), findsOneWidget);
    expect(
        find.byKey(const Key('history-dose-timeline-scroll')), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('overview ring counts to ratio without adherence wording (AC6)',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final day = DateTime.utc(2026, 10, 19);
    final group = _group(day, [
      _dose(1, 7, HistoryDoseStatus.taken),
      _dose(2, 9, HistoryDoseStatus.taken),
      _dose(3, 12, HistoryDoseStatus.late),
      _dose(4, 18, HistoryDoseStatus.missed),
      _dose(5, 21, HistoryDoseStatus.missed),
    ]);
    await tester.pumpWidget(_overview(day, DateTime.utc(2026, 10, 21), group));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    // Mid-animation: the visible count is still running up, the spoken label is final.
    expect(find.text('3/5 liều'), findsNothing);
    expect(find.bySemanticsLabel('3/5 liều'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('3/5 liều'), findsOneWidget);
    expect(find.byKey(const Key('history-progress-ring')), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
    expect(find.textContaining('tuân thủ'), findsNothing);
    expect(find.bySemanticsLabel(RegExp('%|tuân thủ')), findsNothing);
    semantics.dispose();
  });

  testWidgets('reduced motion shows the final ratio on the first frame',
      (tester) async {
    final day = DateTime.utc(2026, 10, 19);
    final group = _group(day, [
      _dose(1, 7, HistoryDoseStatus.taken),
      _dose(2, 21, HistoryDoseStatus.pending),
    ]);
    await tester.pumpWidget(
        _overview(day, DateTime.utc(2026, 10, 21), group, reduced: true));
    expect(find.text('1/2 liều'), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('today strip auto-scrolls to the first pending dose (AC7)',
      (tester) async {
    final today = DateTime.utc(2026, 10, 19);
    final doses = [
      for (var h = 6; h <= 11; h++) _dose(h, h, HistoryDoseStatus.taken),
      _dose(12, 12, HistoryDoseStatus.pending),
      _dose(20, 20, HistoryDoseStatus.pending),
    ];
    await tester
        .pumpWidget(_overview(today, today, _group(today, doses), width: 260));
    await tester.pumpAndSettle();
    final strip = find.byKey(const Key('history-dose-timeline-scroll'));
    final noon = find.text('12:00');
    final stripRect = tester.getRect(strip);
    expect(stripRect.contains(tester.getCenter(noon)), isTrue);
    expect(tester.widget<SingleChildScrollView>(strip).controller!.offset,
        greaterThan(0));

    // A past day keeps the strip at its start (the screen builds a fresh box per day).
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_overview(
        today, DateTime.utc(2026, 10, 21), _group(today, doses),
        width: 260));
    await tester.pumpAndSettle();
    expect(find.text('06:00'), findsOneWidget);
    expect(tester.getRect(find.text('06:00')).left,
        greaterThanOrEqualTo(stripRect.left));
  });

  testWidgets('empty day shows a calm empty state and zero count',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ReminderDayOverview(
          day: DateTime.utc(2026, 10, 21),
          today: DateTime.utc(2026, 10, 21),
          group: null,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Hộp thuốc hôm nay'), findsOneWidget);
    expect(find.text('0/0 liều'), findsOneWidget);
    expect(find.text('Chưa có liều trong ngày này'), findsOneWidget);
  });
}

DateHistoryGroup _group(DateTime day, List<HistoryDose> doses) {
  int count(HistoryDoseStatus s) => doses.where((d) => d.status == s).length;
  return DateHistoryGroup(
    day,
    AdherenceSummary(
      total: doses.length,
      taken: count(HistoryDoseStatus.taken),
      late: count(HistoryDoseStatus.late),
      missed: count(HistoryDoseStatus.missed),
      pending: count(HistoryDoseStatus.pending),
      counted: doses.length - count(HistoryDoseStatus.pending),
      rate: null,
    ),
    doses,
  );
}

Widget _overview(DateTime day, DateTime today, DateHistoryGroup? group,
        {double width = 375, bool reduced = false}) =>
    MaterialApp(
      home: MediaQuery(
        data:
            MediaQueryData(size: Size(width, 800), disableAnimations: reduced),
        child: HistoryMotionScope(
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: width,
                child:
                    ReminderDayOverview(day: day, today: today, group: group),
              ),
            ),
          ),
        ),
      ),
    );

HistoryDose _dose(int id, int hour, HistoryDoseStatus status) => HistoryDose(
      medicationId: id,
      medicationName: 'Thuốc $id',
      scheduleId: id,
      scheduledAt: DateTime.utc(2026, 10, 19, hour - 7),
      takenAt: null,
      status: status,
      statusSource: 'fixture',
    );
