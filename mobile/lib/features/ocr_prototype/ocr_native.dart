import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'ocr_models.dart';

bool get supportsNativeOcr => !kIsWeb && Platform.isAndroid;

class MlKitOcrEngine implements OcrEngine {
  TextRecognizer? _recognizer;
  @override
  Future<String> recognize(String path) async {
    if (!supportsNativeOcr) throw UnsupportedError('Android required');
    _recognizer ??= TextRecognizer(script: TextRecognitionScript.latin);
    return (await _recognizer!.processImage(InputImage.fromFilePath(path)))
        .text;
  }

  @override
  Future<void> close() async {
    await _recognizer?.close();
    _recognizer = null;
  }
}

class GalleryOcrPicker implements OcrImagePicker {
  GalleryOcrPicker({ImagePicker? picker}) : _picker = picker ?? ImagePicker();
  final ImagePicker _picker;
  @override
  Future<String?> pick() async => (await _picker.pickImage(
          source: ImageSource.gallery, requestFullMetadata: false))
      ?.path;
  @override
  Future<String?> recover() async {
    if (!Platform.isAndroid) return null;
    final response = await _picker.retrieveLostData();
    if (response.exception != null) throw response.exception!;
    return response.files?.firstOrNull?.path;
  }
}

class SystemOcrExporter implements OcrExporter {
  @override
  Future<bool> share(File file, Rect origin) async {
    final result = await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        sharePositionOrigin: origin));
    return result.status == ShareResultStatus.success;
  }
}
