import 'dart:typed_data';
import 'package:flutter/widgets.dart';
import 'capture_models.dart';

abstract class CaptureSource extends ChangeNotifier {
  Future<CapturePermission> permission({bool request = false});
  Future<void> openSettings();
  Future<void> initialize();
  Future<void> stop();
  Future<Uint8List> capture();
  Future<Uint8List?> pick();
  Future<Uint8List?> recover();
  Future<void> toggleFlash();
  bool get ready;
  bool get flashAvailable;
  bool get flashOn;
  Widget preview();
}

abstract interface class CaptureProcessor {
  Future<ProcessedCapture> process(Uint8List source);
}

abstract interface class CaptureStore {
  Future<void> initialize();
  Future<PreparedMedicationImage> save(
      ProcessedCapture image, PackagingKind kind);
  Future<void> clear();
}
