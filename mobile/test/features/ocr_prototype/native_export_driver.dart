import 'dart:convert';
import 'dart:io';
import 'package:integration_test/integration_test_driver.dart';

/// Host callback transfers the original JSON payload before test app cleanup.
Future<void> main() async {
  final destination = Platform.environment['OCR_RESULTS_DIR'];
  if (destination == null || destination.isEmpty) {
    throw StateError(
        'OCR_RESULTS_DIR must point to the task results directory');
  }
  await integrationDriver(responseDataCallback: (data) async {
    final exports = (data?['rawExports'] as List?)?.cast<String>();
    if (exports == null || exports.isEmpty) {
      throw StateError('No native OCR exports received');
    }
    final directory = Directory('$destination/runs');
    await directory.create(recursive: true);
    for (final encoded in exports) {
      final run = jsonDecode(encoded) as Map<String, dynamic>;
      final id = run['runId'] as String;
      if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(id)) {
        throw const FormatException('Invalid run ID');
      }
      final file = File('${directory.path}/$id.json');
      if (await file.exists()) {
        if (await file.readAsString() != encoded) {
          throw StateError('Refusing to overwrite an existing run');
        }
      } else {
        await file.create(exclusive: true);
        await file.writeAsString(encoded, encoding: utf8, flush: true);
      }
    }
  });
}
