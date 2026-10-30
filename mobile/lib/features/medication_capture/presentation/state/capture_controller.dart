import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../domain/capture_models.dart';
import '../../domain/capture_ports.dart';

class CaptureController extends ChangeNotifier {
  CaptureController(
      {required this.source,
      required this.processor,
      required this.store,
      Listenable? session})
      : _session = session {
    source.addListener(_changed);
    _session?.addListener(_sessionEnded);
  }
  final CaptureSource source;
  final CaptureProcessor processor;
  final CaptureStore store;
  final Listenable? _session;
  CaptureStage stage = CaptureStage.starting;
  CapturePermission? permissionStatus;
  ProcessedCapture? image;
  CaptureWarning? get blockingWarning => image?.warnings
      .where((warning) =>
          warning == CaptureWarning.dark || warning == CaptureWarning.blurred)
      .firstOrNull;
  bool get canUseImage =>
      !busy &&
      !_closed &&
      image != null &&
      stage == CaptureStage.reviewing &&
      blockingWarning == null;
  String? error;
  bool busy = false;
  bool _active = true,
      _closed = false,
      _asking = false,
      _openingSettings = false;
  bool _settingsResumePending = false;
  int _generation = 0, _imageGeneration = 0;
  PreparedMedicationImage? _lease;

  void _changed() {
    if (!_closed) notifyListeners();
  }

  void _sessionEnded() {
    unawaited(close());
  }

  String _message(Object e, String fallback) =>
      e is CaptureFailure ? e.message : fallback;
  Future<void> start() async {
    final generation = ++_generation;
    busy = true;
    _changed();
    try {
      await store.initialize();
      final recovered = await source.recover();
      if (_closed || generation != _generation) return;
      if (recovered != null) {
        busy = false;
        await accept(recovered);
        return;
      }
    } catch (e) {
      error = _message(e, 'Chưa chuẩn bị được ảnh. Hãy thử lại.');
    }
    if (_closed || generation != _generation) return;
    busy = false;
    await requestPermission(request: false);
  }

  Future<void> requestPermission({bool request = true}) async {
    if (_closed || _asking || _openingSettings || busy) return;
    _asking = true;
    busy = true;
    error = null;
    stage = CaptureStage.camera;
    _changed();
    final generation = _generation;
    try {
      permissionStatus = await source.permission(request: request);
      if (!_closed &&
          _active &&
          generation == _generation &&
          permissionStatus == CapturePermission.granted) {
        if (!source.ready) await source.initialize();
      } else if (!_closed && generation == _generation && source.ready) {
        await source.stop();
      }
    } catch (e) {
      error = _message(e, 'Chưa mở được camera. Bạn có thể chọn ảnh.');
    } finally {
      _asking = false;
      if (!_closed) {
        busy = false;
        _changed();
      }
    }
  }

  Future<void> openSettings() async {
    if (_closed || busy || _openingSettings) return;
    _openingSettings = true;
    error = null;
    _changed();
    try {
      await source.openSettings();
    } catch (e) {
      error = _message(e, 'Không mở được Cài đặt.');
    } finally {
      _openingSettings = false;
      if (!_closed) {
        _changed();
        // A Settings launch can complete after the app has already resumed.
        if (_active && _settingsResumePending && error == null) {
          _settingsResumePending = false;
          await requestPermission(request: false);
        }
      }
      _settingsResumePending = false;
    }
  }

  Future<void> background() async {
    _active = false;
    try {
      await source.stop();
    } catch (e) {
      error = _message(e, 'Chưa đóng được camera.');
      _changed();
    }
  }

  Future<void> resume() async {
    _active = true;
    if (_openingSettings) {
      _settingsResumePending = true;
      return;
    }
    if (_closed || _asking || busy || stage != CaptureStage.camera) return;
    await requestPermission(request: false);
  }

  Future<void> takePhoto() async {
    if (busy || _closed || !source.ready) return;
    busy = true;
    error = null;
    _changed();
    final generation = _generation;
    try {
      final bytes = await source.capture();
      if (!_closed && generation == _generation) await accept(bytes);
    } catch (e) {
      if (!_closed && generation == _generation) {
        error = _message(e, 'Chưa chụp được ảnh. Hãy thử lại.');
      }
    } finally {
      if (!_closed && generation == _generation) {
        busy = false;
        _changed();
      }
    }
  }

  Future<void> pickPhoto() async {
    if (busy || _closed) return;
    busy = true;
    error = null;
    _changed();
    final generation = _generation;
    try {
      await source.stop();
      final bytes = await source.pick();
      if (!_closed && generation == _generation && bytes != null) {
        await accept(bytes);
      } else if (!_closed && bytes == null) {
        busy = false;
        await requestPermission(request: false);
      }
    } catch (e) {
      if (!_closed && generation == _generation) {
        error = _message(e, 'Không mở được ảnh. Hãy chọn ảnh khác.');
      }
    } finally {
      if (!_closed && generation == _generation) {
        busy = false;
        _changed();
      }
    }
  }

  Future<void> accept(Uint8List bytes) async {
    if (_closed) return;
    final generation = ++_imageGeneration;
    stage = CaptureStage.reviewing;
    image = null;
    busy = true;
    error = null;
    _changed();
    try {
      await source.stop();
      if (_closed || generation != _imageGeneration) return;
      final rendered = await processor.process(bytes);
      if (!_closed && generation == _imageGeneration) image = rendered;
    } catch (e) {
      if (!_closed && generation == _imageGeneration) {
        image = null;
        error = _message(e, 'Không xử lý được ảnh. Hãy chọn lại.');
      }
    } finally {
      if (!_closed && generation == _imageGeneration) {
        busy = false;
        _changed();
      }
    }
  }

  Future<PreparedMedicationImage?> prepare() async {
    if (!canUseImage) {
      return null;
    }
    busy = true;
    error = null;
    _changed();
    final generation = _generation;
    try {
      final lease = await store.save(image!, PackagingKind.unspecified);
      if (_closed || generation != _generation) {
        await lease.release();
        return null;
      }
      _lease = lease;
      stage = CaptureStage.prepared;
      return lease;
    } catch (e) {
      if (!_closed && generation == _generation) {
        error = _message(e, 'Chưa lưu được ảnh an toàn. Hãy thử lại.');
      }
      return null;
    } finally {
      if (!_closed && generation == _generation) {
        busy = false;
        _changed();
      }
    }
  }

  PreparedMedicationImage? takeLease() {
    final lease = _lease;
    _lease = null;
    return lease;
  }

  Future<void> retake() async {
    if (_closed) return;
    _generation++;
    _imageGeneration++;
    await _lease?.release();
    _lease = null;
    image = null;
    busy = false;
    await requestPermission(request: false);
  }

  Future<void> toggleFlash() async {
    try {
      await source.toggleFlash();
    } catch (e) {
      error = _message(e, 'Chưa bật được đèn.');
      _changed();
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _generation++;
    _imageGeneration++;
    stage = CaptureStage.closed;
    image = null;
    source.removeListener(_changed);
    _session?.removeListener(_sessionEnded);
    try {
      await source.stop();
      await _lease?.release();
    } catch (e) {
      error = _message(e, 'Chưa dọn xong ảnh tạm.');
    }
    _lease = null;
  }

  @override
  void dispose() {
    unawaited(close());
    super.dispose();
  }
}
