import 'dart:async';
import 'package:flutter/foundation.dart';
import '../domain/capture_models.dart';
import '../domain/capture_ports.dart';
import '../domain/ocr_models.dart';
import '../domain/ocr_ports.dart';
import 'encrypted_capture_store.dart';
import 'image_processor.dart';
import 'mlkit_ocr_reader.dart';
import 'ocr_api_repository.dart';
import 'system_capture_source.dart';

class CaptureServices extends ChangeNotifier {
  CaptureServices(
      {required this.store,
      required this.processor,
      required this.newSource,
      OcrTextReader? reader,
      OcrMatchingRepository? matching})
      : reader = reader ?? MlKitOcrReader(),
        matching = matching ?? const UnavailableOcrMatchingRepository();
  factory CaptureServices.native({OcrMatchingRepository? matching}) =>
      CaptureServices(
          store: EncryptedCaptureStore(),
          processor: const DartCaptureProcessor(),
          newSource: SystemCaptureSource.new,
          matching: matching);
  final CaptureStore store;
  final CaptureProcessor processor;
  final CaptureSource Function() newSource;
  final OcrTextReader reader;
  final OcrMatchingRepository matching;
  String? _sessionToken;
  int _epoch = 0;
  int get epoch => _epoch;
  String? get sessionToken => _sessionToken;
  bool sameSession(int epoch, String? token) =>
      epoch == _epoch && token == _sessionToken;
  Future<void> _clearing = Future.value();
  final _cleanup = <String, PreparedMedicationImage>{};
  bool _running = false;
  (Future<String> Function(), bool Function(), Completer<String>)? _pending;
  String? cleanupError;
  bool _storeCleanupFailed = false;
  Future<void> initialize() async {
    await _clearing;
    await store.initialize();
  }

  Future<void> bindSession(String? token) {
    if (_sessionToken == token) return _clearing;
    _sessionToken = token;
    return invalidate();
  }

  Future<void> invalidate() {
    _epoch++;
    final previous = _clearing;
    final task = () async {
      await previous;
      try {
        await store.clear();
        _storeCleanupFailed = false;
        await retryCleanup();
      } catch (_) {
        _storeCleanupFailed = true;
        cleanupError = 'Chưa dọn được ảnh tạm. Hãy thử lại.';
      }
    }();
    _clearing = task;
    notifyListeners();
    return task;
  }

  Future<bool> release(PreparedMedicationImage image) async {
    _cleanup[image.id] = image;
    try {
      await image.release();
      _cleanup.remove(image.id);
      if (_cleanup.isEmpty && !_storeCleanupFailed) cleanupError = null;
      return true;
    } catch (_) {
      cleanupError = 'Chưa dọn được ảnh tạm. Hãy thử lại.';
      return false;
    }
  }

  Future<bool> retryCleanup() async {
    if (_storeCleanupFailed) {
      try {
        await store.clear();
        _storeCleanupFailed = false;
      } catch (_) {
        cleanupError = 'Chưa dọn được ảnh tạm. Hãy thử lại.';
        return false;
      }
    }
    var ok = true;
    for (final image in _cleanup.values.toList()) {
      if (!await release(image)) ok = false;
    }
    if (ok) cleanupError = null;
    return ok;
  }

  /// At most one active and one pending scan; pending jobs hold no decoded pixels.
  Future<String> runOcr(
      Future<String> Function() job, bool Function() isCurrent) {
    final pending = _pending;
    if (pending != null) {
      pending.$3.completeError(const OcrFailure(OcrFailureKind.expiredImage));
    }
    final result = Completer<String>();
    _pending = (job, isCurrent, result);
    unawaited(_drain());
    return result.future;
  }

  Future<void> _drain() async {
    if (_running) return;
    _running = true;
    try {
      while (_pending != null) {
        final job = _pending!;
        _pending = null;
        try {
          await _clearing;
          if (cleanupError != null && !await retryCleanup()) {
            throw const OcrFailure(OcrFailureKind.cleanup);
          }
          if (!job.$2()) throw const OcrFailure(OcrFailureKind.expiredImage);
          job.$3.complete(await job.$1());
        } catch (e, stack) {
          job.$3.completeError(e, stack);
        }
      }
    } finally {
      _running = false;
    }
  }
}
