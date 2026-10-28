import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'ocr_models.dart';

/// Private application-support directory; no patient identifiers or cloud writes.
class FileOcrStore implements OcrStore {
  FileOcrStore(this.root);
  final Directory root;
  void _checkId(String id) {
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(id)) {
      throw const FormatException('Invalid run ID');
    }
  }

  File _runFile(String id) {
    _checkId(id);
    return File(p.join(root.path, '$id.json'));
  }

  @override
  Future<String> prepareImage(String runId, String source) async {
    _checkId(runId);
    final bytes = await File(source).readAsBytes();
    if (bytes.isEmpty) throw const FormatException('Empty image');
    await root.create(recursive: true);
    final dir = Directory(p.join(root.path, runId));
    if (await dir.exists()) {
      throw const FileSystemException('Run already exists');
    }
    await dir.create();
    // Preserve the original encoding and extension; no resizing/recompression.
    final name = '$runId/image${p.extension(source)}';
    final destination = File(p.join(root.path, name));
    await destination.create(exclusive: true);
    await destination.writeAsBytes(bytes, flush: true);
    return name;
  }

  @override
  Future<void> save(OcrRun run) async {
    final target = _runFile(run.id);
    await root.create(recursive: true);
    // An exclusive lock serializes writers and prevents rename overwriting a run.
    final lock = File('${target.path}.lock');
    await lock.create(exclusive: true);
    final temporary = File('${target.path}.tmp');
    try {
      if (await target.exists()) {
        throw const FileSystemException('Run already saved');
      }
      await temporary.writeAsString(run.encode(), encoding: utf8, flush: true);
      await temporary.rename(target.path);
    } finally {
      if (await temporary.exists()) await temporary.delete();
      await lock.delete();
    }
  }

  @override
  Future<List<OcrRun>> load() async {
    if (!await root.exists()) return [];
    final runs = <OcrRun>[];
    await for (final entity in root.list()) {
      if (entity is File && p.extension(entity.path) == '.json') {
        runs.add(OcrRun.fromJson(
            jsonDecode(await entity.readAsString()) as Map<String, dynamic>));
      }
    }
    runs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return runs;
  }

  @override
  Future<File> export(OcrRun run) async {
    // Sharing this complete immutable JSON does not attach its image.
    final file = _runFile(run.id);
    final stored = OcrRun.fromJson(
        jsonDecode(await file.readAsString()) as Map<String, dynamic>);
    if (stored.encode() != run.encode()) {
      throw const FormatException('Stored run mismatch');
    }
    return file;
  }
}
