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

  test('crop maps BoxFit.cover frame onto upright image (portrait and landscape)',
      () async {
    // Wider than viewport (200x100, imgAspect=2.0 vs viewAspect=1.0):
    // visible region is x=[50..150), y=[0..100).
    // Crop (0.25, 0.25, 0.5, 0.5) => x=[75..125), y=[25..75) => 50x50.
    final wide = img.Image(width: 200, height: 100);
    img.fill(wide, color: img.ColorRgb8(220, 20, 20));
    img.fillRect(wide,
        x1: 75, y1: 25, x2: 124, y2: 74, color: img.ColorRgb8(20, 220, 20));
    final wideResult = await processor.process(
        Uint8List.fromList(img.encodePng(wide)),
        crop: const CaptureCropRect(
            left: 0.25,
            top: 0.25,
            width: 0.5,
            height: 0.5,
            viewportAspectRatio: 1.0));
    expect((wideResult.width, wideResult.height), (50, 50));
    final decodedWide = img.decodeJpg(wideResult.bytes)!;
    final wideCenter = decodedWide.getPixel(25, 25);
    expect(wideCenter.g, greaterThan(180));
    expect(wideCenter.r, lessThan(60));

    // Taller than viewport (100x200, imgAspect=0.5 vs viewAspect=1.0):
    // visible region is x=[0..100), y=[50..150).
    // Crop (0.25, 0.25, 0.5, 0.5) => x=[25..75), y=[75..125) => 50x50.
    final tall = img.Image(width: 100, height: 200);
    img.fill(tall, color: img.ColorRgb8(220, 20, 20));
    img.fillRect(tall,
        x1: 25, y1: 75, x2: 74, y2: 124, color: img.ColorRgb8(20, 20, 220));
    final tallResult = await processor.process(
        Uint8List.fromList(img.encodePng(tall)),
        crop: const CaptureCropRect(
            left: 0.25,
            top: 0.25,
            width: 0.5,
            height: 0.5,
            viewportAspectRatio: 1.0));
    expect((tallResult.width, tallResult.height), (50, 50));
    final decodedTall = img.decodeJpg(tallResult.bytes)!;
    final tallCenter = decodedTall.getPixel(25, 25);
    expect(tallCenter.b, greaterThan(180));
    expect(tallCenter.r, lessThan(60));
  });

  test('crop applies after EXIF orientation bake and strips EXIF metadata',
      () async {
    final raw = img.Image(width: 200, height: 100);
    img.fill(raw, color: img.ColorRgb8(200, 200, 200));
    raw.exif.imageIfd.orientation = 6; // Rotates 90 CW => upright 100x200.
    final result = await processor.process(
        Uint8List.fromList(img.encodeJpg(raw, quality: 100)),
        crop: const CaptureCropRect(
            left: 0.1,
            top: 0.25,
            width: 0.8,
            height: 0.5,
            viewportAspectRatio: 0.5));
    expect((result.width, result.height), (80, 100));
    final decoded = img.decodeJpg(result.bytes)!;
    expect(decoded.exif.imageIfd.orientation, isNull);
    expect(decoded.exif.isEmpty, isTrue);
  });

  test('invalid or out-of-bounds crop rect clamps safely or falls back',
      () async {
    final bytes = makeImage(width: 100, height: 80);
    for (final bad in const [
      CaptureCropRect(
          left: double.nan,
          top: 0,
          width: 0.5,
          height: 0.5,
          viewportAspectRatio: 1.0),
      CaptureCropRect(
          left: 0, top: 0, width: 0.5, height: 0.5, viewportAspectRatio: 0),
      CaptureCropRect(
          left: 0.2, top: 0.2, width: 0, height: 0.5, viewportAspectRatio: 1.0),
      CaptureCropRect(
          left: 1.5,
          top: 1.5,
          width: 0.5,
          height: 0.5,
          viewportAspectRatio: 1.0),
    ]) {
      final fallback = await processor.process(bytes, crop: bad);
      expect((fallback.width, fallback.height), (100, 80));
    }

    final clamped = await processor.process(bytes,
        crop: const CaptureCropRect(
            left: -0.2,
            top: 0.5,
            width: 1.5,
            height: 0.8,
            viewportAspectRatio: 1.25));
    expect(clamped.width, 100);
    expect(clamped.height, 40);
  });

  test('large image is resized to max 1600px and still detects dark warning',
      () async {
    final largeDark = makeImage(width: 2000, height: 1000, value: 20);
    final result = await processor.process(largeDark);
    expect((result.width, result.height), (1600, 800));
    expect(result.warnings, contains(CaptureWarning.dark));
  });
}
