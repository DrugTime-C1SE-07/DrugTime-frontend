import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/features/medication_capture/data/encrypted_capture_store.dart';
import 'package:drugtime_mobile/features/medication_capture/domain/capture_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late EncryptedCaptureStore store;
  late DateTime now;
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    root = await Directory.systemTemp.createTemp('capture-test-');
    now = DateTime.utc(2026, 10, 30);
    store =
        EncryptedCaptureStore(directory: () async => root, clock: () => now);
  });
  tearDown(() async {
    await store.clear();
    await root.delete(recursive: true);
  });
  ProcessedCapture sample() => ProcessedCapture(
      Uint8List.fromList(utf8.encode('PRIVATE IMAGE DATA')), 12, 10);
  test(
      'encrypted roundtrip, distinct nonce, no plaintext file; release idempotent',
      () async {
    final first = await store.save(sample(), PackagingKind.box),
        second = await store.save(sample(), PackagingKind.blister);
    expect(utf8.decode(await first.read()), 'PRIVATE IMAGE DATA');
    final files = root.listSync().whereType<File>().toList();
    expect(files, hasLength(2));
    final data = files.map((f) => f.readAsStringSync()).toList();
    expect(data.every((s) => !s.contains('PRIVATE IMAGE DATA')), isTrue);
    final boxes = data.map((s) => jsonDecode(s)['box']).toList();
    expect(boxes[0], isNot(boxes[1]));
    await first.release();
    await first.release();
    expect(await second.read(), isNotEmpty);
  });
  test('expires at exactly 24h and removes owned ciphertext', () async {
    final lease = await store.save(sample(), PackagingKind.box);
    now = now.add(const Duration(hours: 24));
    await expectLater(lease.read(), throwsA(isA<CaptureFailure>()));
    expect(root.listSync(), isEmpty);
  });
  test(
      'unclassified images roundtrip without rewriting legacy authenticated metadata',
      () async {
    final legacy = await store.save(sample(), PackagingKind.box);
    final legacyFile = root.listSync().whereType<File>().single;
    final legacyEnvelope = await legacyFile.readAsString();
    final current = await store.save(sample(), PackagingKind.unspecified);
    expect(current.kind, PackagingKind.unspecified);
    expect(await current.read(), await legacy.read());
    expect(await legacyFile.readAsString(), legacyEnvelope);
  });
  test('modified ciphertext is rejected and removed', () async {
    final lease = await store.save(sample(), PackagingKind.box);
    final file = root.listSync().whereType<File>().single;
    final envelope =
        jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final bytes = base64Decode(envelope['box'] as String);
    bytes[bytes.length - 1] ^= 1;
    envelope['box'] = base64Encode(bytes);
    await file.writeAsString(jsonEncode(envelope));
    await expectLater(lease.read(), throwsA(isA<CaptureFailure>()));
    expect(root.listSync(), isEmpty);
  });
  test(
      'clear invalidates active leases; startup removes orphan only in dedicated folder',
      () async {
    final lease = await store.save(sample(), PackagingKind.box);
    await store.clear();
    await expectLater(lease.read(), throwsA(isA<CaptureFailure>()));
    await File('${root.path}/orphan.capture.part')
        .writeAsString('ciphertext fragment');
    await File('${root.path}/keep.txt').writeAsString('unrelated');
    await store.initialize();
    expect(await File('${root.path}/orphan.capture.part').exists(), isFalse);
    expect(await File('${root.path}/keep.txt').readAsString(), 'unrelated');
  });
  test('failed storage initialization cannot fallback to plaintext', () async {
    final file = File('${root.path}/not-a-directory');
    await file.writeAsString('not a directory');
    final bad =
        EncryptedCaptureStore(directory: () async => Directory(file.path));
    await expectLater(bad.save(sample(), PackagingKind.box),
        throwsA(isA<FileSystemException>()));
    expect(await file.readAsString(), 'not a directory');
  });
}
