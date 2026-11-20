import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/shared/widgets/mascot/mascot_artwork_painter.dart';
import 'package:drugtime_mobile/shared/widgets/mascot/mascot_controller.dart';
import 'package:drugtime_mobile/shared/widgets/mascot/mascot_view.dart';

void main() {
  setUpAll(MascotView.preloadFigmaArtwork);
  for (final mood in [MascotMood.farewell, MascotMood.thumbsUp]) {
    testWidgets('original artwork ${mood.name} blinks and articulates its hand',
        (tester) async {
      final ctl = MascotController()..play(mood);
      const key = Key('motion');
      await tester.pumpWidget(MaterialApp(
          home: Center(
              child: RepaintBoundary(
                  key: key,
                  child: ColoredBox(
                      color: const Color(0xff01554f),
                      child: MascotView(
                          controller: ctl,
                          size: 224,
                          height: mood == MascotMood.thumbsUp ? 205 : 224,
                          figmaArtwork: true))))));
      await tester.pump();
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final paint = tester
          .widget<CustomPaint>(find.descendant(
              of: find.byType(MascotView), matching: find.byType(CustomPaint)))
          .painter;
      expect(paint, isA<MascotArtworkPainter>());
      final rig = (paint! as MascotArtworkPainter).rig;
      var minBlink = 1.0;
      final hand = rig.value('hry');
      for (var frame = 0; frame < 60; frame++) {
        await tester.pump(const Duration(milliseconds: 33));
        if (rig.blink < minBlink) minBlink = rig.blink;
        if (const bool.fromEnvironment('CAPTURE_DELETION')) {
          final boundary =
              tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 1);
            final bytes =
                await image.toByteData(format: ui.ImageByteFormat.png);
            final file = File(
                '../../output/account-deletion/motion/${mood.name}-${frame.toString().padLeft(2, '0')}.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      }
      expect(minBlink, lessThan(.4));
      expect(rig.value('hry'), isNot(hand));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      ctl.dispose();
    });
  }
}
