import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/features/medication_capture/data/mlkit_ocr_reader.dart';
import 'package:drugtime_mobile/features/medication_capture/data/nv21_image_converter.dart';
import 'package:drugtime_mobile/features/medication_capture/domain/ocr_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('google_mlkit_text_recognizer');
  tearDown(() => TestDefaultBinaryMessengerBinding
      .instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, null));
  test('NV21 bytes no path; preserves newlines and clears buffer after close',
      () async {
    final calls = <String>[];
    final buffer = Uint8List.fromList([16, 16, 16, 16, 128, 128]);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      if (call.method == 'vision#closeTextRecognizer') return null;
      final data = (call.arguments as Map)['imageData'] as Map;
      expect(data['type'], 'bytes');
      expect(data['path'], isNull);
      expect((data['metadata'] as Map)['image_format'], 17);
      return {'text': 'A\r\n500mg', 'blocks': []};
    });
    final reader = MlKitOcrReader(
        supported: true, prepare: (_) async => Nv21Image(buffer, 2, 2));
    expect(
        await reader.recognize(Uint8List(1),
            isCurrent: () => true, onRecognizing: () {}),
        'A\r\n500mg');
    expect(calls, ['vision#startTextRecognizer', 'vision#closeTextRecognizer']);
    expect(buffer, everyElement(0));
  });
  test('cancel during prepare prevents native invocation', () async {
    var current = true, calls = 0;
    final pending = Completer<Nv21Image>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
      calls++;
      return null;
    });
    final reader =
        MlKitOcrReader(supported: true, prepare: (_) => pending.future);
    final future = reader.recognize(Uint8List(1),
        isCurrent: () => current, onRecognizing: () {});
    final assertion = expectLater(future, throwsA(isA<OcrFailure>()));
    current = false;
    pending.complete(Nv21Image(Uint8List(6), 2, 2));
    await assertion;
    expect(calls, 0);
  });
  test('native error closes recognizer and is not leaked', () async {
    var closed = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'vision#closeTextRecognizer') {
        closed = true;
        return null;
      }
      throw PlatformException(code: 'test', message: 'PRIVATE');
    });
    final reader = MlKitOcrReader(
        supported: true, prepare: (_) async => Nv21Image(Uint8List(6), 2, 2));
    await expectLater(
        reader.recognize(Uint8List(1),
            isCurrent: () => true, onRecognizing: () {}),
        throwsA(isA<OcrFailure>()));
    expect(closed, true);
  });
}
