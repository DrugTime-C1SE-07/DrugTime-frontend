import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../domain/capture_models.dart';
import '../domain/capture_ports.dart';

class SystemCaptureSource extends CaptureSource {
  SystemCaptureSource(
      {ImagePicker? picker,
      Future<CapturePermission> Function(bool)? permissionCheck,
      Future<void> Function()? settings,
      Future<Directory> Function()? cacheDirectory})
      : _picker = picker ?? ImagePicker(),
        _permissionCheck = permissionCheck,
        _settings = settings,
        _cacheDirectory = cacheDirectory ?? getTemporaryDirectory;
  final ImagePicker _picker;
  final Future<CapturePermission> Function(bool)? _permissionCheck;
  final Future<void> Function()? _settings;
  final Future<Directory> Function() _cacheDirectory;
  CameraController? _camera;
  int _generation = 0;
  bool _flashAvailable = true;
  @override
  bool get ready => _camera?.value.isInitialized ?? false;
  @override
  bool get flashAvailable => ready && _flashAvailable;
  @override
  bool get flashOn => _camera?.value.flashMode == FlashMode.torch;
  @override
  Widget preview() {
    final camera = _camera;
    if (camera == null) return const SizedBox.expand();
    return ValueListenableBuilder<CameraValue>(
      valueListenable: camera,
      builder: (context, value, _) {
        final native = value.previewSize;
        if (!value.isInitialized || native == null) {
          return const SizedBox.expand();
        }
        final orientation = value.previewPauseOrientation ??
            value.lockedCaptureOrientation ??
            value.deviceOrientation;
        final landscape = orientation == DeviceOrientation.landscapeLeft ||
            orientation == DeviceOrientation.landscapeRight;
        final size = landscape ? native : Size(native.height, native.width);
        return ClipRect(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox.fromSize(size: size, child: CameraPreview(camera)),
          ),
        );
      },
    );
  }

  @override
  Future<CapturePermission> permission({bool request = false}) async {
    if (_permissionCheck != null) return _permissionCheck(request);
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return CapturePermission.denied;
    }
    final status = request
        ? await Permission.camera.request()
        : await Permission.camera.status;
    if (status.isGranted) return CapturePermission.granted;
    if (status.isPermanentlyDenied || status.isRestricted) {
      return CapturePermission.permanentlyDenied;
    }
    return CapturePermission.denied;
  }

  @override
  Future<void> openSettings() async {
    if (_settings != null) {
      await _settings();
      return;
    }
    if (!await openAppSettings()) {
      throw const CaptureFailure('Không mở được Cài đặt.');
    }
  }

  @override
  Future<void> initialize() async {
    if (ready) return;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw const CaptureFailure(
          'Camera hiện hỗ trợ Android. Bạn có thể chọn ảnh.');
    }
    final generation = ++_generation;
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      throw const CaptureFailure('Thiết bị không có camera.');
    }
    final selected = cameras
            .where((c) => c.lensDirection == CameraLensDirection.back)
            .firstOrNull ??
        cameras.first;
    final camera = CameraController(selected, ResolutionPreset.veryHigh,
        enableAudio: false);
    try {
      await camera.initialize();
      if (generation != _generation) {
        await camera.dispose();
        return;
      }
      _camera = camera;
      _flashAvailable = true;
      notifyListeners();
    } on CameraException {
      await camera.dispose();
      throw const CaptureFailure('Chưa mở được camera. Hãy thử lại.');
    }
  }

  @override
  Future<void> stop() async {
    _generation++;
    final camera = _camera;
    _camera = null;
    await camera?.dispose();
  }

  @override
  Future<void> toggleFlash() async {
    try {
      await _camera?.setFlashMode(flashOn ? FlashMode.off : FlashMode.torch);
      notifyListeners();
    } on CameraException {
      _flashAvailable = false;
      notifyListeners();
      throw const CaptureFailure('Thiết bị chưa bật được đèn.');
    }
  }

  @override
  Future<Uint8List> capture() async {
    final camera = _camera;
    if (camera == null || !ready) {
      throw const CaptureFailure('Camera chưa sẵn sàng.');
    }
    try {
      return await consume(await camera.takePicture());
    } on CameraException {
      throw const CaptureFailure('Chưa chụp được ảnh. Hãy thử lại.');
    }
  }

  @override
  Future<Uint8List?> pick() async {
    final file = await _picker.pickImage(
        source: ImageSource.gallery, requestFullMetadata: false);
    return file == null ? null : consume(file);
  }

  @override
  Future<Uint8List?> recover() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    final response = await _picker.retrieveLostData();
    if (response.exception != null) {
      throw const CaptureFailure('Chưa khôi phục được ảnh. Hãy chọn lại.');
    }
    final file = response.files?.firstOrNull;
    return file == null ? null : consume(file);
  }

  /// Only a returned plugin file inside the app cache is ours to remove.
  Future<Uint8List> consume(XFile file) async {
    final cache = p.normalize(p.absolute((await _cacheDirectory()).path));
    final target = p.normalize(p.absolute(file.path));
    final owned = p.isWithin(cache, target);
    try {
      return await file.readAsBytes();
    } finally {
      if (owned && await File(target).exists()) await File(target).delete();
    }
  }
}
