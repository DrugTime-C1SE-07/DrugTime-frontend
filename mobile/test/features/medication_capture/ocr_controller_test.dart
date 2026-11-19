import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/features/medication_capture/data/capture_services.dart';
import 'package:drugtime_mobile/features/medication_capture/domain/capture_models.dart';
import 'package:drugtime_mobile/features/medication_capture/domain/ocr_models.dart';
import 'package:drugtime_mobile/features/medication_capture/domain/ocr_ports.dart';
import 'package:drugtime_mobile/features/medication_capture/presentation/state/ocr_controller.dart';
import 'capture_controller_test.dart' show TestSource, TestStore, TestProcessor;

class FakeReader implements OcrTextReader {
  int calls = 0;
  String text = 'TEST\r\n500mg';
  Completer<String>? pending;
  @override
  Future<String> recognize(Uint8List jpeg,
      {required bool Function() isCurrent,
      required void Function() onRecognizing}) async {
    calls++;
    onRecognizing();
    return pending == null ? text : await pending!.future;
  }
}

class FakeMatcher implements OcrMatchingRepository {
  int calls = 0;
  bool fail = false;
  String? token;
  Completer<OcrMatchResult>? pending;
  OcrMatchResult result = OcrMatchResult(
      status: OcrMatchStatus.matched,
      items: [
        const OcrCandidate(
            id: 1,
            name: 'Thuốc kiểm thử',
            activeIngredient: null,
            strengthText: '500 mg',
            dosageForm: null,
            hasActiveIngredients: false,
            score: 0.8)
      ],
      preselectedId: 1,
      suggestedQuery: null,
      reasons: []);
  @override
  Future<OcrMatchResult> match(String text,
      {required String sessionToken, int limit = 5}) async {
    calls++;
    token = sessionToken;
    if (fail) throw const OcrFailure(OcrFailureKind.network);
    return pending == null ? result : await pending!.future;
  }
}

CaptureServices testServices({FakeReader? reader, FakeMatcher? matcher}) =>
    CaptureServices(
        store: TestStore(),
        processor: TestProcessor(),
        newSource: TestSource.new,
        reader: reader ?? FakeReader(),
        matching: matcher ?? FakeMatcher());
PreparedMedicationImage testLease(
        {Future<Uint8List> Function()? read,
        Future<void> Function()? release,
        DateTime? expires}) =>
    PreparedMedicationImage(
        id: 'image',
        kind: PackagingKind.unspecified,
        width: 64,
        height: 48,
        createdAt: DateTime.now(),
        expiresAt: expires ?? DateTime.now().add(const Duration(hours: 1)),
        read: read ?? () async => Uint8List.fromList([1, 2, 3]),
        release: release ?? () async {});

void main() {
  test('one run, original OCR reused for matching retry, pinned token',
      () async {
    final reader = FakeReader(), matcher = FakeMatcher()..fail = true;
    final services = testServices(reader: reader, matcher: matcher);
    await services.bindSession('A');
    final controller = OcrController(image: testLease(), services: services);
    await Future.wait([controller.start(), controller.start()]);
    expect(controller.failure?.kind, OcrFailureKind.network);
    matcher.fail = false;
    await controller.start();
    expect(reader.calls, 1);
    expect(matcher.calls, 2);
    expect(matcher.token, 'A');
    expect(controller.stage, OcrStage.result);
    await controller.close();
    controller.dispose();
    services.dispose();
  });
  test('no text and too-long text never invoke matching', () async {
    for (final text in [' \n', '😀' * 2001]) {
      final reader = FakeReader()..text = text, matcher = FakeMatcher();
      final services = testServices(reader: reader, matcher: matcher);
      await services.bindSession('A');
      final c = OcrController(image: testLease(), services: services);
      await c.start();
      expect(c.stage, OcrStage.failure);
      expect(matcher.calls, 0);
      await c.close();
      c.dispose();
      services.dispose();
    }
  });
  test('cancel while decrypting prevents OCR and clears late bytes', () async {
    final read = Completer<Uint8List>(), entered = Completer<void>();
    final reader = FakeReader(), matcher = FakeMatcher();
    final services = testServices(reader: reader, matcher: matcher);
    await services.bindSession('A');
    var releases = 0;
    final c = OcrController(
        image: testLease(read: () {
          entered.complete();
          return read.future;
        }, release: () async {
          releases++;
        }),
        services: services);
    final running = c.start();
    await entered.future;
    await c.close();
    final bytes = Uint8List.fromList([1, 2, 3]);
    read.complete(bytes);
    await running;
    expect(bytes, everyElement(0));
    expect(reader.calls, 0);
    expect(matcher.calls, 0);
    expect(releases, 1);
    c.dispose();
    services.dispose();
  });
  test(
      'session switch during native recognition never sends OCR with account B',
      () async {
    final entered = Completer<void>();
    final reader = FakeReader()..pending = Completer<String>();
    final matcher = FakeMatcher();
    final services = testServices(reader: reader, matcher: matcher);
    await services.bindSession('A');
    final c = OcrController(image: testLease(), services: services);
    c.addListener(() {
      if (c.stage == OcrStage.recognizing && !entered.isCompleted) {
        entered.complete();
      }
    });
    final running = c.start();
    await entered.future;
    await services.bindSession('B');
    reader.pending!.complete('PRIVATE');
    await running;
    expect(matcher.calls, 0);
    expect(c.result, isNull);
    expect(c.stage, OcrStage.closed);
    c.dispose();
    services.dispose();
  });
  test('late HTTP result after close is ignored', () async {
    final matcher = FakeMatcher()..pending = Completer<OcrMatchResult>();
    final services = testServices(matcher: matcher);
    await services.bindSession('A');
    final entered = Completer<void>();
    final c = OcrController(image: testLease(), services: services);
    c.addListener(() {
      if (c.stage == OcrStage.matching && !entered.isCompleted) {
        entered.complete();
      }
    });
    final running = c.start();
    await entered.future;
    await c.close();
    matcher.pending!.complete(matcher.result);
    await running;
    expect(c.result, isNull);
    expect(c.stage, OcrStage.closed);
    c.dispose();
    services.dispose();
  });
  test(
      'cleanup failure is visible and queued for retry; expired image is not read',
      () async {
    var fail = true, reads = 0;
    final services = testServices();
    await services.bindSession('A');
    final c = OcrController(
        image: testLease(
            read: () async {
              reads++;
              return Uint8List(0);
            },
            expires: DateTime.now().subtract(const Duration(seconds: 1)),
            release: () async {
              if (fail) throw StateError('denied');
            }),
        services: services);
    await c.start();
    expect(reads, 0);
    expect(await c.close(), false);
    expect(services.cleanupError, isNotNull);
    fail = false;
    expect(await services.retryCleanup(), true);
    expect(services.cleanupError, isNull);
    c.dispose();
    services.dispose();
  });
}
