import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../domain/capture_models.dart';
import '../domain/capture_ports.dart';

class EncryptedCaptureStore implements CaptureStore {
  EncryptedCaptureStore(
      {FlutterSecureStorage? keyStorage,
      Future<Directory> Function()? directory,
      DateTime Function()? clock})
      : _keys = keyStorage ?? const FlutterSecureStorage(),
        _directory = directory ??
            (() async => Directory(p.join((await getTemporaryDirectory()).path,
                'medication_capture_v1'))),
        _clock = clock ?? DateTime.now;
  final FlutterSecureStorage _keys;
  final Future<Directory> Function() _directory;
  final DateTime Function() _clock;
  static const keyName = 'medication_capture_session_key_v1';
  final _cipher = AesGcm.with256bits();
  Directory? _root;
  SecretKey? _key;
  Future<void>? _initializing;
  int _generation = 0;
  final _timers = <String, Timer>{};
  String? cleanupError;

  @override
  Future<void> initialize() {
    final task = _initializing ??= _initialize();
    return task.catchError((Object e, StackTrace stack) {
      if (identical(_initializing, task)) {
        _initializing = null;
      }
      Error.throwWithStackTrace(e, stack);
    });
  }

  Future<void> _initialize() async {
    final generation = ++_generation;
    _root = await _directory();
    await _root!.create(recursive: true);
    // Old sessions are never restored: drafts retain checked fields, not photos.
    await _purgeFiles();
    final key = await _cipher.newSecretKey();
    if (generation != _generation) {
      throw const CaptureFailure('Phiên chụp đã kết thúc.');
    }
    await _keys.write(
        key: keyName, value: base64Encode(await key.extractBytes()));
    if (generation != _generation) {
      await _keys.delete(key: keyName);
      throw const CaptureFailure('Phiên chụp đã kết thúc.');
    }
    _key = key;
  }

  @override
  Future<PreparedMedicationImage> save(
      ProcessedCapture image, PackagingKind kind) async {
    await initialize();
    final key = _key;
    if (key == null) {
      throw const CaptureFailure('Không thể lưu ảnh an toàn. Hãy thử lại.');
    }
    final generation = _generation;
    final id = List.generate(16, (_) => Random.secure().nextInt(256))
        .map((v) => v.toRadixString(16).padLeft(2, '0'))
        .join();
    final created = _clock().toUtc();
    final expires = created.add(const Duration(hours: 24));
    final header = jsonEncode({
      'v': 1,
      'id': id,
      'created': created.toIso8601String(),
      'expires': expires.toIso8601String(),
      'width': image.width,
      'height': image.height,
      'kind': kind.name
    });
    final box = await _cipher.encrypt(image.bytes,
        secretKey: key, aad: utf8.encode(header));
    if (generation != _generation) {
      throw const CaptureFailure('Phiên chụp đã kết thúc.');
    }
    final file = File(p.join(_root!.path, '$id.capture'));
    final staging = File('${file.path}.part');
    try {
      await staging.writeAsString(
          jsonEncode(
              {'header': header, 'box': base64Encode(box.concatenation())}),
          flush: true);
      if (generation != _generation) {
        throw const CaptureFailure('Phiên chụp đã kết thúc.');
      }
      await staging.rename(file.path);
      if (generation != _generation) {
        await _delete(file);
        throw const CaptureFailure('Phiên chụp đã kết thúc.');
      }
    } finally {
      if (await staging.exists()) await staging.delete();
    }
    Future<void> release() async {
      _timers.remove(id)?.cancel();
      await _delete(file);
    }

    _timers[id] = Timer(
        expires.difference(created),
        () => unawaited(release().catchError((Object e) {
              cleanupError = 'Chưa dọn được ảnh hết hạn.';
            })));
    return PreparedMedicationImage(
        id: id,
        kind: kind,
        width: image.width,
        height: image.height,
        createdAt: created,
        expiresAt: expires,
        release: release,
        read: () async {
          if (generation != _generation ||
              !_clock().toUtc().isBefore(expires)) {
            await release();
            throw const CaptureFailure('Ảnh đã hết hạn. Hãy chụp lại.');
          }
          try {
            final data =
                jsonDecode(await file.readAsString()) as Map<String, dynamic>;
            if (data['header'] != header) {
              throw const CaptureFailure('Không thể mở ảnh an toàn.');
            }
            final encrypted = SecretBox.fromConcatenation(
                base64Decode(data['box'] as String),
                nonceLength: _cipher.nonceLength,
                macLength: _cipher.macAlgorithm.macLength);
            final bytes = await _cipher.decrypt(encrypted,
                secretKey: key, aad: utf8.encode(header));
            if (generation != _generation ||
                !_clock().toUtc().isBefore(expires)) {
              await release();
              throw const CaptureFailure('Ảnh đã hết hạn. Hãy chụp lại.');
            }
            return Uint8List.fromList(bytes);
          } on FileSystemException {
            throw const CaptureFailure('Ảnh không còn khả dụng. Hãy chụp lại.');
          } on SecretBoxAuthenticationError {
            await release();
            throw const CaptureFailure(
                'Không thể mở ảnh an toàn. Hãy chụp lại.');
          } on FormatException {
            await release();
            throw const CaptureFailure(
                'Không thể mở ảnh an toàn. Hãy chụp lại.');
          }
        });
  }

  Future<void> _delete(File file) async {
    try {
      await file.delete();
    } on FileSystemException catch (e) {
      if (e.osError?.errorCode != 2 && await file.exists()) rethrow;
    }
  }

  @override
  Future<void> clear() async {
    _generation++;
    _key = null;
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    await _purgeFiles();
    await _keys.delete(key: keyName);
    _initializing = null;
  }

  Future<void> _purgeFiles() async {
    final root = _root;
    if (root != null && await root.exists()) {
      await for (final entry in root.list(followLinks: false)) {
        if (entry is File &&
            (entry.path.endsWith('.capture') || entry.path.endsWith('.part'))) {
          await _delete(entry);
        }
      }
    }
  }
}
