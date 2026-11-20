import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:drugtime_mobile/shared/widgets/mascot/mascot_controller.dart';
import 'package:drugtime_mobile/shared/widgets/mascot/mascot_painter.dart';
import 'package:drugtime_mobile/shared/widgets/mascot/mascot_rig.dart';
import 'package:drugtime_mobile/shared/widgets/mascot/mascot_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('vẽ mọi bảng màu × trang phục mới × trạng thái không lỗi', () {
    final ctl = MascotController();
    for (final palette in MascotPalette.values) {
      for (final outfit in [MascotOutfit.gardenHat, MascotOutfit.scarf]) {
        for (final mood in MascotMood.values) {
          final rig = MascotRig(random: math.Random(3))
            ..outfit = outfit
            ..setMood(mood, ledge: 360);
          for (var i = 0; i < 30; i++) {
            rig.tick(1 / 30, ctl: ctl, still: false);
          }
          final recorder = ui.PictureRecorder();
          MascotPainter(rig, outfit: outfit, palette: palette)
              .paint(Canvas(recorder), const Size.square(160));
          expect(recorder.endRecording(), isNotNull,
              reason: '${palette.name}/${outfit.name}/${mood.name}');
        }
      }
    }
  });

  test('mặc định vẫn là màu xanh gốc', () {
    final painter = MascotPainter(MascotRig());
    expect(painter.palette, MascotPalette.blue);
    expect(MascotPalette.blue.base, const Color(0xFF1B9AFC));
    expect(MascotPalette.blue.deep, const Color(0xFF0A7FEF));
  });

  test('đổi bảng màu thì vẽ lại', () {
    final rig = MascotRig();
    final blue = MascotPainter(rig);
    final peach = MascotPainter(rig, palette: MascotPalette.peach);
    expect(peach.shouldRepaint(blue), isTrue);
    expect(MascotPainter(rig).shouldRepaint(blue), isFalse);
  });

  for (final mood in [MascotMood.hug, MascotMood.blissful]) {
    test('${mood.name} tự quay về trạng thái nền trước đó', () {
      final ctl = MascotController();
      final rig = MascotRig(random: math.Random(4))
        ..setMood(MascotMood.sleepy, ledge: 360)
        ..setMood(mood, ledge: 360);
      expect(rig.mood, mood);
      for (var t = 0.0; t < 2.2; t += 1 / 60) {
        rig.tick(1 / 60, ctl: ctl, still: false);
      }
      expect(rig.mood, MascotMood.sleepy);
    });

    test('${mood.name} khi giảm chuyển động: giữ trạng thái nền', () {
      final rig = MascotRig()
        ..setMood(MascotMood.wave, ledge: 360)
        ..setMood(MascotMood.concerned, ledge: 360)
        ..setMood(mood, ledge: 360, still: true);
      expect(rig.mood, MascotMood.concerned);
    });
  }

  test('blissful nhắm mắt, má ửng; hug khép hai tay vào giữa', () {
    final ctl = MascotController();
    final live = MascotRig(random: math.Random(5))
      ..setMood(MascotMood.blissful, ledge: 360);
    for (var i = 0; i < 40; i++) {
      live.tick(1 / 60, ctl: ctl, still: false);
    }
    expect(live.value('open'), lessThan(.3));
    expect(live.value('cheek'), greaterThan(1));

    final hug = MascotRig(random: math.Random(6))
      ..setMood(MascotMood.hug, ledge: 360);
    for (var i = 0; i < 50; i++) {
      hug.tick(1 / 60, ctl: ctl, still: false);
    }
    expect(hug.value('hrx') - hug.value('hlx'), lessThan(150));
  });

  testWidgets('MascotView: onTap thay phản ứng mặc định, có nhãn tuỳ chỉnh',
      (tester) async {
    final ctl = MascotController()..play(MascotMood.idle);
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Center(
        child: MascotView(
          controller: ctl,
          size: 120,
          palette: MascotPalette.peach,
          outfit: MascotOutfit.scarf,
          semanticLabel: 'Bạn thuốc cam',
          onTap: () => taps++,
        ),
      ),
    ));
    await tester.tap(find.byType(MascotView));
    await tester.pump(const Duration(milliseconds: 50));
    expect(taps, 1);
    expect(ctl.mood, MascotMood.idle);
    expect(find.bySemanticsLabel('Bạn thuốc cam'), findsOneWidget);
  });

  testWidgets('MascotView không truyền onTap: vẫn chọc (poke) như cũ',
      (tester) async {
    final ctl = MascotController()..play(MascotMood.idle);
    await tester.pumpWidget(MaterialApp(
      home: Center(child: MascotView(controller: ctl, size: 120)),
    ));
    await tester.tap(find.byType(MascotView));
    await tester.pump(const Duration(milliseconds: 50));
    expect(ctl.mood, MascotMood.poke);
    expect(find.bySemanticsLabel('Linh vật DrugTime'), findsOneWidget);
  });
}
