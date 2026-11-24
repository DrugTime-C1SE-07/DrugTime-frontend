import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/core/utils/app_assets.dart';
import 'package:drugtime_mobile/features/adherence_history/presentation/widgets/dose_timeline_rail.dart';
import 'package:drugtime_mobile/features/adherence_history/domain/entities/adherence_history.dart';
import 'package:drugtime_mobile/features/adherence_history/domain/entities/adherence_history_failure.dart';
import 'package:drugtime_mobile/features/adherence_history/presentation/screens/adherence_month_screen.dart';
import 'package:drugtime_mobile/features/adherence_history/presentation/screens/medication_history_screen.dart';
import 'package:drugtime_mobile/features/adherence_history/presentation/widgets/adherence_calendar.dart';
import 'package:drugtime_mobile/features/adherence_history/presentation/widgets/dose_history_tile.dart';
import 'package:drugtime_mobile/core/storage/local_db/local_models.dart';
import 'package:drugtime_mobile/core/sync/schedule_sync_service.dart';
import 'package:drugtime_mobile/features/adherence_history/presentation/screens/adherence_history_screen.dart';
import 'package:drugtime_mobile/features/adherence_history/presentation/state/adherence_history_controller.dart';
import 'package:drugtime_mobile/features/home/presentation/home_schedule_controller.dart';
import 'adherence_history_test_helpers.dart';

class _ScheduleSource implements ScheduleRemoteDataSource {
  List<LocalMedicationSchedule> schedules = [];

  @override
  Future<List<LocalMedicationSchedule>> fetchSchedules({
    required String patientId,
  }) async =>
      schedules;
}

void main() {
  testWidgets('synced Home confirmation updates matching Reminder occurrence',
      (tester) async {
    final repo = FakeHistoryRepository()..statuses = [];
    final now = DateTime.parse('2026-10-19T07:50:00+07:00');
    final schedules = _ScheduleSource()
      ..schedules = [
        for (final (id, time) in [(4, '08:00:00'), (5, '08:01:00')])
          LocalMedicationSchedule(
            id: id,
            patientUserId: 'one',
            userMedicationId: id,
            medicationId: id,
            medicationName: 'Liều $id',
            quantityPerDose: '1',
            dosesPerDay: 1,
            intakeTime: time,
            daysOfWeek: const [1],
            reminderEnabled: true,
            effectiveFrom: DateTime.parse('2026-10-01T00:00:00+07:00'),
            serverSyncedAt: now,
          ),
      ];
    final history = AdherenceHistoryController(repo,
        clock: () => now, scheduleSource: schedules)
      ..setPatient('one');
    final home = HomeScheduleController(
        null, null, (_, __) async => HomeConfirmation.synced)
      ..setAccess('one', true);
    addTearDown(history.dispose);
    addTearDown(home.dispose);
    await tester.pumpWidget(MaterialApp(
      home: HomeScheduleScope(
        controller: home,
        child: AdherenceHistoryScope(
          controller: history,
          child: Scaffold(body: AdherenceHistoryScreen(clock: () => now)),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await history.selectDay(DateTime.utc(2026, 10, 19));
    await tester.pumpAndSettle();
    expect(find.byType(DoseHistoryTile), findsNWidgets(2));

    home.lastConfirmed = (4, DateTime.parse('2026-10-19T08:00:00+07:00'));
    home.confirmedSeq++;
    home.notifyListeners();
    await tester.pumpAndSettle();
    expect(history.selectedGroup?.doses, hasLength(2));
    expect(history.selectedGroup!.doses.any(history.isHomeConfirmed), isTrue);

    final confirmedTile =
        find.byKey(ValueKey((4, DateTime.parse('2026-10-19T08:00:00+07:00'))));
    expect(find.descendant(of: confirmedTile, matching: find.text('Đã uống')),
        findsOneWidget);
    final adjacentTile =
        find.byKey(ValueKey((5, DateTime.parse('2026-10-19T08:01:00+07:00'))));
    // At 07:50 the 08:01 dose is still ahead: it shows the countdown (AC11) instead of the
    // old "Chờ", which compared against the fixture's later `as_of`.
    expect(
        find.descendant(of: adjacentTile, matching: find.text('Còn 11 phút')),
        findsOneWidget);
  });

  testWidgets('refresh on tab return shows both newly saved future doses',
      (tester) async {
    final now = DateTime.parse('2026-10-21T08:36:00+07:00');
    final source = _ScheduleSource();
    final controller = AdherenceHistoryController(FakeHistoryRepository(),
        clock: () => now, scheduleSource: source)
      ..setPatient('one');
    addTearDown(controller.dispose);
    Future<void> showTab(bool active) async {
      await tester.pumpWidget(MaterialApp(
        home: AdherenceHistoryScope(
          controller: controller,
          child: Scaffold(
              body: AdherenceHistoryScreen(active: active, clock: () => now)),
        ),
      ));
      await tester.pumpAndSettle();
    }

    await showTab(true);
    expect(find.textContaining('Sắp tới'), findsNothing);
    await showTab(false);
    source.schedules = [
      for (final (id, time) in [
        (1, '13:00:00'),
        (2, '20:00:00'),
        (3, '13:01:00')
      ])
        LocalMedicationSchedule(
          id: id,
          patientUserId: 'one',
          userMedicationId: 1,
          medicationId: 1,
          medicationName: 'Thuốc thử nghiệm',
          quantityPerDose: '1',
          dosesPerDay: 2,
          intakeTime: time,
          daysOfWeek: const [3],
          reminderEnabled: true,
          effectiveFrom: now,
          serverSyncedAt: now,
        ),
    ];
    await showTab(true);
    expect(find.text('13:00'), findsNWidgets(2));
    final midday = find.byKey(const ValueKey('BUỔI TRƯA'));
    expect(find.text('Buổi trưa'), findsOneWidget);
    expect(find.descendant(of: midday, matching: find.byType(DoseHistoryTile)),
        findsNWidgets(2));

    final evening = find.byType(DoseHistoryTile).last;
    await tester.ensureVisible(evening);
    await tester.pumpAndSettle();
    await tester.tap(evening);
    await tester.pumpAndSettle();
    expect(find.text('Chi tiết liều dùng'), findsOneWidget);
  });

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
    expect(find.text('Thứ Hai, 19/10'), findsOneWidget);
    expect(find.text('2/4 liều'), findsOneWidget);
    expect(c.selectedGroup?.doses, hasLength(4));
    expect(find.byType(DoseHistoryTile), findsWidgets);
    expect(find.byType(AdherenceMonthScreen), findsNothing);
    expect(repo.calls.length, 1);
  });

  testWidgets('calendar selection updates card, CTA and Back preserve day',
      (tester) async {
    final c = await pumpHistory(tester, FakeHistoryRepository());
    await _openHistoryMonth(tester);
    expect(find.byType(AdherenceMonthScreen), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('history-day-19')));
    await tester.pumpAndSettle();
    expect(c.selectedDay, DateTime.utc(2026, 10, 19));
    expect(find.byType(DoseHistoryTile), findsNothing);
    expect(find.text('Thứ 2, 19/10/2026'), findsOneWidget);
    final button = find.byKey(const Key('history-view-day'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.byType(AdherenceMonthScreen), findsNothing);
    expect(c.selectedGroup?.doses, hasLength(4));
    expect(find.byType(DoseHistoryTile), findsWidgets);
    await _openHistoryMonth(tester);
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
    await tester.tap(find.byTooltip('Chọn tháng'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tháng trước'));
    await tester.pumpAndSettle();
    expect(c.selectedDay, DateTime.utc(2026, 9, 1));
    expect(find.byType(AdherenceMonthScreen), findsOneWidget);
    expect(find.text('Tháng 9, 2026'), findsOneWidget);
    await tester.tap(find.byTooltip('Chọn tháng'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tháng sau'));
    await tester.pumpAndSettle();
    expect(c.selectedDay, c.today);
    expect(find.text('Xem chi tiết ngày hôm nay'), findsOneWidget);
    expect(repo.calls.length, 3);
  });

  testWidgets('future day cannot be selected in week or month', (tester) async {
    final c = await pumpHistory(tester, FakeHistoryRepository());
    await tester.tap(find.byKey(const ValueKey('history-week-22')));
    await tester.pumpAndSettle();
    expect(c.selectedDay, c.today);
    await _openHistoryMonth(tester);
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
    await _openMedicationHistory(tester);
    expect(find.byType(MedicationHistoryScreen), findsOneWidget);
    expect(find.byType(DoseHistoryTile), findsNothing);
    final tile = find.byKey(const ValueKey('history-medication-7'));
    await tester.ensureVisible(tile);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(c.expanded(7), isTrue);
    expect(find.text('Đã uống'), findsOneWidget);
    expect(find.text('Trễ'), findsOneWidget);
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
    expect(find.text('0/0 liều'), findsOneWidget);
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
    expect(find.text('Thứ Hai, 19/10'), findsOneWidget);
    expect(find.text('25%'), findsNothing);
    expect(find.text('2/4 liều'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.textContaining('liều còn lại'), findsNothing);
  });

  testWidgets('late and pending at 100 percent do not claim completion',
      (tester) async {
    final repo = FakeHistoryRepository()
      ..statuses = ['uong_tre', 'cho_xac_nhan'];
    final c = await pumpHistory(tester, repo);
    await c.selectDay(DateTime.utc(2026, 10, 19));
    await tester.pumpAndSettle();
    expect(find.text('100%'), findsNothing);
    expect(find.text('1/2 liều'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('Đủ liều'), findsNothing);
    expect(find.textContaining('Tất cả đúng giờ'), findsNothing);
    expect(find.text('Trễ'), findsOneWidget);
  });

  group('day timeline (AC10, AC11, AC14, AC16)', () {
    final today = DateTime.utc(2026, 10, 21);
    HistoryDose dose(int id, int hour, int minute, HistoryDoseStatus status) =>
        HistoryDose(
          medicationId: 7,
          medicationName: 'Thuốc $id',
          scheduleId: 100 + id,
          scheduledAt: DateTime.utc(2026, 10, 21, hour - 7, minute),
          takenAt: status == HistoryDoseStatus.taken
              ? DateTime.utc(2026, 10, 21, hour - 7, minute + 5)
              : null,
          status: status,
          statusSource: 'fixture',
        );

    /// Adds a "today" group to the seeded history.
    AdherenceHistory withToday(AdherenceHistory h, List<HistoryDose> doses) {
      int count(HistoryDoseStatus s) =>
          doses.where((d) => d.status == s).length;
      final summary = AdherenceSummary(
        total: doses.length,
        taken: count(HistoryDoseStatus.taken),
        late: count(HistoryDoseStatus.late),
        missed: count(HistoryDoseStatus.missed),
        pending: count(HistoryDoseStatus.pending),
        counted: doses.length - count(HistoryDoseStatus.pending),
        rate: null,
      );
      return AdherenceHistory(
        patientId: h.patientId,
        from: h.from,
        to: h.to,
        asOf: h.asOf,
        mode: h.mode,
        summary: h.summary,
        dates: [...h.dates, DateHistoryGroup(today, summary, doses)],
      );
    }

    Finder tileOf(int id) => find.byWidgetPredicate(
        (w) => w is DoseHistoryTile && w.dose.scheduleId == 100 + id);
    String mascot(WidgetTester tester) => (tester
            .widget<Image>(find.descendant(
                of: find.byKey(const Key('reminder-scene-header')),
                matching: find.byType(Image)))
            .image as AssetImage)
        .assetName;

    testWidgets(
        'now marker sits between passed and upcoming doses, ticks each minute',
        (tester) async {
      final semantics = tester.ensureSemantics();
      // 03:00 UTC = 10:00 in Vietnam; the device zone does not matter.
      var now = DateTime.utc(2026, 10, 21, 3);
      final repo = FakeHistoryRepository()
        ..transform = (h) => withToday(h, [
              dose(1, 8, 0, HistoryDoseStatus.taken),
              dose(2, 10, 25, HistoryDoseStatus.pending),
              dose(3, 18, 0, HistoryDoseStatus.pending),
            ]);
      await pumpHistory(tester, repo, clock: () => now);
      final marker = find.byKey(const Key('history-now-marker'));
      expect(marker, findsOneWidget);
      expect(find.text('Bây giờ · 10:00'), findsOneWidget);
      expect(tester.getTopLeft(marker).dy,
          greaterThan(tester.getTopLeft(tileOf(1)).dy));
      expect(tester.getTopLeft(marker).dy,
          lessThan(tester.getTopLeft(tileOf(2)).dy));
      // Countdown under 60 minutes, plain "Sắp tới" further ahead; no confirm action.
      expect(find.descendant(of: tileOf(2), matching: find.text('Còn 25 phút')),
          findsOneWidget);
      expect(find.descendant(of: tileOf(3), matching: find.text('Sắp tới')),
          findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('còn 25 phút')), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
      // Rail: the dose already due is drawn as passed, the later ones are not.
      Color? dotOf(int id) {
        final row =
            find.ancestor(of: tileOf(id), matching: find.byType(Stack)).first;
        final dot = tester.widget<Container>(find.descendant(
            of: row, matching: find.byKey(const Key('dose-rail-dot'))));
        return (dot.decoration as BoxDecoration).color;
      }

      expect(dotOf(1), DoseRailSegment.passedColor);
      expect(dotOf(2), isNot(DoseRailSegment.passedColor));

      // Next minute boundary: no reload needed, the line and countdown follow the clock.
      final calls = repo.calls.length;
      now = DateTime.utc(2026, 10, 21, 3, 26);
      await tester.pump(const Duration(minutes: 1));
      await tester.pump();
      // Let the badge cross-fade finish.
      await tester.pump(const Duration(milliseconds: 300));
      expect(repo.calls.length, calls);
      expect(find.text('Bây giờ · 10:26'), findsOneWidget);
      expect(tester.getTopLeft(marker).dy,
          greaterThan(tester.getTopLeft(tileOf(2)).dy));
      expect(tester.getTopLeft(marker).dy,
          lessThan(tester.getTopLeft(tileOf(3)).dy));
      // 10:25 has passed: its badge falls back to the real status, not "Sắp tới".
      expect(
          find.descendant(of: tileOf(2), matching: find.textContaining('Còn')),
          findsNothing);
      expect(find.descendant(of: tileOf(2), matching: find.text('Sắp tới')),
          findsNothing);
      semantics.dispose();
    });

    testWidgets('no marker on another day; mascot follows today',
        (tester) async {
      final repo = FakeHistoryRepository()
        ..transform = (h) => withToday(h, [
              dose(1, 8, 0, HistoryDoseStatus.taken),
              dose(2, 18, 0, HistoryDoseStatus.pending),
            ]);
      final c = await pumpHistory(tester, repo);
      expect(find.byKey(const Key('history-now-marker')), findsOneWidget);
      expect(mascot(tester), AppAssets.mascotHello);
      await c.selectDay(DateTime.utc(2026, 10, 19));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('history-now-marker')), findsNothing);
      // Viewing another day keeps the mascot on today's progress.
      expect(mascot(tester), AppAssets.mascotHello);
    });

    testWidgets('today all taken → happy, any missed → thinking',
        (tester) async {
      final happy = FakeHistoryRepository()
        ..transform = (h) => withToday(h, [
              dose(1, 7, 0, HistoryDoseStatus.taken),
              dose(2, 9, 0, HistoryDoseStatus.taken),
            ]);
      await pumpHistory(tester, happy);
      expect(mascot(tester), AppAssets.mascotHappy);
      // All doses are behind "now": the line sits after the last one.
      expect(tester.getTopLeft(find.byKey(const Key('history-now-marker'))).dy,
          greaterThan(tester.getTopLeft(tileOf(2)).dy));

      final thinking = FakeHistoryRepository()
        ..transform = (h) => withToday(h, [
              dose(1, 7, 0, HistoryDoseStatus.missed),
              dose(2, 18, 0, HistoryDoseStatus.pending),
            ]);
      await tester.pumpWidget(const SizedBox());
      await pumpHistory(tester, thinking);
      expect(mascot(tester), AppAssets.mascotThinking);
      expect(find.bySemanticsLabel('Dumi, linh vật DrugTime'), findsOneWidget);
    });

    testWidgets('returning to the app refreshes the clock at once',
        (tester) async {
      var now = DateTime.utc(2026, 10, 21, 3);
      final repo = FakeHistoryRepository()
        ..transform = (h) => withToday(h, [
              dose(1, 8, 0, HistoryDoseStatus.taken),
              dose(2, 18, 0, HistoryDoseStatus.pending),
            ]);
      await pumpHistory(tester, repo, clock: () => now);
      expect(find.text('Bây giờ · 10:00'), findsOneWidget);
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pump();
      now = DateTime.utc(2026, 10, 21, 3, 40);
      for (final state in [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pumpAndSettle();
      expect(find.text('Bây giờ · 10:40'), findsOneWidget);
    });
  });
}

Future<void> _openHistoryMonth(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Mở lịch tháng'));
  await tester.pumpAndSettle();
}

Future<void> _openMedicationHistory(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Tùy chọn lịch sử'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Theo thuốc'));
  await tester.pumpAndSettle();
}
