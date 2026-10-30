import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:drugtime_mobile/features/ocr_prototype/ocr_models.dart';
import 'package:drugtime_mobile/features/ocr_prototype/ocr_store.dart';
import 'package:drugtime_mobile/features/ocr_prototype/ocr_controller.dart';
import 'package:drugtime_mobile/features/ocr_prototype/ocr_native.dart';

class _FixturePicker implements OcrImagePicker {
  _FixturePicker(this.path);
  final String path;
  @override
  Future<String?> pick() async => path;
  @override
  Future<String?> recover() async => null;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const base64Image = String.fromEnvironment('OCR_IMAGE_BASE64');
  const imagePath = String.fromEnvironment('OCR_IMAGE_PATH');
  const expected = String.fromEnvironment('OCR_EXPECTED_TEXT');
  testWidgets('ML Kit native recognizes supplied packaging fixture offline',
      (tester) async {
    final dir = await Directory.systemTemp.createTemp('ocr_native_');
    final image = File('${dir.path}/fixture.png');
    final root = Directory(
        p.join((await getApplicationSupportDirectory()).path, 'ocr_runs'));
    final store = FileOcrStore(root);
    final controller = OcrController(
        engine: MlKitOcrEngine(),
        picker: _FixturePicker(image.path),
        store: store,
        rootPath: root.path);
    try {
      await image.writeAsBytes(imagePath.isEmpty
          ? base64Decode(base64Image)
          : await File(imagePath).readAsBytes());
      await controller.initialize();
      await controller.pick();
      await controller.run(
          const String.fromEnvironment('OCR_IMAGE_ID',
              defaultValue: 'native-fixture'),
          {
            'platform': 'Android',
            'deviceModel': const String.fromEnvironment('OCR_DEVICE_MODEL'),
            'osVersion': const String.fromEnvironment('OCR_OS_VERSION'),
            'appRevision': const String.fromEnvironment('OCR_APP_REVISION'),
            'nativeSdkVersion':
                const String.fromEnvironment('OCR_NATIVE_SDK_VERSION'),
            'deviceKind': const String.fromEnvironment('OCR_DEVICE_KIND',
                defaultValue: 'unspecified'),
            'purpose': 'native_smoke_pilot',
            'imageSource': const String.fromEnvironment('OCR_IMAGE_SOURCE',
                defaultValue: 'tester_supplied_fixture'),
            'datasetVersion': 'pilot_only_unverified',
          });
      expect(controller.saved, isTrue, reason: controller.message);
      final run = controller.result!;
      expect(run.status, 'text');
      expect(run.rawText, isNotEmpty);
      if (expected.isNotEmpty) expect(run.rawText, contains(expected));
      final exported = await store.export(run);
      final decoded = OcrRun.fromJson(
          jsonDecode(await exported.readAsString()) as Map<String, dynamic>);
      expect(decoded.encode(), run.encode());
      binding.reportData = {
        'rawExports': [await exported.readAsString()]
      };
      expect((await store.load()).any((entry) => entry.id == run.id), isTrue);
    } finally {
      controller.dispose();
      await controller.closed;
      await dir.delete(recursive: true);
    }
  }, skip: base64Image.isEmpty && imagePath.isEmpty);
  testWidgets(
      'native blank image returns no text; invalid image rejected before engine',
      (tester) async {
    final dir = await Directory.systemTemp.createTemp('ocr_blank_');
    final engine = MlKitOcrEngine();
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawColor(const ui.Color(0xFFFFFFFF), ui.BlendMode.src);
    final picture = recorder.endRecording();
    final image = await picture.toImage(100, 100);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('${dir.path}/blank.png');
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      expect((await engine.recognize(file.path)).trim(), isEmpty);
      final bad = File('${dir.path}/bad.png');
      await bad.writeAsString('not an image');
      await expectLater(validateOcrImage(bad.path), throwsA(anything));
    } finally {
      image.dispose();
      picture.dispose();
      await engine.close();
      await dir.delete(recursive: true);
    }
  });
}
