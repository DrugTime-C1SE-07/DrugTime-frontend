import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'adherence_history_test_helpers.dart';

void main() {
  testWidgets('week selector exposes status markers and disables future dates',
      (tester) async {
    await pumpHistory(tester, FakeHistoryRepository());
    final missedDay = find.byKey(const ValueKey('history-week-19'));
    final missedSemantics = find.ancestor(
      of: missedDay,
      matching: find.byType(Semantics),
    );
    expect(
      tester.widgetList<Semantics>(missedSemantics).any((semantics) =>
          semantics.properties.label?.contains('có bỏ lỡ') ?? false),
      isTrue,
    );

    final futureDay = tester.widget<InkWell>(
      find.byKey(const ValueKey('history-week-25')),
    );
    expect(futureDay.onTap, isNull);
  });

  testWidgets(
      'single indicator slides between cells (AC4) and taps buzz (AC20)',
      (tester) async {
    final haptics = recordHaptics(tester);
    final c = await pumpHistory(tester, FakeHistoryRepository());
    final indicator = find.byKey(const Key('history-week-indicator'));
    expect(indicator, findsOneWidget);
    final start = tester.getRect(indicator).left;
    expect(
        tester.getCenter(indicator).dx,
        closeTo(
            tester.getCenter(find.byKey(const ValueKey('history-week-21'))).dx,
            1));
    await tester.tap(find.byKey(const ValueKey('history-week-19')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    final middle = tester.getRect(indicator).left;
    expect(indicator, findsOneWidget);
    await tester.pumpAndSettle();
    final end = tester.getRect(indicator).left;
    expect(c.selectedDay, DateTime.utc(2026, 10, 19));
    expect(middle, lessThan(start));
    expect(middle, greaterThan(end));
    expect(
        tester.getCenter(indicator).dx,
        closeTo(
            tester.getCenter(find.byKey(const ValueKey('history-week-19'))).dx,
            1));
    expect(haptics, ['HapticFeedbackType.selectionClick']);

    // Tapping the day already selected changes nothing and does not buzz.
    await tester.tap(find.byKey(const ValueKey('history-week-19')));
    await tester.pumpAndSettle();
    expect(haptics, hasLength(1));
  });

  testWidgets('week swipe goes to D−7 / min(D+7, today) (AC5, AC20)',
      (tester) async {
    final haptics = recordHaptics(tester);
    final c = await pumpHistory(tester, FakeHistoryRepository());
    final card = find.byKey(const Key('history-week-swipe'));
    expect(card, findsOneWidget);

    // The week already holds today: a swipe to the next week does nothing.
    await tester.fling(card, const Offset(-200, 0), 1200);
    await tester.pumpAndSettle();
    expect(c.selectedDay, DateTime.utc(2026, 10, 21));
    expect(haptics, isEmpty);

    await tester.fling(card, const Offset(200, 0), 1200);
    await tester.pumpAndSettle();
    expect(c.selectedDay, DateTime.utc(2026, 10, 14));
    expect(find.byKey(const ValueKey('history-week-12')), findsOneWidget);
    expect(haptics, hasLength(1));

    await tester.fling(card, const Offset(-200, 0), 1200);
    await tester.pumpAndSettle();
    expect(c.selectedDay, DateTime.utc(2026, 10, 21));
    expect(haptics, hasLength(2));
    // Future days stay disabled after the swipe.
    expect(
        tester
            .widget<InkWell>(find.byKey(const ValueKey('history-week-25')))
            .onTap,
        isNull);
  });

  testWidgets('large text keeps horizontal scrolling instead of week swipe',
      (tester) async {
    await pumpHistory(tester, FakeHistoryRepository(), width: 320, scale: 2);
    expect(find.byKey(const Key('history-week-card')), findsOneWidget);
    expect(find.byKey(const Key('history-week-swipe')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
