import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import '../domain/ocr_models.dart';

class Nv21Image {
  const Nv21Image(this.bytes, this.width, this.height);
  final Uint8List bytes;
  final int width, height;
  void clear() => bytes.fillRange(0, bytes.length, 0);
}

Future<Nv21Image> prepareNv21(Uint8List encoded) =>
    compute(convertToNv21, encoded);

/// BT.601 limited-range Y, followed by interleaved VU samples averaged over2x2.
/// Odd edges are replicated, never cropped; no disk IO or resizing.
Nv21Image convertToNv21(Uint8List encoded) {
  const invalid = OcrFailure(OcrFailureKind.invalidImage);
  if (encoded.isEmpty || encoded.length > 20 * 1024 * 1024) throw invalid;
  final info = img.findDecoderForData(encoded)?.startDecode(encoded);
  if (info == null ||
      info.width < 1 ||
      info.height < 1 ||
      info.width > 4096 ||
      info.height > 4096 ||
      info.width * info.height > 24000000) {
    throw invalid;
  }
  final image = img.decodeImage(encoded);
  if (image == null) throw invalid;
  final w = (image.width + 1) & ~1, h = (image.height + 1) & ~1;
  final bytes = Uint8List(w * h * 3 ~/ 2);
  int clip(int value) => value.clamp(0, 255);
  for (var y = 0; y < h; y += 2) {
    for (var x = 0; x < w; x += 2) {
      var r = 0, g = 0, b = 0;
      for (var dy = 0; dy < 2; dy++) {
        for (var dx = 0; dx < 2; dx++) {
          final p = image.getPixel((x + dx).clamp(0, image.width - 1),
              (y + dy).clamp(0, image.height - 1));
          final pr = p.r.toInt(), pg = p.g.toInt(), pb = p.b.toInt();
          bytes[(y + dy) * w + x + dx] =
              clip(((66 * pr + 129 * pg + 25 * pb + 128) >> 8) + 16);
          r += pr;
          g += pg;
          b += pb;
        }
      }
      r = (r + 2) ~/ 4;
      g = (g + 2) ~/ 4;
      b = (b + 2) ~/ 4;
      final uv = w * h + (y ~/ 2) * w + x;
      bytes[uv] = clip(((112 * r - 94 * g - 18 * b + 128) >> 8) + 128);
      bytes[uv + 1] = clip(((-38 * r - 74 * g + 112 * b + 128) >> 8) + 128);
    }
  }
  return Nv21Image(bytes, w, h);
}
