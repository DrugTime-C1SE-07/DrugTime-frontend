import 'dart:ui' as ui;

import 'package:drugtime_mobile/shared/widgets/pill_glyph.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('vẽ đủ 6 hình viên thuốc không lỗi', () {
    for (final shape in PillShape.values) {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      PillGlyphPainter(
              PillLook(shape, const Color(0xFF1B9AFC), color2: Colors.white))
          .paint(canvas, const Size.square(64));
      expect(recorder.endRecording(), isNotNull, reason: shape.name);
    }
  });

  test('shouldRepaint chỉ khi hình, màu hoặc góc thay đổi', () {
    const base = PillLook(PillShape.capsule, Color(0xFF1B9AFC), angle: .2);
    final painter = PillGlyphPainter(base);
    expect(painter.shouldRepaint(PillGlyphPainter(base)), isFalse);
    expect(
        painter.shouldRepaint(PillGlyphPainter(
            const PillLook(PillShape.capsule, Color(0xFFF2DE8C), angle: .2))),
        isTrue);
    expect(
        painter.shouldRepaint(PillGlyphPainter(
            const PillLook(PillShape.capsule, Color(0xFF1B9AFC), angle: .3))),
        isTrue);
  });

  testWidgets('PillGlyph có kích thước đúng', (tester) async {
    await tester.pumpWidget(const Center(
        child:
            PillGlyph(PillLook(PillShape.round, Color(0xFFF4F1EA)), size: 40)));
    expect(tester.getSize(find.byType(PillGlyph)), const Size(40, 40));
  });
}
