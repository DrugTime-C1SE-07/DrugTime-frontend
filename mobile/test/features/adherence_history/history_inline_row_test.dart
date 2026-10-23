import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/features/adherence_history/presentation/widgets/history_inline_row.dart';

void main() {
  testWidgets(
      'large text stays in one line and scrolls to final label with affordance',
      (tester) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(2)),
                child: HistoryInlineRow(children: [
                  Text('Đã uống'),
                  Text('Bỏ lỡ'),
                  Text('Chờ')
                ])))));
    final first = tester.getTopLeft(find.text('Đã uống'));
    expect(tester.getTopLeft(find.text('Chờ')).dy, first.dy);
    expect(
        tester.widget<Scrollbar>(find.byType(Scrollbar)).thumbVisibility, true);
    await tester.drag(
        find.byType(SingleChildScrollView), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('Chờ')).right, lessThanOrEqualTo(320));
    expect(tester.widget<Text>(find.text('Chờ')).overflow, isNull);
    expect(tester.takeException(), isNull);
  });
}
