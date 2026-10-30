import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:drugtime_mobile/features/medication_capture/data/image_processor.dart';
import 'package:drugtime_mobile/features/medication_capture/domain/capture_models.dart';
import 'capture_controller_test.dart' show makeImage;

void main() {
  const processor = DartCaptureProcessor();
  test('all EXIF orientations are baked, including mirrored corners', () async {
    final expected = [
      [0, 1, 2, 3],
      [1, 0, 3, 2],
      [3, 2, 1, 0],
      [2, 3, 0, 1],
      [0, 2, 1, 3],
      [2, 0, 3, 1],
      [3, 1, 2, 0],
      [1, 3, 0, 2]
    ];
    final colors = [
      img.ColorRgb8(220, 20, 20),
      img.ColorRgb8(20, 220, 20),
      img.ColorRgb8(20, 20, 220),
      img.ColorRgb8(220, 220, 20)
    ];
    for (var orientation = 1; orientation <= 8; orientation++) {
      final original = img.Image(width: 80, height: 40);
      for (var y = 0; y < 40; y++) {
        for (var x = 0; x < 80; x++) {
          original.setPixel(
              x, y, colors[(y >= 20 ? 2 : 0) + (x >= 40 ? 1 : 0)]);
        }
      }
      original.exif.imageIfd.orientation = orientation;
      final result = await processor
          .process(Uint8List.fromList(img.encodeJpg(original, quality: 100)));
      expect((result.width, result.height),
          orientation <= 4 ? (80, 40) : (40, 80));
      final decoded = img.decodeJpg(result.bytes)!;
      final samples = [
        (decoded.width ~/ 4, decoded.height ~/ 4),
        (decoded.width * 3 ~/ 4, decoded.height ~/ 4),
        (decoded.width ~/ 4, decoded.height * 3 ~/ 4),
        (decoded.width * 3 ~/ 4, decoded.height * 3 ~/ 4)
      ];
      for (var i = 0; i < 4; i++) {
        final actual = decoded.getPixel(samples[i].$1, samples[i].$2),
            color = colors[expected[orientation - 1][i]];
        expect((actual.r - color.r).abs(), lessThan(25),
            reason: 'orientation $orientation corner $i');
        expect((actual.g - color.g).abs(), lessThan(25));
        expect((actual.b - color.b).abs(), lessThan(25));
      }
      expect(decoded.exif.imageIfd.orientation, isNull);
    }
  });
  test('full frame keeps both dimensions without classification or cropping',
      () async {
    final bytes = makeImage(width: 80, height: 40);
    final full = await processor.process(bytes);
    expect((full.width, full.height), (80, 40));
  });
  test('empty/corrupt/oversize input rejected; dark/no-texture warnings',
      () async {
    await expectLater(
        processor.process(Uint8List(0)), throwsA(isA<CaptureFailure>()));
    await expectLater(processor.process(Uint8List.fromList([1, 2])),
        throwsA(isA<CaptureFailure>()));
    await expectLater(processor.process(Uint8List(20 * 1024 * 1024 + 1)),
        throwsA(isA<CaptureFailure>()));
    final dark = await processor.process(makeImage(value: 20));
    expect(dark.warnings, contains(CaptureWarning.dark));
    expect(dark.warnings, contains(CaptureWarning.lowTexture));
    final white = await processor.process(makeImage(value: 255));
    expect(white.warnings, isNot(contains(CaptureWarning.bright)));
  });
  test('EXIF processing retains both halves and their original colors',
      () async {
    final original = img.Image(width: 80, height: 40);
    for (var y = 0; y < 40; y++) {
      for (var x = 0; x < 80; x++) {
        original.setPixel(x, y,
            x < 40 ? img.ColorRgb8(220, 20, 20) : img.ColorRgb8(20, 220, 20));
      }
    }
    original.exif.imageIfd.orientation = 6;
    final bytes = Uint8List.fromList(img.encodeJpg(original, quality: 100));
    final first = await processor.process(bytes),
        second = await processor.process(bytes);
    expect(first.bytes, second.bytes);
    expect((first.width, first.height), (40, 80));
    final decoded = img.decodeJpg(first.bytes)!;
    final top = decoded.getPixel(10, 10);
    expect(top.r, closeTo(220, 10));
    expect(top.g, closeTo(20, 10));
    final pixel = decoded.getPixel(10, 60);
    expect(pixel.r, closeTo(20, 10));
    expect(pixel.g, closeTo(220, 10));
    expect(pixel.b, closeTo(20, 10));
  });
}
