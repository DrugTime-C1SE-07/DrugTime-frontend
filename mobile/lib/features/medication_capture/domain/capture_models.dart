import 'dart:typed_data';

// The classified values remain for existing encrypted image metadata.
enum PackagingKind { box, blister, unspecified }

enum CapturePermission { granted, denied, permanentlyDenied }

enum CaptureStage { starting, camera, reviewing, prepared, closed }

enum CaptureWarning { dark, blurred, bright, lowTexture }

class CaptureFailure implements Exception {
  const CaptureFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

class ProcessedCapture {
  const ProcessedCapture(this.bytes, this.width, this.height,
      {this.warnings = const []});
  final Uint8List bytes;
  final int width;
  final int height;
  final List<CaptureWarning> warnings;
}

/// The holder owns this image until release; no public path to ciphertext.
class PreparedMedicationImage {
  PreparedMedicationImage(
      {required this.id,
      required this.kind,
      required this.width,
      required this.height,
      required this.createdAt,
      required this.expiresAt,
      required Future<Uint8List> Function() read,
      required Future<void> Function() release})
      : _read = read,
        _release = release;
  final String id;
  final PackagingKind kind;
  final int width;
  final int height;
  final DateTime createdAt;
  final DateTime expiresAt;
  String get mimeType => 'image/jpeg';
  int get rotationDegrees => 0;
  final Future<Uint8List> Function() _read;
  final Future<void> Function() _release;
  Future<void>? _released;
  bool _revoked = false;
  bool get isReleased => _revoked;
  Future<Uint8List> read() {
    if (isReleased) throw const CaptureFailure('Ảnh không còn khả dụng.');
    return _read();
  }

  Future<void> release() {
    _revoked = true;
    return _released ??= _release().catchError((Object e, StackTrace stack) {
      _released = null;
      Error.throwWithStackTrace(e, stack);
    });
  }
}

enum CaptureResultKind { aborted, prepared }

class CaptureResult {
  const CaptureResult.aborted()
      : kind = CaptureResultKind.aborted,
        image = null;
  const CaptureResult.prepared(this.image) : kind = CaptureResultKind.prepared;
  final CaptureResultKind kind;
  final PreparedMedicationImage? image;
}

class CaptureCandidate {
  const CaptureCandidate(
      {required this.id,
      required this.name,
      required this.ingredient,
      required this.strength,
      this.registration});
  final String id;
  final String name;
  final String ingredient;
  final String strength;
  final String? registration;
}
