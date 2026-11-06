import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../domain/ocr_models.dart';
import '../domain/ocr_ports.dart';
import 'nv21_image_converter.dart';

class MlKitOcrReader implements OcrTextReader {
  MlKitOcrReader(
      {Future<Nv21Image> Function(Uint8List)? prepare, bool? supported})
      : _prepare = prepare ?? prepareNv21,
        _supported = supported ??
            (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);
  final Future<Nv21Image> Function(Uint8List) _prepare;
  final bool _supported;

  @override
  Future<String> recognize(Uint8List jpeg,
      {required bool Function() isCurrent,
      required void Function() onRecognizing}) async {
    if (!_supported) throw const OcrFailure(OcrFailureKind.unsupported);
    Nv21Image? image;
    TextRecognizer? recognizer;
    try {
      if (!isCurrent()) throw const OcrFailure(OcrFailureKind.expiredImage);
      image = await _prepare(jpeg);
      if (!isCurrent()) throw const OcrFailure(OcrFailureKind.expiredImage);
      onRecognizing();
      if (!isCurrent()) throw const OcrFailure(OcrFailureKind.expiredImage);
      recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final text = await recognizer.processImage(InputImage.fromBytes(
          bytes: image.bytes,
          metadata: InputImageMetadata(
              size: Size(image.width.toDouble(), image.height.toDouble()),
              rotation: InputImageRotation.rotation0deg,
              format: InputImageFormat.nv21,
              bytesPerRow: image.width)));
      if (!isCurrent()) throw const OcrFailure(OcrFailureKind.expiredImage);
      return text.text;
    } on OcrFailure {
      rethrow;
    } catch (_) {
      throw const OcrFailure(OcrFailureKind.recognition);
    } finally {
      image?.clear();
      // Process completion (including errors) precedes close; cancellation is logical.
      if (recognizer != null) {
        try {
          await recognizer.close();
        } catch (_) {
          throw const OcrFailure(OcrFailureKind.recognition);
        }
      }
    }
  }
}
