import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Rect;

/// Local experiment only: this schema is independent of patient/medication APIs.
class OcrRun {
  OcrRun(
      {required this.id,
      required this.imageId,
      required this.createdAt,
      required this.rawText,
      required this.status,
      required this.elapsedMs,
      required this.metadata,
      this.imagePath,
      this.errorCode});
  final String id, imageId, createdAt, rawText, status;
  final int elapsedMs;
  final Map<String, String> metadata;
  final String? imagePath, errorCode;
  Map<String, Object?> toJson() => {
        'schemaVersion': 1,
        'runId': id,
        'imageId': imageId,
        'createdAt': createdAt,
        'rawText': rawText,
        'status': status,
        'elapsedMs': elapsedMs,
        'metadata': metadata,
        'imagePath': imagePath,
        'errorCode': errorCode
      };
  factory OcrRun.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != 1) {
      throw const FormatException('Unsupported schema');
    }
    return OcrRun(
        id: json['runId'] as String,
        imageId: json['imageId'] as String,
        createdAt: json['createdAt'] as String,
        rawText: json['rawText'] as String,
        status: json['status'] as String,
        elapsedMs: json['elapsedMs'] as int,
        metadata: Map<String, String>.from(json['metadata'] as Map),
        imagePath: json['imagePath'] as String?,
        errorCode: json['errorCode'] as String?);
  }
  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());
}

abstract interface class OcrEngine {
  Future<String> recognize(String path);
  Future<void> close();
}

abstract interface class OcrImagePicker {
  Future<String?> pick();
  Future<String?> recover();
}

abstract interface class OcrStore {
  Future<String> prepareImage(String runId, String source);
  Future<void> save(OcrRun run);
  Future<List<OcrRun>> load();
  Future<File> export(OcrRun run);
}

abstract interface class OcrExporter {
  Future<bool> share(File file, Rect origin);
}
