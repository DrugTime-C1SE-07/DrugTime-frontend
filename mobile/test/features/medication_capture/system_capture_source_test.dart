import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:drugtime_mobile/features/medication_capture/data/system_capture_source.dart';
import 'package:drugtime_mobile/features/medication_capture/domain/capture_models.dart';

void main() {
  test('status read and explicit request are distinguished; settings delegated',
      () async {
    final requests = <bool>[];
    var settings = 0;
    final source = SystemCaptureSource(permissionCheck: (request) async {
      requests.add(request);
      return request
          ? CapturePermission.permanentlyDenied
          : CapturePermission.denied;
    }, settings: () async {
      settings++;
    });
    expect(await source.permission(), CapturePermission.denied);
    expect(await source.permission(request: true),
        CapturePermission.permanentlyDenied);
    await source.openSettings();
    expect(requests, [false, true]);
    expect(settings, 1);
    source.dispose();
  });
  test(
      'Settings launch failure is propagated so the camera screen can offer retry',
      () async {
    final source = SystemCaptureSource(settings: () async {
      throw const CaptureFailure('Không mở được Cài đặt.');
    });
    await expectLater(source.openSettings(), throwsA(isA<CaptureFailure>()));
    source.dispose();
  });
  test(
      'consume removes only returned app-cache staging; never gallery original',
      () async {
    final root = await Directory.systemTemp.createTemp('capture-source-');
    final cache = await Directory('${root.path}/cache').create();
    final staging = File('${cache.path}/camera.jpg');
    await staging.writeAsBytes([1, 2, 3]);
    final original = File('${root.path}/gallery.jpg');
    await original.writeAsBytes([4, 5, 6]);
    final source = SystemCaptureSource(cacheDirectory: () async => cache);
    expect(await source.consume(XFile(staging.path)), [1, 2, 3]);
    expect(await staging.exists(), isFalse);
    expect(await source.consume(XFile(original.path)), [4, 5, 6]);
    expect(await original.exists(), isTrue);
    source.dispose();
    await root.delete(recursive: true);
  });
}
