import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import '../domain/capture_models.dart';
import '../domain/capture_ports.dart';

class DartCaptureProcessor implements CaptureProcessor {
  const DartCaptureProcessor();
  @override
  Future<ProcessedCapture> process(Uint8List source) =>
      compute(_process, source);
}

ProcessedCapture _process(Uint8List bytes) {
  if (bytes.isEmpty || bytes.length > 20 * 1024 * 1024) {
    throw const CaptureFailure(
        'Ảnh không hợp lệ hoặc quá lớn. Hãy chọn ảnh khác.');
  }
  final info = img.findDecoderForData(bytes)?.startDecode(bytes);
  if (info == null || info.width * info.height > 24000000) {
    throw const CaptureFailure('Không mở được ảnh này. Hãy chọn ảnh khác.');
  }
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw const CaptureFailure('Không mở được ảnh này.');
  var upright = img.bakeOrientation(decoded);
  if (math.max(upright.width, upright.height) > 4096) {
    upright = img.copyResize(upright,
        width: upright.width >= upright.height ? 4096 : null,
        height: upright.height > upright.width ? 4096 : null);
  }
  final warnings = _quality(upright);
  // A fresh RGB image strips EXIF/GPS and orientation metadata.
  img.Image stripped(img.Image source) {
    final target = img.Image(width: source.width, height: source.height);
    img.compositeImage(target, source);
    return target;
  }

  return ProcessedCapture(
      Uint8List.fromList(img.encodeJpg(stripped(upright), quality: 95)),
      upright.width,
      upright.height,
      warnings: warnings);
}

List<CaptureWarning> _quality(img.Image source) {
  final long = math.max(source.width, source.height);
  final sample = long > 512
      ? img.copyResize(source,
          width: source.width >= source.height ? 512 : null,
          height: source.height > source.width ? 512 : null)
      : source;
  final w = sample.width, h = sample.height;
  if (w < 3 || h < 3) return [CaptureWarning.lowTexture];
  final luma = List<double>.filled(w * h, 0);
  var dark = 0, bright = 0;
  double sum = 0, squares = 0;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final p = sample.getPixel(x, y);
      final value = .2126 * p.r + .7152 * p.g + .0722 * p.b;
      luma[y * w + x] = value;
      sum += value;
      squares += value * value;
      if (value < 40) dark++;
      if (p.r >= 245 && p.g >= 245 && p.b >= 245) bright++;
    }
  }
  final n = w * h, mean = sum / (w * h);
  double lap = 0, lapSq = 0;
  for (var y = 1; y < h - 1; y++) {
    for (var x = 1; x < w - 1; x++) {
      final i = y * w + x;
      final v =
          4 * luma[i] - luma[i - 1] - luma[i + 1] - luma[i - w] - luma[i + w];
      lap += v;
      lapSq += v * v;
    }
  }
  final count = (w - 2) * (h - 2);
  final variance = lapSq / count - math.pow(lap / count, 2);
  final texture = squares / n - mean * mean;
  final warnings = <CaptureWarning>[];
  if (mean < 60 || dark / n > .65) warnings.add(CaptureWarning.dark);
  if (texture < 25) {
    warnings.add(CaptureWarning.lowTexture);
  } else if (variance < 80) {
    warnings.add(CaptureWarning.blurred);
  }
  // A white box is not proof of glare: require a connected highlight and
  // meaningful non-white content. This remains a capture hint, never OCR.
  if (bright / n > .15 && bright / n < .8 && texture > 400) {
    final seen = Uint8List(n);
    var largest = 0;
    for (var start = 0; start < n; start++) {
      if (seen[start] != 0 || luma[start] < 245) continue;
      final pending = <int>[start];
      seen[start] = 1;
      var area = 0;
      while (pending.isNotEmpty) {
        final i = pending.removeLast();
        area++;
        final x = i % w;
        for (final j in [
          if (x > 0) i - 1,
          if (x < w - 1) i + 1,
          if (i >= w) i - w,
          if (i < n - w) i + w
        ]) {
          if (seen[j] == 0 && luma[j] >= 245) {
            seen[j] = 1;
            pending.add(j);
          }
        }
      }
      largest = math.max(largest, area);
    }
    if (largest / n > .05) warnings.add(CaptureWarning.bright);
  }
  return warnings;
}
