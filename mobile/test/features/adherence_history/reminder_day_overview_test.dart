import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

    expect(find.text('Hộp thuốc 19/10'), findsOneWidget);
    expect(find.text('1/2 liều'), findsOneWidget);
    expect(find.text('08:00'), findsOneWidget);
    expect(find.text('20:00'), findsOneWidget);
    expect(
        find.byKey(const Key('history-dose-timeline-scroll')), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
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
    expect(find.text('Hộp thuốc hôm nay'), findsOneWidget);
    expect(find.text('0/0 liều'), findsOneWidget);
    expect(find.text('Chưa có liều trong ngày này'), findsOneWidget);
  });
}

HistoryDose _dose(int id, int hour, HistoryDoseStatus status) => HistoryDose(
      medicationId: id,
      medicationName: 'Thuốc $id',
      scheduleId: id,
      scheduledAt: DateTime.utc(2026, 10, 19, hour - 7),
      takenAt: null,
      status: status,
      statusSource: 'fixture',
    );
