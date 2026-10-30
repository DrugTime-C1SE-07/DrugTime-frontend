import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/features/ocr_prototype/ocr_models.dart';
import 'package:drugtime_mobile/features/ocr_prototype/ocr_controller.dart';
import 'package:drugtime_mobile/features/ocr_prototype/ocr_store.dart';

const metadata = {
  'platform': 'Android',
  'deviceModel': 'test',
  'osVersion': '15',
  'appRevision': 'abc',
  'nativeSdkVersion': '16.0.1'
};

class FakeEngine implements OcrEngine {
  String text = 'Thuốc\nAmoxicillin 500 mg';
  bool fail = false;
  int calls = 0, closes = 0;
  Completer<String>? pending;
  @override
  Future<String> recognize(String path) async {
    calls++;
    if (fail) throw StateError('engine');
    return pending == null ? text : pending!.future;
  }

  @override
  Future<void> close() async {
    closes++;
  }
}

class FakePicker implements OcrImagePicker {
  String? selected = 'source.png', recovered;
  bool fail = false;
  @override
  Future<String?> pick() async {
    if (fail) throw StateError('picker');
    return selected;
  }

  @override
  Future<String?> recover() async => recovered;
}

class FakeStore implements OcrStore {
  final runs = <OcrRun>[];
  bool failSave = false, failImage = false;
  @override
  Future<String> prepareImage(String id, String source) async {
    if (failImage) throw StateError('input');
    return '$id/image.png';
  }

  @override
  Future<void> save(OcrRun run) async {
    if (failSave) throw StateError('disk');
    runs.add(run);
  }

  @override
  Future<List<OcrRun>> load() async => runs;
  @override
  Future<File> export(OcrRun run) async => File('${run.id}.json');
}

class FakeExporter implements OcrExporter {
  bool fail = false, shared = true;
  Rect? origin;
  @override
  Future<bool> share(File file, Rect origin) async {
    this.origin = origin;
    if (fail) throw StateError('share');
    return shared;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeEngine engine;
  late FakePicker picker;
  late FakeStore store;
  late OcrController controller;
  setUp(() {
    engine = FakeEngine();
    picker = FakePicker();
    store = FakeStore();
    var sequence = 0;
    controller = OcrController(
        engine: engine,
        picker: picker,
        store: store,
        rootPath: '.',
        validateImage: (_) async {},
        newId: () => 'run${++sequence}');
  });
  tearDown(() async {
    if (!controller.disposed) controller.dispose();
    await controller.closed;
  });
  test(
      'raw and metadata retained; repeated image creates distinct immutable runs',
      () async {
    await controller.pick();
    await controller.run('img01', metadata);
    expect(controller.result!.rawText, engine.text);
    expect(controller.result!.status, 'text');
    expect(controller.saved, true);
    expect(controller.result!.createdAt, endsWith('+07:00'));
    expect(controller.result!.metadata['modelVersion'], 'not_exposed');
    await controller.run('img01', metadata);
    expect(store.runs.map((r) => r.id), ['run1', 'run2']);
  });
  test('no_text, input_error and engine_error are distinct', () async {
    await controller.pick();
    engine.text = ' \n';
    await controller.run('a', metadata);
    expect(controller.result!.status, 'no_text');
    expect(controller.result!.rawText, ' \n');
    engine.fail = true;
    await controller.run('a', metadata);
    expect(controller.result!.status, 'engine_error');
    store.failImage = true;
    await controller.run('a', metadata);
    expect(controller.result!.status, 'input_error');
    expect(engine.calls, 2);
  });
  test('cancel does not create OCR run; picker failure allows retry', () async {
    picker.selected = null;
    await controller.pick();
    expect(controller.result, null);
    expect(store.runs, isEmpty);
    expect(engine.calls, 0);
    picker.fail = true;
    await controller.pick();
    expect(controller.busy, false);
    picker.fail = false;
    picker.selected = 'other.png';
    await controller.pick();
    expect(controller.image, 'other.png');
  });
  test('metadata required before engine call and recovery does not OCR',
      () async {
    picker.recovered = 'recovered.png';
    await controller.initialize();
    expect(controller.image, 'recovered.png');
    expect(engine.calls, 0);
    await controller.run('a', {});
    expect(engine.calls, 0);
  });
  test('save retry reuses result without recognizing twice', () async {
    await controller.pick();
    store.failSave = true;
    await controller.run('a', metadata);
    expect(controller.saved, false);
    final id = controller.result!.id;
    store.failSave = false;
    await controller.retrySave();
    expect(controller.saved, true);
    expect(controller.result!.id, id);
    expect(engine.calls, 1);
  });
  test(
      'double tap blocked, dispose waits for engine and never notifies closed screen',
      () async {
    await controller.pick();
    engine.pending = Completer<String>();
    var notifications = 0;
    controller.addListener(() => notifications++);
    final first = controller.run('a', metadata);
    await Future<void>.delayed(Duration.zero);
    await controller.run('b', metadata);
    await controller.pick();
    expect(engine.calls, 1);
    controller.dispose();
    final before = notifications;
    expect(engine.closes, 0);
    engine.pending!.complete('raw');
    await first;
    await controller.closed;
    expect(engine.closes, 1);
    expect(notifications, before);
    expect(store.runs.single.imageId, 'a');
  });
  test('export cancel and failure preserve saved result', () async {
    await controller.pick();
    await controller.run('a', metadata);
    final exporter = FakeExporter()..shared = false;
    await controller.export(
        controller.result!, exporter, const Rect.fromLTWH(1, 2, 30, 40));
    expect(controller.saved, true);
    expect(exporter.origin!.width, 30);
    exporter.fail = true;
    await controller.export(controller.result!, exporter, Rect.zero);
    expect(controller.saved, true);
    expect(store.runs, hasLength(1));
  });
  test('unsupported does not call picker or engine', () async {
    final other = OcrController(
        engine: engine,
        picker: picker,
        store: store,
        rootPath: '.',
        supported: false);
    await other.pick();
    await other.run('a', metadata);
    expect(other.image, null);
    expect(engine.calls, 0);
    other.dispose();
    await other.closed;
  });
  group('filesystem', () {
    late Directory temp;
    late FileOcrStore files;
    setUp(() async {
      temp = await Directory.systemTemp.createTemp('ocr_test_');
      files = FileOcrStore(temp);
    });
    tearDown(() async {
      await temp.delete(recursive: true);
    });
    OcrRun sample(String id) => OcrRun(
        id: id,
        imageId: 'a',
        createdAt: '2026-10-27T12:00:00+07:00',
        rawText: 'Thuốc\nĐúng dấu  \n',
        status: 'text',
        elapsedMs: 10,
        metadata: metadata);
    test('UTF-8 round trip, export and no overwrite', () async {
      final run = sample('one');
      await files.save(run);
      expect((await files.load()).single.encode(), run.encode());
      expect(await (await files.export(run)).readAsString(), run.encode());
      await expectLater(
          files.save(sample('one')), throwsA(isA<FileSystemException>()));
      expect((await files.load()).single.rawText, run.rawText);
      await files.save(sample('two'));
      expect(await files.load(), hasLength(2));
    });
    test('image bytes unchanged, duplicate and unsafe IDs rejected', () async {
      final source = File('${temp.path}/source.png');
      await source.writeAsBytes([1, 2, 3]);
      final relative = await files.prepareImage('one', source.path);
      expect(await File('${temp.path}/$relative').readAsBytes(), [1, 2, 3]);
      await expectLater(files.prepareImage('one', source.path),
          throwsA(isA<FileSystemException>()));
      await expectLater(files.save(sample('../unsafe')), throwsFormatException);
    });
    test('incomplete files ignored; corrupt JSON reported', () async {
      await File('${temp.path}/incomplete.tmp').writeAsString('{');
      expect(await files.load(), isEmpty);
      await File('${temp.path}/bad.json').writeAsString('{');
      await expectLater(files.load(), throwsFormatException);
    });
  });
}
