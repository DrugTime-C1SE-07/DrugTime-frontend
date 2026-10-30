import 'package:flutter/foundation.dart';
import '../domain/capture_ports.dart';
import 'encrypted_capture_store.dart';
import 'image_processor.dart';
import 'system_capture_source.dart';

class CaptureServices extends ChangeNotifier {
  CaptureServices(
      {required this.store, required this.processor, required this.newSource});
  factory CaptureServices.native() => CaptureServices(
      store: EncryptedCaptureStore(),
      processor: const DartCaptureProcessor(),
      newSource: SystemCaptureSource.new);
  final CaptureStore store;
  final CaptureProcessor processor;
  final CaptureSource Function() newSource;
  String? cleanupError;
  Future<void> initialize() => store.initialize();
  Future<void> invalidate() async {
    notifyListeners();
    try {
      await store.clear();
      cleanupError = null;
    } catch (_) {
      cleanupError = 'Chưa dọn được ảnh tạm. Hãy thử lại.';
    }
  }
}
