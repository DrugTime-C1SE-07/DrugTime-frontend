import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:drugtime_mobile/features/medication_capture/domain/capture_models.dart';
import 'package:drugtime_mobile/features/medication_capture/domain/capture_ports.dart';
import 'package:drugtime_mobile/features/medication_capture/presentation/state/capture_controller.dart';

Uint8List makeImage({int width = 64, int height = 48, int value = 160}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(value, value, value));
  return Uint8List.fromList(img.encodePng(image));
}

class TestSource extends CaptureSource {
  CapturePermission access = CapturePermission.granted;
  bool available = false, torch = false;
  int captures = 0, requests = 0, initializations = 0, stops = 0;
  int settingsCalls = 0;
  final statusRequests = <bool>[];
  Completer<Uint8List>? pending;
  Completer<CapturePermission>? permissionPending;
  Completer<void>? settingsPending;
  Uint8List? picked, recovered;
  bool fail = false, settingsFail = false;
  @override
  bool get ready => available;
  @override
  bool get flashAvailable => available;
  @override
  bool get flashOn => torch;
  @override
  Widget preview() =>
      const ColoredBox(color: Colors.black, key: Key('test-camera'));
  @override
  Future<CapturePermission> permission({bool request = false}) async {
    requests++;
    statusRequests.add(request);
    return permissionPending == null ? access : permissionPending!.future;
  }

  @override
  Future<void> openSettings() async {
    settingsCalls++;
    if (settingsFail) throw const CaptureFailure('Không mở được Cài đặt.');
    await settingsPending?.future;
  }

  @override
  Future<void> initialize() async {
    initializations++;
    available = true;
    notifyListeners();
  }

  @override
  Future<void> stop() async {
    stops++;
    available = false;
    torch = false;
  }

  @override
  Future<void> toggleFlash() async {
    torch = !torch;
    notifyListeners();
  }

  @override
  Future<Uint8List> capture() async {
    captures++;
    if (fail) throw const CaptureFailure('Lỗi chụp');
    return pending == null ? makeImage() : pending!.future;
  }

  @override
  Future<Uint8List?> pick() async => picked;
  @override
  Future<Uint8List?> recover() async => recovered;
}

class TestProcessor implements CaptureProcessor {
  final pending = <Completer<ProcessedCapture>>[];
  bool delayed = false, failProcessing = false;
  List<CaptureWarning> warnings = const [];
  @override
  Future<ProcessedCapture> process(Uint8List bytes) async {
    if (failProcessing) throw const CaptureFailure('Không mở được ảnh này.');
    if (delayed) {
      final task = Completer<ProcessedCapture>();
      pending.add(task);
      return task.future;
    }
    return ProcessedCapture(bytes, 64, 48, warnings: warnings);
  }
}

class TestStore implements CaptureStore {
  int saves = 0, releases = 0, clears = 0;
  final live = <String, Uint8List>{};
  @override
  Future<void> initialize() async {}
  @override
  Future<void> clear() async {
    clears++;
    live.clear();
  }

  @override
  Future<PreparedMedicationImage> save(
      ProcessedCapture image, PackagingKind kind) async {
    final id = 'test-${saves++}';
    live[id] = image.bytes;
    final now = DateTime.now();
    return PreparedMedicationImage(
        id: id,
        kind: kind,
        width: image.width,
        height: image.height,
        createdAt: now,
        expiresAt: now.add(const Duration(hours: 24)),
        read: () async {
          final bytes = live[id];
          if (bytes == null) throw const CaptureFailure('Hết phiên');
          return bytes;
        },
        release: () async {
          releases++;
          live.remove(id);
        });
  }
}

void main() {
  for (final scenario in <(List<CaptureWarning>, bool)>[
    ([], true),
    ([CaptureWarning.dark], false),
    ([CaptureWarning.blurred], false),
    ([CaptureWarning.dark, CaptureWarning.blurred], false),
    ([CaptureWarning.bright, CaptureWarning.dark], false),
    ([CaptureWarning.bright], true),
    ([CaptureWarning.lowTexture], true),
  ]) {
    test('image quality ${scenario.$1} permits handoff: ${scenario.$2}',
        () async {
      final store = TestStore();
      final processor = TestProcessor()..warnings = scenario.$1;
      final c = CaptureController(
          source: TestSource(), processor: processor, store: store);
      await c.accept(makeImage());
      expect(c.canUseImage, scenario.$2);
      final prepared = await c.prepare();
      expect(prepared != null, scenario.$2);
      expect(store.saves, scenario.$2 ? 1 : 0);
      await c.close();
      c.dispose();
    });
  }
  test('entry reads status; only explicit permission action requests access',
      () async {
    final source = TestSource()..access = CapturePermission.denied;
    final c = CaptureController(
        source: source, processor: TestProcessor(), store: TestStore());
    await c.start();
    expect(source.statusRequests, [false]);
    expect(source.ready, isFalse);
    source.access = CapturePermission.granted;
    await c.requestPermission();
    expect(source.statusRequests, [false, true]);
    expect(source.ready, isTrue);
    await c.requestPermission(request: false);
    expect(source.initializations, 1);
    await c.close();
    c.dispose();
  });
  test(
      'double capture is one operation; stale completion cannot revive a closed flow',
      () async {
    final source = TestSource()..pending = Completer<Uint8List>();
    final c = CaptureController(
        source: source, processor: TestProcessor(), store: TestStore());
    await c.start();
    final task = c.takePhoto();
    await c.takePhoto();
    expect(source.captures, 1);
    await c.close();
    source.pending!.complete(makeImage());
    await task;
    expect(c.stage, CaptureStage.closed);
    expect(c.image, isNull);
    c.dispose();
  });
  test(
      'resuming permission dialog never asks twice; Settings resume reads status',
      () async {
    final source = TestSource()..access = CapturePermission.denied;
    final c = CaptureController(
        source: source, processor: TestProcessor(), store: TestStore());
    await c.start();
    source.permissionPending = Completer<CapturePermission>();
    final request = c.requestPermission();
    await Future<void>.delayed(Duration.zero);
    await c.background();
    await c.resume();
    source.permissionPending!.complete(CapturePermission.granted);
    await request;
    expect(source.requests, 2);
    source.permissionPending = null;
    await c.openSettings();
    await c.background();
    await c.resume();
    source.access = CapturePermission.granted;
    await c.resume();
    expect(source.statusRequests, [false, true, false, false]);
    expect(source.ready, isTrue);
    await c.close();
    c.dispose();
  });
  test(
      'Settings is single-flight; a late Settings result still reads resumed status',
      () async {
    final source = TestSource()
      ..access = CapturePermission.permanentlyDenied
      ..settingsPending = Completer<void>();
    final c = CaptureController(
        source: source, processor: TestProcessor(), store: TestStore());
    await c.start();
    final opening = c.openSettings();
    await c.openSettings();
    expect(source.settingsCalls, 1);
    await c.background();
    source.access = CapturePermission.granted;
    await c.resume();
    source.settingsPending!.complete();
    await opening;
    expect(source.statusRequests, [false, false]);
    expect(source.ready, isTrue);
    await c.close();
    c.dispose();
  });
  test('Settings failure leaves an actionable error and allows retry',
      () async {
    final source = TestSource()
      ..access = CapturePermission.permanentlyDenied
      ..settingsFail = true;
    final c = CaptureController(
        source: source, processor: TestProcessor(), store: TestStore());
    await c.start();
    await c.openSettings();
    expect(c.error, 'Không mở được Cài đặt.');
    source.settingsFail = false;
    await c.openSettings();
    expect(source.settingsCalls, 2);
    expect(c.error, isNull);
    expect(source.statusRequests, [false]);
    await c.close();
    c.dispose();
  });
  test('gallery cancel returns to camera; resume in review never opens it',
      () async {
    final source = TestSource();
    final c = CaptureController(
        source: source, processor: TestProcessor(), store: TestStore());
    await c.start();
    await c.pickPhoto();
    expect(c.stage, CaptureStage.camera);
    expect(source.ready, isTrue);
    source.picked = makeImage();
    await c.pickPhoto();
    final inits = source.initializations;
    await c.background();
    await c.resume();
    expect(c.stage, CaptureStage.reviewing);
    expect(source.initializations, inits);
    await c.close();
    c.dispose();
  });
  test(
      'prepared lease survives flow closure only after explicit ownership transfer',
      () async {
    final store = TestStore();
    final c = CaptureController(
        source: TestSource(), processor: TestProcessor(), store: store);
    await c.accept(makeImage());
    final lease = await c.prepare();
    expect(lease, isNotNull);
    expect(lease!.kind, PackagingKind.unspecified);
    expect(await c.prepare(), isNull);
    expect(c.takeLease(), same(lease));
    await c.close();
    expect(store.releases, 0);
    expect(await lease.read(), isNotEmpty);
    await lease.release();
    await lease.release();
    expect(store.releases, 1);
    c.dispose();
  });
  test('older image output cannot overwrite a newer one', () async {
    final processor = TestProcessor()..delayed = true;
    final c = CaptureController(
        source: TestSource(), processor: processor, store: TestStore());
    final first = c.accept(makeImage());
    await Future<void>.delayed(Duration.zero);
    final second = c.accept(makeImage(value: 220));
    await Future<void>.delayed(Duration.zero);
    final newer = ProcessedCapture(makeImage(value: 220), 32, 24);
    processor.pending[1].complete(newer);
    await second;
    processor.pending[0].complete(ProcessedCapture(makeImage(), 64, 48));
    await first;
    expect(c.image, same(newer));
    expect(c.busy, isFalse);
    await c.close();
    c.dispose();
  });
  test('retake invalidates pending image processing and returns to camera',
      () async {
    final processor = TestProcessor()..delayed = true;
    final c = CaptureController(
        source: TestSource(), processor: processor, store: TestStore());
    final processing = c.accept(makeImage());
    await Future<void>.delayed(Duration.zero);
    await c.retake();
    processor.pending.single.complete(ProcessedCapture(makeImage(), 64, 48));
    await processing;
    expect(c.stage, CaptureStage.camera);
    expect(c.source.ready, isTrue);
    expect(c.image, isNull);
    expect(c.busy, isFalse);
    await c.close();
    c.dispose();
  });
  test('camera error leaves retry and no medication output', () async {
    final source = TestSource()..fail = true;
    final c = CaptureController(
        source: source, processor: TestProcessor(), store: TestStore());
    await c.start();
    await c.takePhoto();
    expect(c.error, 'Lỗi chụp');
    expect(c.busy, isFalse);
    expect(c.image, isNull);
    await c.close();
    c.dispose();
  });
}
