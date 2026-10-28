import 'dart:async';
import 'dart:ui' show Tristate;
import 'package:drugtime_mobile/features/medication/data/repositories/in_memory_medication_repository.dart';
import 'package:drugtime_mobile/features/medication/domain/entities/medication.dart';
import 'package:drugtime_mobile/features/medication/domain/entities/medication_failure.dart';
import 'package:drugtime_mobile/features/medication/presentation/state/medication_controller.dart';
import 'package:drugtime_mobile/features/medication/presentation/widgets/drug_catalog_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class SearchRepository extends InMemoryMedicationRepository {
  final queries = <String>[];
  final pending = <Completer<List<DrugCatalogItem>>>[];
  @override
  Future<List<DrugCatalogItem>> searchCatalog(String query) {
    queries.add(query);
    final request = Completer<List<DrugCatalogItem>>();
    pending.add(request);
    return request.future;
  }
}

DrugCatalogItem drug(String id, {String? name, bool missing = false}) =>
    DrugCatalogItem(
      id: id,
      name: name ?? id,
      activeIngredient: missing ? '' : 'Hoạt chất',
      strength: missing ? '' : '5 mg',
      dosageForm: missing ? '' : 'Viên nén',
    );
Future<SearchRepository> mount(WidgetTester tester) async {
  final repo = SearchRepository();
  final controller = MedicationController(repo);
  addTearDown(controller.dispose);
  await tester.pumpWidget(MaterialApp(
      home: MedicationScope(
    controller: controller,
    child: const Scaffold(body: DrugCatalogSheet()),
  )));
  await tester.pump();
  return repo;
}

Future<void> search(WidgetTester tester, String q) async {
  await tester.enterText(find.byType(TextField), q);
  await tester.pump(catalogSearchDebounce);
}

void main() {
  testWidgets('empty whitespace, debounce 299/300ms and trimmed final query',
      (tester) async {
    final repo = await mount(tester);
    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump(const Duration(milliseconds: 400));
    expect(repo.queries, isEmpty);
    await tester.enterText(find.byType(TextField), ' A ');
    await tester.pump(const Duration(milliseconds: 299));
    expect(repo.queries, isEmpty);
    await tester.enterText(find.byType(TextField), ' B ');
    await tester.pump(const Duration(milliseconds: 299));
    expect(repo.queries, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    expect(repo.queries, ['B']);
    repo.pending.single.complete([drug('second'), drug('first')]);
    await tester.pump();
    expect(tester.getTopLeft(find.text('second')).dy,
        lessThan(tester.getTopLeft(find.text('first')).dy));
    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    expect(find.text('second'), findsNothing);
  });
  testWidgets(
      'A B A: only current generation can update, including stale error',
      (tester) async {
    final repo = await mount(tester);
    await search(tester, 'A');
    await search(tester, 'B');
    await search(tester, 'A');
    repo.pending[2].complete([drug('latest')]);
    await tester.pump();
    repo.pending[0].complete([drug('stale')]);
    repo.pending[1]
        .completeError(const MedicationFailure(MedicationFailureKind.network));
    await tester.pump();
    expect(find.text('latest'), findsOneWidget);
    expect(find.text('stale'), findsNothing);
    expect(find.text('Chưa tìm được'), findsNothing);
  });
  testWidgets(
      'clear invalidates request and dispose cancels timer or ignores response',
      (tester) async {
    final repo = await mount(tester);
    await search(tester, 'A');
    await tester.enterText(find.byType(TextField), '');
    repo.pending[0].complete([drug('stale')]);
    await tester.pump();
    expect(find.text('stale'), findsNothing);
    await search(tester, 'B');
    await tester.enterText(find.byType(TextField), 'C');
    await tester.pumpWidget(const SizedBox());
    repo.pending[1]
        .completeError(const MedicationFailure(MedicationFailureKind.network));
    await tester.pump(const Duration(seconds: 1));
    expect(repo.queries, ['A', 'B']);
    expect(tester.takeException(), isNull);
  });
  for (final symbol in ['á', '😀']) {
    testWidgets('trimmed Unicode limit 100 allowed, 101 blocked: $symbol',
        (tester) async {
      final repo = await mount(tester);
      await search(tester, symbol * 99);
      expect(repo.queries, [symbol * 99]);
      repo.pending[0].complete([]);
      await tester.pump();
      await search(tester, ' ${symbol * 100} ');
      expect(repo.queries, [symbol * 99, symbol * 100]);
      await search(tester, symbol * 101);
      expect(repo.queries, hasLength(2));
      repo.pending[1].complete([drug('stale')]);
      await tester.pump();
      expect(find.text('stale'), findsNothing);
      expect(
          find.text(
              'Nhập tối đa 100 ký tự sau khi bỏ khoảng trắng đầu và cuối.'),
          findsOneWidget);
      await search(tester, 'valid');
      repo.pending[2].complete([]);
      await tester.pump();
      expect(find.text('Không tìm thấy thuốc phù hợp'), findsOneWidget);
    });
  }
  testWidgets('network retry uses current query once and clears old error',
      (tester) async {
    final repo = await mount(tester);
    await search(tester, ' A ');
    repo.pending[0]
        .completeError(const MedicationFailure(MedicationFailureKind.network));
    await tester.pump();
    expect(find.text('Chưa tìm được'), findsOneWidget);
    final retry = tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'Thử lại'))
        .onPressed!;
    retry();
    retry();
    await tester.pump();
    expect(repo.queries, ['A', 'A']);
    expect(find.text('Chưa tìm được'), findsNothing);
    repo.pending[1].complete([drug('latest')]);
    await tester.pump();
    expect(find.text('latest'), findsOneWidget);
    await search(tester, 'B');
    repo.pending[2]
        .completeError(const MedicationFailure(MedicationFailureKind.network));
    await tester.pump();
    await search(tester, 'C');
    expect(find.text('Chưa tìm được'), findsNothing);
    repo.pending[3].complete([]);
    await tester.pump();
    expect(find.text('Không tìm thấy thuốc phù hợp'), findsOneWidget);
  });

  for (final kind in [
    MedicationFailureKind.validation,
    MedicationFailureKind.unauthorized
  ]) {
    testWidgets('failure $kind is not empty success', (tester) async {
      final repo = await mount(tester);
      await search(tester, 'A');
      repo.pending[0].completeError(MedicationFailure(kind));
      await tester.pump();
      expect(find.text('Chưa tìm được'), findsOneWidget);
      expect(find.text('Không tìm thấy thuốc phù hợp'), findsNothing);
      expect(
          find.text('Thử lại'),
          kind == MedicationFailureKind.unauthorized
              ? findsNothing
              : findsOneWidget);
    });
  }

  testWidgets(
      'strength, missing fields and same name distinct ids keep original item',
      (tester) async {
    final repo = await mount(tester);
    await search(tester, 'A');
    repo.pending[0].complete([
      drug('1', name: 'Cùng tên'),
      drug('2', name: 'Cùng tên', missing: true)
    ]);
    await tester.pump();
    expect(find.text('Cùng tên'), findsNWidgets(2));
    expect(find.text('5 mg'), findsOneWidget);
    expect(find.textContaining('null'), findsNothing);
    expect(find.text('Chưa có thông tin hoạt chất'), findsOneWidget);
  });

  testWidgets(
      'query change removes selection immediately; stale response cannot restore it',
      (tester) async {
    final repo = await mount(tester);
    await search(tester, 'A');
    repo.pending[0].complete([drug('current')]);
    await tester.pump();
    await tester.tap(find.text('current'));
    await tester.pumpAndSettle();
    final confirm = find.widgetWithText(FilledButton, 'Xác nhận thuốc');
    expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
    await tester.enterText(find.byType(TextField), 'B');
    await tester.pump();
    expect(confirm, findsNothing);
    await tester.pump(catalogSearchDebounce);
    await search(tester, 'A');
    repo.pending[2].complete([drug('new-current')]);
    await tester.pump();
    repo.pending[1].complete([drug('stale')]);
    await tester.pump();
    expect(find.text('stale'), findsNothing);
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
    expect(find.byKey(const ValueKey('drug-selection-review')), findsNothing);
  });

  testWidgets('empty action focuses and selects current query on same route',
      (tester) async {
    final repo = await mount(tester);
    await search(tester, 'unknown');
    repo.pending.single.complete([]);
    await tester.pump();
    await tester.tap(find.text('Tìm kiếm thủ công'));
    await tester.pump();
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.focusNode!.hasFocus, isTrue);
    expect(field.controller!.selection,
        const TextSelection(baseOffset: 0, extentOffset: 7));
    expect(find.byType(DrugCatalogSheet), findsOneWidget);
  });

  for (final size in [const Size(320, 568), const Size(375, 812)]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('keyboard selection and semantics $size text $scale',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.view.viewInsets = const FakeViewPadding(bottom: 220);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final semantics = tester.ensureSemantics();
        final repo = await mount(tester);
        await search(tester, 'long');
        repo.pending.single.complete([
          drug('long-name', name: 'Tên thuốc dài để thử khả năng cuộn và đọc'),
        ]);
        await tester.pump();
        final name = find.text('Tên thuốc dài để thử khả năng cuộn và đọc');
        await tester.scrollUntilVisible(name, 80,
            scrollable: find.byType(Scrollable).last);
        await tester.ensureVisible(name);
        await tester.pumpAndSettle();
        await tester.tapAt(tester.getTopLeft(name) + const Offset(10, 10));
        await tester.pumpAndSettle();
        final confirm = find.widgetWithText(FilledButton, 'Xác nhận thuốc');
        expect(confirm.hitTestable(), findsOneWidget);
        expect(tester.getSemantics(confirm).flagsCollection.isEnabled,
            Tristate.isTrue);
        expect(tester.takeException(), isNull);
        semantics.dispose();
      });
    }
  }

  testWidgets('modal host places query and confirm above the keyboard',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 220);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    DrugCatalogItem? result;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
      builder: (context) => Scaffold(
          body: TextButton(
              onPressed: () async {
                result = await showDrugCatalogSheet(context,
                    search: (_) async => [drug('modal-item')],
                    isInUse: (_) => false);
              },
              child: const Text('Mở'))),
    )));
    await tester.tap(find.text('Mở'));
    await tester.pumpAndSettle();
    expect(tester.getBottomRight(find.byType(TextField)).dy,
        lessThanOrEqualTo(348));
    await tester.enterText(find.byType(TextField), 'modal');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('modal-item'), 80,
        scrollable: find.byType(Scrollable).last);
    await tester.ensureVisible(find.text('modal-item'));
    await tester.pumpAndSettle();
    await tester.tapAt(
        tester.getTopLeft(find.text('modal-item')) + const Offset(10, 10));
    await tester.pumpAndSettle();
    final confirm = find.widgetWithText(FilledButton, 'Xác nhận thuốc');
    expect(tester.getBottomRight(confirm).dy, lessThanOrEqualTo(348));
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(result!.id, 'modal-item');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'small screen large text with keyboard: states scroll and retry remains reachable',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 250);
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final repo = await mount(tester);
    expect(tester.takeException(), isNull);
    await search(tester, 'A');
    repo.pending[0]
        .completeError(const MedicationFailure(MedicationFailureKind.network));
    await tester.pump();
    await tester.ensureVisible(find.text('Thử lại'));
    await tester.tap(find.text('Thử lại'));
    await tester.pump();
    expect(repo.queries, ['A', 'A']);
    repo.pending[1].complete([]);
    await tester.pump();
    expect(tester.takeException(), isNull);
    await search(tester, 'B');
    repo.pending[2].complete([drug('result')]);
    await tester.pump();
    await tester.scrollUntilVisible(find.text('result'), 80,
        scrollable: find.byType(Scrollable).last);
    expect(tester.takeException(), isNull);
  });
}
