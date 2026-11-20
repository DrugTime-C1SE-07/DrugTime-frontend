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
}
