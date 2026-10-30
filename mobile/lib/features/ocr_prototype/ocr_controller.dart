import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../../core/storage/local_db/client_uuid.dart';
import 'ocr_models.dart';

Future<void> validateOcrImage(String path) async {
  final codec = await ui.instantiateImageCodec(await File(path).readAsBytes());
  codec.dispose();
}

class OcrController extends ChangeNotifier {
  OcrController(
      {required this.engine,
      required this.picker,
      required this.store,
      required this.rootPath,
      this.supported = true,
      this.validateImage = validateOcrImage,
      String Function()? newId})
      : newId = newId ?? createClientUuid;
  final OcrEngine engine;
  final OcrImagePicker picker;
  final OcrStore store;
  final String rootPath;
  final bool supported;
  final Future<void> Function(String) validateImage;
  final String Function() newId;
  bool busy = false, disposed = false;
  int _generation = 0;
  String? image, message, resourceError;
  OcrRun? result;
  bool saved = false;
  List<OcrRun> history = [];
  Future<void>? _active;
  Future<void>? closed;
  void _emit(int generation) {
    if (!disposed && generation == _generation) notifyListeners();
  }

  Future<void> _exclusive(Future<void> Function(int) action) async {
    if (busy || disposed || !supported) return;
    busy = true;
    final generation = ++_generation;
    message = null;
    _emit(generation);
    final operation = Future<void>.sync(() => action(generation));
    _active = operation;
    try {
      await operation;
    } finally {
      busy = false;
      _emit(generation);
    }
  }

  Future<void> initialize() => _exclusive((generation) async {
        try {
          history = await store.load();
        } catch (_) {
          message = 'Không đọc được lịch sử. Kiểm tra bộ nhớ và thử lại.';
        }
        try {
          final recovered = await picker.recover();
          if (!disposed && recovered != null) {
            image = recovered;
            message = 'Đã khôi phục ảnh đã chọn. Kiểm tra mã ảnh rồi chạy lại.';
          }
        } catch (_) {
          message = 'Không khôi phục được ảnh. Hãy chọn ảnh khác.';
        }
      });
  Future<void> pick() => _exclusive((generation) async {
        if (result != null && !saved) {
          message = 'Lưu kết quả hiện tại trước khi đổi ảnh.';
          return;
        }
        try {
          final selected = await picker.pick();
          if (disposed) return;
          if (selected == null) {
            message = 'Đã hủy chọn ảnh.';
            return;
          }
          image = selected;
          result = null;
          saved = false;
        } catch (_) {
          message = 'Không mở được thư viện ảnh. Kiểm tra quyền và thử lại.';
        }
      });
  Future<void> run(String imageId, Map<String, String> metadata) =>
      _exclusive((generation) async {
        if (result != null && !saved) {
          message = 'Lưu kết quả hiện tại trước khi chạy tiếp.';
          return;
        }
        const requiredKeys = [
          'platform',
          'deviceModel',
          'osVersion',
          'appRevision',
          'nativeSdkVersion'
        ];
        if (image == null ||
            imageId.trim().isEmpty ||
            requiredKeys.any((key) => (metadata[key] ?? '').trim().isEmpty)) {
          message =
              'Chọn ảnh và điền đủ mã ảnh, thiết bị, OS, revision và native SDK.';
          return;
        }
        final source = image!;
        final id = newId();
        String? relative;
        String raw = '', status = 'input_error';
        String? errorCode;
        final timer = Stopwatch();
        try {
          await validateImage(source);
          relative = await store.prepareImage(id, source);
        } catch (_) {
          errorCode = 'image_unavailable_or_invalid';
        }
        if (relative != null) {
          timer.start();
          try {
            raw = await engine.recognize(p.join(rootPath, relative));
            status = raw.trim().isEmpty ? 'no_text' : 'text';
          } catch (_) {
            status = 'engine_error';
            errorCode = 'recognition_failed';
          } finally {
            timer.stop();
          }
        }
        final timestamp = DateTime.now().toUtc().add(const Duration(hours: 7));
        result = OcrRun(
            id: id,
            imageId: imageId.trim(),
            createdAt:
                '${timestamp.toIso8601String().replaceAll('Z', '')}+07:00',
            rawText: raw,
            status: status,
            elapsedMs: timer.elapsedMilliseconds,
            imagePath: relative,
            errorCode: errorCode,
            metadata: {
              ...metadata,
              'engine': 'google_mlkit_text_recognition',
              'packageVersion': '0.17.1',
              'script': 'latin',
              'preprocessing': 'none',
              'modelVersion': 'not_exposed',
              'metadataSource': 'tester_confirmed',
              'timezone': 'Asia/Ho_Chi_Minh'
            });
        saved = false;
        await _persist();
      });
  Future<void> _persist() async {
    final run = result;
    if (run == null) return;
    try {
      await store.save(run);
      saved = true;
      history = [run, ...history.where((entry) => entry.id != run.id)];
    } catch (_) {
      message = 'Chưa lưu được kết quả. Giữ màn hình và bấm Lưu lại.';
    }
  }

  Future<void> retrySave() => _exclusive((_) async {
        if (!saved) await _persist();
      });
  Future<void> export(OcrRun run, OcrExporter exporter, ui.Rect origin) =>
      _exclusive((_) async {
        try {
          final file = await store.export(run);
          final shared = await exporter.share(file, origin);
          message = shared
              ? 'Đã chia sẻ JSON.'
              : 'Chưa xác nhận chia sẻ; bản lưu vẫn còn trên thiết bị.';
        } catch (_) {
          message = 'Không xuất được JSON. Bản lưu được giữ lại; hãy thử lại.';
        }
      });
  @override
  void dispose() {
    disposed = true;
    _generation++;
    closed = () async {
      try {
        await _active;
        await engine.close();
      } catch (_) {
        resourceError = 'engine_close_failed';
      }
    }();
    super.dispose();
  }
}
