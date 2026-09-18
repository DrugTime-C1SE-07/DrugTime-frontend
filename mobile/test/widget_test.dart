import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/main.dart';

void main() {
  testWidgets('Smoke test App renders', (WidgetTester tester) async {
    await tester.pumpWidget(const DrugTimeApp());
    expect(find.text('DrugTime - Sẵn sàng cho Sprint 1'), findsOneWidget);
  });
}
