import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/features/adherence_history/domain/entities/adherence_history.dart';
import 'package:drugtime_mobile/features/adherence_history/domain/entities/adherence_history_failure.dart';
import 'package:drugtime_mobile/features/adherence_history/presentation/screens/adherence_month_screen.dart';
import 'package:drugtime_mobile/features/adherence_history/presentation/screens/medication_history_screen.dart';
import 'package:drugtime_mobile/features/adherence_history/presentation/widgets/adherence_calendar.dart';
import 'package:drugtime_mobile/features/adherence_history/presentation/widgets/dose_history_tile.dart';
import 'adherence_history_test_helpers.dart';

void main() {
  testWidgets('day defaults to today and week selection updates inline',
      (tester) async {
    final repo = FakeHistoryRepository();
    final c = await pumpHistory(tester, repo);
    expect(c.selectedDay, DateTime.utc(2026, 10, 21));
    expect(find.byKey(const Key('history-title')), findsOneWidget);
    expect(find.byType(AdherenceCalendar), findsNothing);
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.text('Chưa có lịch sử'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('history-week-19')));
    await tester.pumpAndSettle();
    expect(c.selectedDay, DateTime.utc(2026, 10, 19));
    expect(find.text('66,67%'), findsOneWidget);
    expect(find.textContaining('Tạm tính'), findsOneWidget);
    expect(c.selectedGroup?.doses, hasLength(4));
    expect(find.byType(DoseHistoryTile), findsWidgets);
    expect(find.byType(AdherenceMonthScreen), findsNothing);
    expect(repo.calls.length, 1);
  });

  testWidgets('calendar selection updates card, CTA and Back preserve day',
      (tester) async {
    final c = await pumpHistory(tester, FakeHistoryRepository());
    await openHistoryMonth(tester);
    expect(find.byType(AdherenceMonthScreen), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('history-day-19')));
    await tester.pumpAndSettle();
    expect(c.selectedDay, DateTime.utc(2026, 10, 19));
    expect(find.byType(DoseHistoryTile), findsNothing);
    expect(find.text('66,67%'), findsOneWidget);
    final button = find.byKey(const Key('history-view-day'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.byType(AdherenceMonthScreen), findsNothing);
    expect(c.selectedGroup?.doses, hasLength(4));
    expect(find.byType(DoseHistoryTile), findsWidgets);
    await openHistoryMonth(tester);
    await tester.tap(find.byKey(const ValueKey('history-day-20')));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(c.selectedDay, DateTime.utc(2026, 10, 20));
    expect(find.text('Chưa có lịch sử'), findsOneWidget);
    expect(find.byType(AdherenceMonthScreen), findsNothing);
  });

  testWidgets('double calendar tap opens once; month reload keeps its page',
      (tester) async {
    final repo = FakeHistoryRepository();
    final c = await pumpHistory(tester, repo);
    final open = tester
        .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.calendar_month_outlined))
        .onPressed!;
    open();
    open();
    await tester.pumpAndSettle();
    expect(find.byType(AdherenceMonthScreen), findsOneWidget);
    await tester.tap(find.byTooltip('Tháng trước'));
    await tester.pumpAndSettle();
    expect(c.selectedDay, DateTime.utc(2026, 9, 1));
    expect(find.byType(AdherenceMonthScreen), findsOneWidget);
    expect(find.text('Tháng 9, 2026'), findsOneWidget);
    await tester.tap(find.byTooltip('Tháng sau'));
    await tester.pumpAndSettle();
    expect(c.selectedDay, c.today);
    expect(find.text('Xem ngày'), findsOneWidget);
    expect(repo.calls.length, 3);
  });

  testWidgets('future day cannot be selected in week or month', (tester) async {
    final c = await pumpHistory(tester, FakeHistoryRepository());
    await tester.tap(find.byKey(const ValueKey('history-week-22')));
    await tester.pumpAndSettle();
    expect(c.selectedDay, c.today);
    await openHistoryMonth(tester);
    await tester.tap(find.byKey(const ValueKey('history-day-22')));
    await tester.pumpAndSettle();
    expect(c.selectedDay, c.today);
  });

  testWidgets('medication menu opens collapsed groups and Back reloads date',
      (tester) async {
    final repo = FakeHistoryRepository();
    final c = await pumpHistory(tester, repo);
    await c.selectDay(DateTime.utc(2026, 10, 19));
    await tester.pumpAndSettle();
    await openMedicationHistory(tester);
    expect(find.byType(MedicationHistoryScreen), findsOneWidget);
    expect(find.byType(DoseHistoryTile), findsNothing);
    final tile = find.byKey(const ValueKey('history-medication-7'));
    await tester.ensureVisible(tile);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(c.expanded(7), isTrue);
    expect(find.textContaining('Đã uống ·'), findsOneWidget);
    expect(find.textContaining('Trễ ·'), findsOneWidget);
    expect(find.text('Bỏ lỡ'), findsOneWidget);
    expect(find.text('Chờ'), findsOneWidget);
    expect(find.text('Chưa ghi nhận đã uống'), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(c.selectedDay, DateTime.utc(2026, 10, 19));
    expect(repo.calls.last.mode, HistoryMode.date);
    expect(find.byType(MedicationHistoryScreen), findsNothing);
    expect(c.selectedGroup?.doses, hasLength(4));
    expect(find.byType(DoseHistoryTile), findsWidgets);
  });

  testWidgets(
      'error differs from empty; retry and loading do not show old summary',
      (tester) async {
    final repo = FakeHistoryRepository()
      ..failure = const HistoryFailure(HistoryFailureKind.network);
    final c = await pumpHistory(tester, repo);
    expect(find.byKey(const Key('history-error')), findsOneWidget);
    expect(find.text('Chưa có lịch sử'), findsNothing);
    repo.failure = null;
    repo.statuses = [];
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa tính'), findsOneWidget);
    expect(find.text('Chưa có lịch sử'), findsOneWidget);
    repo.delayed = true;
    final pending = c.load();
    await tester.pump();
    expect(find.byKey(const Key('history-summary')), findsNothing);
    repo.pending.single
        .completeError(const HistoryFailure(HistoryFailureKind.unavailable));
    await pending;
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('history-error')), findsOneWidget);
  });

  testWidgets(
      'day rate uses its group instead of overall month; pending stays provisional',
      (tester) async {
    final repo = FakeHistoryRepository()
      ..transform = (data) {
        final missed = List.generate(
            5,
            (i) => HistoryDose(
                medicationId: 7,
                medicationName: 'Other day',
                scheduleId: 20 + i,
                scheduledAt: DateTime.utc(2026, 10, 20, 1),
                takenAt: null,
                status: HistoryDoseStatus.missed,
                statusSource: 'recorded'));
        return AdherenceHistory(
          patientId: data.patientId,
          from: data.from,
          to: data.to,
          asOf: data.asOf,
          mode: data.mode,
          summary: const AdherenceSummary(
              total: 9,
              taken: 1,
              late: 1,
              missed: 6,
              pending: 1,
              counted: 8,
              rate: 25),
          dates: [
            ...data.dates,
            DateHistoryGroup(
                DateTime.utc(2026, 10, 20),
                const AdherenceSummary(
                    total: 5,
                    taken: 0,
                    late: 0,
                    missed: 5,
                    pending: 0,
                    counted: 5,
                    rate: 0),
                missed)
          ],
        );
      };
    final c = await pumpHistory(tester, repo);
    await c.selectDay(DateTime.utc(2026, 10, 19));
    await tester.pumpAndSettle();
    expect(find.text('66,67%'), findsOneWidget);
    expect(find.text('25%'), findsNothing);
    expect(find.text('2/4 đã uống'), findsOneWidget);
    expect(find.textContaining('1 chờ'), findsOneWidget);
    expect(find.textContaining('liều còn lại'), findsNothing);
  });

  testWidgets('late and pending at 100 percent do not claim completion',
      (tester) async {
    final repo = FakeHistoryRepository()
      ..statuses = ['uong_tre', 'cho_xac_nhan'];
    final c = await pumpHistory(tester, repo);
    await c.selectDay(DateTime.utc(2026, 10, 19));
    await tester.pumpAndSettle();
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('1/2 đã uống'), findsOneWidget);
    expect(find.textContaining('Tạm tính'), findsOneWidget);
    expect(find.text('Đủ liều'), findsNothing);
    expect(find.textContaining('Tất cả đúng giờ'), findsNothing);
    expect(find.textContaining('Trễ ·'), findsOneWidget);
  });
}
