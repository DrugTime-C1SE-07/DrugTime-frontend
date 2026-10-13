import 'dart:async';
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
      await search(tester, ' ${symbol * 100} ');
      expect(repo.queries, [symbol * 100]);
      await search(tester, symbol * 101);
      expect(repo.queries, hasLength(1));
      repo.pending[0].complete([drug('stale')]);
      await tester.pump();
      expect(find.text('stale'), findsNothing);
      expect(
          find.text(
              'Nhập tối đa 100 ký tự sau khi bỏ khoảng trắng đầu và cuối.'),
          findsOneWidget);
      await search(tester, 'valid');
      repo.pending[1].complete([]);
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
    await tester.ensureVisible(find.text('result'));
    expect(tester.takeException(), isNull);
  });
}
