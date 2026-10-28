import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'app/theme/app_theme.dart';
import 'features/ocr_prototype/ocr_controller.dart';
import 'features/ocr_prototype/ocr_native.dart';
import 'features/ocr_prototype/ocr_screen.dart';
import 'features/ocr_prototype/ocr_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!supportsNativeOcr) {
    runApp(MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(
            body: Center(child: Text('Prototype OCR chỉ hỗ trợ Android.')))));
    return;
  }
  try {
    final root = Directory(
        p.join((await getApplicationSupportDirectory()).path, 'ocr_runs'));
    final controller = OcrController(
        engine: MlKitOcrEngine(),
        picker: GalleryOcrPicker(),
        store: FileOcrStore(root),
        rootPath: root.path);
    runApp(MaterialApp(
        theme: buildAppTheme(),
        home: OcrPrototypeScreen(
            controller: controller, exporter: SystemOcrExporter())));
  } catch (_) {
    runApp(MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(
            body: Center(
                child: Text(
                    'Không mở được bộ nhớ thử nghiệm. Hãy đóng và mở lại ứng dụng.')))));
  }
}
