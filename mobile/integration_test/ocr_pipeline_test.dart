import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:drugtime_mobile/features/medication_capture/data/encrypted_capture_store.dart';
import 'package:drugtime_mobile/features/medication_capture/data/mlkit_ocr_reader.dart';
import 'package:drugtime_mobile/features/medication_capture/domain/capture_models.dart';
import 'package:drugtime_mobile/features/medication_capture/domain/ocr_models.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
      'native reads in-memory packaging; encrypted files only; blank/cancel cleanup',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Text('OCR native verification'))));
    await tester.runAsync(() async {
      final parent = await getTemporaryDirectory();
      final root =
          await Directory('${parent.path}/ocr-pipeline-test').createTemp();
      final store = EncryptedCaptureStore(directory: () async => root);
      final reader = MlKitOcrReader();
      try {
        final pixels = img.Image(width: 720, height: 320);
        img.fill(pixels, color: img.ColorRgb8(255, 255, 255));
        img.drawString(pixels, 'PANADOL',
            font: img.arial48, x: 40, y: 60, color: img.ColorRgb8(0, 0, 0));
        img.drawString(pixels, '500 mg',
            font: img.arial48, x: 40, y: 150, color: img.ColorRgb8(0, 0, 0));
        final lease = await store.save(
            ProcessedCapture(
                Uint8List.fromList(img.encodeJpg(pixels)), 720, 320),
            PackagingKind.unspecified);
        final bytes = await lease.read();
        try {
          final text = await reader.recognize(bytes,
              isCurrent: () => true, onRecognizing: () {});
          expect(text.toUpperCase(), contains('PANADOL'));
          expect(text, contains('500'));
        } finally {
          bytes.fillRange(0, bytes.length, 0);
        }
        final files = await root.list().toList();
        expect(files, hasLength(1));
        expect(files.single.path, endsWith('.capture'));
        expect(
            (await File(files.single.path).readAsString()), contains('"box"'));
        var current = true;
        await expectLater(
            reader.recognize(await lease.read(),
                isCurrent: () => current,
                onRecognizing: () {
                  current = false;
                }),
            throwsA(isA<OcrFailure>()));
        await lease.release();
        final blank = img.Image(width: 320, height: 128);
        img.fill(blank, color: img.ColorRgb8(255, 255, 255));
        final blankBytes = Uint8List.fromList(img.encodeJpg(blank));
        try {
          expect(
              (await reader.recognize(blankBytes,
                      isCurrent: () => true, onRecognizing: () {}))
                  .trim(),
              isEmpty);
        } finally {
          blankBytes.fillRange(0, blankBytes.length, 0);
        }
        expect(await root.list().toList(), isEmpty);
      } finally {
        await store.clear();
        if (!root.path.startsWith('${parent.path}/')) {
          throw StateError('Unexpected temporary directory');
        }
        await root.delete(recursive: true);
      }
    });
  });
}
