import 'package:drugtime_mobile/features/home/presentation/scene/banner_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('chip cao 34 dp, có icon và nhãn (AC27)', (t) async {
    await t.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            BannerChip(icon: Icons.check, label: '4/7 liều', progress: 4 / 7),
            BannerChip(
                icon: Icons.local_fire_department,
                label: '2 ngày liên tục',
                tint: Color(0xFFF57C00)),
          ]),
        ),
      ),
    ));
    for (final label in ['4/7 liều', '2 ngày liên tục']) {
      final chip = find.ancestor(
          of: find.text(label), matching: find.byType(BannerChip));
      expect(t.getSize(chip).height, closeTo(34, 1));
      expect(find.descendant(of: chip, matching: find.byType(Icon)),
          findsOneWidget);
    }
    expect(t.takeException(), isNull);
  });

  testWidgets('chip liều có vòng tiến độ, chip chuỗi thì không', (t) async {
    await t.pumpWidget(const MaterialApp(
      home: Row(children: [
        BannerChip(icon: Icons.check, label: 'a', progress: .5),
        BannerChip(icon: Icons.check, label: 'b'),
      ]),
    ));
    CustomPaint ring(String label) => t.widget<CustomPaint>(find.descendant(
        of: find.ancestor(
            of: find.text(label), matching: find.byType(BannerChip)),
        matching: find
            .byWidgetPredicate((w) => w is CustomPaint && w.child is Center)));
    expect((ring('a').painter as dynamic).progress, .5);
    expect((ring('b').painter as dynamic).progress, isNull);
  });
}
