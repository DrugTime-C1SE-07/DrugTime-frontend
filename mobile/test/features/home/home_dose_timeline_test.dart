import 'package:drugtime_mobile/features/adherence_history/domain/entities/adherence_history.dart';
import 'package:drugtime_mobile/features/home/presentation/home_schedule_controller.dart';
import 'package:drugtime_mobile/features/home/presentation/widgets/home_dose_timeline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 07:50 giờ Việt Nam.
final _now = DateTime.utc(2026, 11, 17, 0, 50);

HistoryDose _dose(int id, int h, HistoryDoseStatus s, {DateTime? takenAt}) =>
    HistoryDose(
      medicationId: id,
      medicationName: 'Thuốc $id',
      scheduleId: id,
      scheduledAt: DateTime.utc(2026, 11, 17, h - 7),
      takenAt: takenAt,
      status: s,
      statusSource: 'test',
    );

DateHistoryGroup _day(List<HistoryDose> doses) => DateHistoryGroup(
    DateTime.utc(2026, 11, 17),
    AdherenceSummary(
        total: doses.length,
        taken: doses.where((d) => d.status == HistoryDoseStatus.taken).length,
        late: 0,
        missed: doses.where((d) => d.status == HistoryDoseStatus.missed).length,
        pending:
            doses.where((d) => d.status == HistoryDoseStatus.pending).length,
        counted: doses.length,
        rate: null),
    doses);

Widget _app(HomeScheduleController c) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: HomeDoseTimeline(
              controller: c, now: _now, onAdd: () {}, onScan: () {}),
        ),
      ),
    );

void main() {
  setUp(HomeDoseTimeline.pulsed.clear);

  testWidgets('liều bỏ lỡ pulse đúng một lần, dựng lại không pulse nữa (AC18)',
      (t) async {
    final c = HomeScheduleController(
        null, null, (_, __) async => HomeConfirmation.synced)
      ..day = _day([
        _dose(1, 6, HistoryDoseStatus.missed),
        _dose(2, 8, HistoryDoseStatus.pending)
      ]);
    await t.pumpWidget(_app(c));
    expect(find.text('06:00 · Bỏ lỡ'), findsOneWidget);
    expect(
        find.byType(AnimatedBuilder).evaluate().where((e) {
          return (e.widget as AnimatedBuilder).animation is AnimationController;
        }),
        isNotEmpty);
    await t.pumpAndSettle();
    expect(HomeDoseTimeline.pulsed, hasLength(1));

    await t.pumpWidget(const SizedBox());
    await t.pumpWidget(_app(c));
    final pulsing = find.byType(AnimatedBuilder).evaluate().where(
        (e) => (e.widget as AnimatedBuilder).animation is AnimationController);
    expect(pulsing, isEmpty);
  });

  testWidgets('liều kế tiếp: nhãn đếm phút và nút Đã uống', (t) async {
    final c = HomeScheduleController(
        null, null, (_, __) async => HomeConfirmation.synced, clock: () => _now)
      ..day = _day([
        _dose(1, 7, HistoryDoseStatus.taken),
        _dose(2, 8, HistoryDoseStatus.pending)
      ]);
    await t.pumpWidget(_app(c));
    expect(find.text('Liều tiếp theo · 10 phút nữa'), findsOneWidget);
    expect(find.text('Đã uống'), findsNWidgets(2)); // badge dòng 07:00 + nút
    expect(find.widgetWithText(FilledButton, 'Đã uống'), findsOneWidget);
  });

  testWidgets(
      'xác nhận thành công: thẻ ăn mừng → thu gọn có badge → liều kế mở (AC19)',
      (t) async {
    final c = HomeScheduleController(
        null, null, (_, __) async => HomeConfirmation.synced, clock: () => _now)
      ..day = _day([
        _dose(1, 8, HistoryDoseStatus.pending),
        _dose(2, 20, HistoryDoseStatus.pending)
      ]);
    await t.pumpWidget(_app(c));
    expect(find.text('Liều tiếp theo · 10 phút nữa'), findsOneWidget);

    // giả lập kết quả của confirm() + load(): liều 1 đã uống lúc 07:52
    c
      ..day = _day([
        _dose(1, 8, HistoryDoseStatus.taken,
            takenAt: DateTime.utc(2026, 11, 17, 0, 52)),
        _dose(2, 20, HistoryDoseStatus.pending),
      ])
      ..lastConfirmed = (1, DateTime.utc(2026, 11, 17, 1))
      ..confirmedSeq = 1;
    await t.pumpWidget(_app(c));
    await t.pump();
    expect(find.text('Tuyệt vời · đúng giờ'), findsOneWidget);
    expect(find.text('Đã uống lúc 07:52'), findsOneWidget);
    expect(find.text('Liều tiếp theo · Tối nay'), findsNothing);

    await t.pump(HomeDoseTimeline.celebrateHold);
    await t.pumpAndSettle();
    expect(find.text('Tuyệt vời · đúng giờ'), findsNothing);
    expect(find.text('Liều tiếp theo · Tối nay'), findsOneWidget);
    // dòng 08:00 đã thu gọn và có badge, cộng nút của liều 20:00
    expect(find.text('Đã uống'), findsNWidgets(2));
    expect(find.widgetWithText(FilledButton, 'Đã uống'), findsOneWidget);
  });

  testWidgets(
      'đưa vào hàng chờ đồng bộ: hiện "Đang chờ đồng bộ", không ăn mừng (AC19)',
      (t) async {
    final c = HomeScheduleController(
        null, null, (_, __) async => HomeConfirmation.pending,
        clock: () => _now);
    c.setAccess('p1', true);
    c.day = _day([_dose(1, 8, HistoryDoseStatus.pending)]);
    await t.pumpWidget(_app(c));
    await t.tap(find.widgetWithText(FilledButton, 'Đã uống'));
    await t.pumpWidget(_app(c));
    await t.pumpAndSettle();
    expect(find.text('Đang chờ đồng bộ'), findsWidgets);
    expect(find.text('Tuyệt vời · đúng giờ'), findsNothing);
    expect(c.confirmedSeq, 0);
  });

  test('nhãn liều kế tiếp', () {
    final d = _dose(1, 21, HistoryDoseStatus.pending);
    expect(nextDoseLabel(d, DateTime.utc(2026, 11, 17, 1)),
        'Liều tiếp theo · Tối nay');
    final m = _dose(2, 11, HistoryDoseStatus.pending);
    expect(nextDoseLabel(m, DateTime.utc(2026, 11, 17, 1, 30)),
        'Liều tiếp theo · 2 giờ 30 phút nữa');
    expect(nextDoseLabel(m, DateTime.utc(2026, 11, 17, 4, 5)),
        'Liều tiếp theo · Đến giờ rồi');
  });
}
