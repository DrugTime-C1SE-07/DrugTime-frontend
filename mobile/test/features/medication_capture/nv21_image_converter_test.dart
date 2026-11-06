import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:drugtime_mobile/features/medication_capture/data/nv21_image_converter.dart';
import 'package:drugtime_mobile/features/medication_capture/domain/ocr_models.dart';

void main() {
  Uint8List image(int r, int g, int b, {int w = 2, int h = 2}) {
    final pixels = img.Image(width: w, height: h);
    img.fill(pixels, color: img.ColorRgb8(r, g, b));
    return Uint8List.fromList(img.encodePng(pixels));
  }

  test('NV21 oracle black/white/red, V before U', () {
    expect(convertToNv21(image(0, 0, 0)).bytes, [16, 16, 16, 16, 128, 128]);
    expect(convertToNv21(image(255, 255, 255)).bytes,
        [235, 235, 235, 235, 128, 128]);
    expect(convertToNv21(image(255, 0, 0)).bytes, [82, 82, 82, 82, 240, 90]);
  });
  test('odd edges pad without cropping and output can be cleared', () async {
    final nv = await prepareNv21(image(255, 255, 255, w: 3, h: 1));
    expect((nv.width, nv.height), (4, 2));
    expect(nv.bytes.take(8), everyElement(235));
    expect(nv.bytes.length, 12);
    nv.clear();
    expect(nv.bytes, everyElement(0));
  });
  test('reject corrupt and oversize without producing a file', () {
    expect(() => convertToNv21(Uint8List(0)), throwsA(isA<OcrFailure>()));
    expect(() => convertToNv21(Uint8List.fromList([1, 2, 3])),
        throwsA(isA<OcrFailure>()));
    expect(() => convertToNv21(image(0, 0, 0, w: 4097, h: 1)),
        throwsA(isA<OcrFailure>()));
  });
}
