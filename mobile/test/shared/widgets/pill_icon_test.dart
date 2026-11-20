import 'package:drugtime_mobile/app/theme/app_colors.dart' as tokens;
import 'package:drugtime_mobile/shared/widgets/pill_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('colored pill tile passes orange fill and intact outline colors',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Center(child: PillTile(size: 48, colored: true)),
      ),
    ));

    final icon = tester.widget<PillIcon>(find.byType(PillIcon));
    expect(icon.fillColor, tokens.AppColors.pillFill);
    expect(icon.color, isNot(tokens.AppColors.pillFill));
    expect(icon.color, isNotNull);
    // _PillPainter clips fill to the capsule then draws its outer stroke and divider.
  });
}
