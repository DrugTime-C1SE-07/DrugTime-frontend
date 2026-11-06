import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/features/medication_capture/domain/ocr_models.dart';
import 'ocr_controller_test.dart' show testServices, testLease;
import 'capture_controller_test.dart' show TestStore, TestProcessor, TestSource;
import 'package:drugtime_mobile/features/medication_capture/data/capture_services.dart';

class _FailingStore extends TestStore {
  bool fail = true;
  @override
  Future<void> clear() async {
    if (fail) throw StateError('test storage error');
    await super.clear();
  }
}

void main() {
  test(
      'store cleanup failure is retained across successful lease release and can retry',
      () async {
    final store = _FailingStore();
    final services = CaptureServices(
        store: store, processor: TestProcessor(), newSource: TestSource.new);
    await services.invalidate();
    expect(services.cleanupError, isNotNull);
    expect(await services.release(testLease()), true);
    expect(services.cleanupError, isNotNull);
    expect(await services.retryCleanup(), false);
    store.fail = false;
    expect(await services.retryCleanup(), true);
    expect(services.cleanupError, isNull);
    services.dispose();
  });
  test(
      'one active and one latest pending OCR; replaced job never allocates pixels',
      () async {
    final services = testServices();
    final gate = Completer<String>(), entered = Completer<void>();
    var replacedCalls = 0, latestCalls = 0;
    final first = services.runOcr(() {
      entered.complete();
      return gate.future;
    }, () => true);
    await entered.future;
    final replaced = services.runOcr(() async {
      replacedCalls++;
      return 'old';
    }, () => true);
    final assertion = expectLater(replaced, throwsA(isA<OcrFailure>()));
    final latest = services.runOcr(() async {
      latestCalls++;
      return 'new';
    }, () => true);
    gate.complete('first');
    expect(await first, 'first');
    await assertion;
    expect(await latest, 'new');
    expect(replacedCalls, 0);
    expect(latestCalls, 1);
    services.dispose();
  });
  test('session epoch changes synchronously before cleanup finishes', () async {
    final services = testServices();
    await services.bindSession('A');
    final epoch = services.epoch;
    final pending = services.bindSession('B');
    expect(services.sameSession(epoch, 'A'), false);
    expect(services.sessionToken, 'B');
    await pending;
    services.dispose();
  });
  test('stale queued job never starts', () async {
    final services = testServices();
    var calls = 0;
    await expectLater(
        services.runOcr(() async {
          calls++;
          return '';
        }, () => false),
        throwsA(isA<OcrFailure>()));
    expect(calls, 0);
    services.dispose();
  });
}
