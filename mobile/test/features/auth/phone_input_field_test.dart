import 'package:drugtime_mobile/features/auth/presentation/widgets/phone_input_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Task adhoc-20261115-pill-mascot-redesign, P16: cờ Việt Nam trước mã +84.
void main() {
  testWidgets('cờ Việt Nam đứng trước +84, cùng hàng, có nhãn Việt Nam',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: PhoneInputField(controller: controller),
        ),
      ),
    ));

    final flag = find.byType(VietnamFlag);
    final code = find.text('+84');
    expect(flag, findsOneWidget);
    expect(code, findsOneWidget);
    expect(find.bySemanticsLabel('Việt Nam'), findsOneWidget);

    final flagRect = tester.getRect(flag);
    final codeRect = tester.getRect(code);
    expect(flagRect.size, const Size(22, 15));
    expect(flagRect.right, lessThanOrEqualTo(codeRect.left));
    expect((flagRect.center.dy - codeRect.center.dy).abs(), lessThan(2));
    semantics.dispose();
  });
}
