import 'dart:async';
import 'dart:developer';
import 'package:flutter/foundation.dart';
import '../../data/capture_services.dart';
import '../../domain/capture_models.dart';
import '../../domain/ocr_models.dart';

class OcrController extends ChangeNotifier {
  OcrController(
      {required this.image, required this.services, DateTime Function()? clock})
      : _clock = clock ?? DateTime.now,
        _epoch = services.epoch,
        _token = services.sessionToken {
    services.addListener(_sessionEnded);
    _expiry = Timer(image.expiresAt.difference(_clock()), _expire);
  }
  final PreparedMedicationImage image;
  final CaptureServices services;
  final DateTime Function() _clock;
  final int _epoch;
  String? _token;
  late final Timer _expiry;
  OcrStage stage = OcrStage.preparing;
  OcrMatchResult? result;
  OcrFailure? failure;
  final timings = <String, Duration>{};
  String? _text;
  bool _busy = false, _closed = false, _disposed = false;
  int _generation = 0;
  Future<bool>? _closing;
  bool get busy => _busy;
  bool _current(int generation) =>
      !_closed &&
      generation == _generation &&
      services.sameSession(_epoch, _token) &&
      !image.isReleased &&
      _clock().isBefore(image.expiresAt);
  void _emit() {
    if (!_disposed) notifyListeners();
  }

  void _phase(OcrStage value) {
    stage = value;
    _emit();
  }

  void _sessionEnded() {
    unawaited(close());
  }

  void _expire() {
    if (_closed) return;
    unawaited(close().then((clean) {
      failure = OcrFailure(
          clean ? OcrFailureKind.expiredImage : OcrFailureKind.cleanup);
      _phase(OcrStage.failure);
    }));
  }

  Future<T> _timed<T>(String name, Future<T> Function() run) async {
    final watch = Stopwatch()..start();
    final trace = TimelineTask()..start('medication_scan.$name');
    try {
      return await run();
    } finally {
      watch.stop();
      timings[name] = watch.elapsed;
      trace.finish();
    }
  }

  Future<void> start() async {
    if (_busy || _closed) return;
    final generation = ++_generation;
    _busy = true;
    failure = null;
    result = null;
    _phase(_text == null ? OcrStage.preparing : OcrStage.matching);
    try {
      if (_token == null || _token!.isEmpty) {
        throw const OcrFailure(OcrFailureKind.unauthorized);
      }
      if (!_current(generation)) {
        throw const OcrFailure(OcrFailureKind.expiredImage);
      }
      if (_text == null) {
        final text = await services.runOcr(() async {
          Uint8List? bytes;
          try {
            bytes = await _timed('decrypt', image.read);
            if (!_current(generation)) {
              throw const OcrFailure(OcrFailureKind.expiredImage);
            }
            final prepare = Stopwatch()..start();
            final convertTrace = TimelineTask()
              ..start('medication_scan.convert');
            var converting = true;
            TimelineTask? nativeTrace;
            Stopwatch? native;
            try {
              return await _timed(
                  'prepare_native',
                  () => services.reader.recognize(bytes!,
                      isCurrent: () => _current(generation),
                      onRecognizing: () {
                        convertTrace.finish();
                        converting = false;
                        nativeTrace = TimelineTask()
                          ..start('medication_scan.native');
                        timings['convert'] = prepare.elapsed;
                        native = Stopwatch()..start();
                        if (_current(generation)) _phase(OcrStage.recognizing);
                      }));
            } finally {
              if (converting) {
                convertTrace.finish();
              }
              nativeTrace?.finish();
              if (native != null) timings['native'] = native!.elapsed;
            }
          } finally {
            bytes?.fillRange(0, bytes.length, 0);
          }
        }, () => _current(generation));
        if (!_current(generation)) return;
        validateOcrText(text, 5);
        _text = text;
      }
      if (!_current(generation)) return;
      _phase(OcrStage.matching);
      final matches = await _timed(
          'http', () => services.matching.match(_text!, sessionToken: _token!));
      if (!_current(generation)) return;
      result = matches;
      _text = null;
      _phase(OcrStage.result);
    } catch (e) {
      if (_closed || generation != _generation) return;
      failure =
          e is OcrFailure ? e : const OcrFailure(OcrFailureKind.invalidImage);
      if (!failure!.canRetry) _text = null;
      _phase(OcrStage.failure);
    } finally {
      _busy = false;
      _emit();
    }
  }

  Future<bool> close() {
    if (_closing != null) return _closing!;
    _closed = true;
    _generation++;
    _expiry.cancel();
    _text = null;
    _token = null;
    result = null;
    failure = null;
    services.removeListener(_sessionEnded);
    _phase(OcrStage.closed);
    return _closing = services.release(image).then((clean) {
      if (!clean) {
        failure = const OcrFailure(OcrFailureKind.cleanup);
        _phase(OcrStage.failure);
      }
      return clean;
    });
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(close());
    super.dispose();
  }
}
