import 'dart:typed_data';
import 'ocr_models.dart';

abstract interface class OcrTextReader {
  Future<String> recognize(Uint8List jpeg,
      {required bool Function() isCurrent,
      required void Function() onRecognizing});
}

abstract interface class OcrMatchingRepository {
  Future<OcrMatchResult> match(String text,
      {required String sessionToken, int limit = 5});
}
