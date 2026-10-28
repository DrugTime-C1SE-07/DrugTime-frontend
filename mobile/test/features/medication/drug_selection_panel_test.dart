import 'dart:ui' show Tristate;

import 'package:drugtime_mobile/app/theme/app_theme.dart';
import 'package:drugtime_mobile/features/medication/data/models/drug_selection_demo_fixtures.dart';
import 'package:drugtime_mobile/features/medication/domain/entities/medication.dart';
import 'package:drugtime_mobile/features/medication/presentation/widgets/drug_selection_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const items = DrugSelectionDemoFixtures.candidates;
final confirm = find.widgetWithText(FilledButton, 'Xác nhận thuốc');
Finder candidate(int i) => find.byKey(ValueKey('drug-candidate-$i'));

Future<void> mount(WidgetTester tester,
        {List<DrugCatalogItem> candidates = items,
        ValueChanged<DrugCatalogItem>? onConfirm,
        VoidCallback? manual}) =>
    tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: DrugSelectionPanel(
          candidates: candidates,
          source: DrugSelectionSource.ocr,
          onConfirm: onConfirm ?? (_) {},
          onManualSearch: manual ?? () {},
        ),
      ),
    ));

void main() {
  testWidgets('order, identity, tap only selects; confirm returns latest once',
      (tester) async {
    final results = <DrugCatalogItem>[];
    await mount(tester, onConfirm: results.add);
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
    expect(tester.getTopLeft(candidate(0)).dy,
        lessThan(tester.getTopLeft(candidate(1)).dy));
    await tester.tap(candidate(0));
    await tester.pump();
    expect(results, isEmpty);
    expect(find.text('Hàm lượng: 500 mg'), findsOneWidget);
    await tester.ensureVisible(candidate(1));
    await tester.pumpAndSettle();
    await tester.tap(candidate(1));
    await tester.pump();
    final callback = tester.widget<FilledButton>(confirm).onPressed!;
    callback();
    callback();
    await tester.pump();
    expect(results, [same(items[1])]);
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
  });

  testWidgets('replacement, empty and same id changed metadata clear selection',
      (tester) async {
    final results = <DrugCatalogItem>[];
    await mount(tester, onConfirm: results.add);
    await tester.tap(candidate(0));
    await tester.pump();
    final changed = [
      DrugCatalogItem(
          id: items.first.id,
          name: items.first.name,
          activeIngredient: '',
          strength: 'Mới',
          dosageForm: '',
          unit: ''),
    ];
    await mount(tester, candidates: changed, onConfirm: results.add);
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
    expect(find.byKey(const ValueKey('drug-selection-review')), findsNothing);
    await tester.tap(candidate(0));
    await tester.pump();
    expect(find.text('Hàm lượng: Mới'), findsOneWidget);
    await mount(tester, candidates: const [], onConfirm: results.add);
    expect(confirm, findsNothing);
    expect(results, isEmpty);
  });

  testWidgets('missing fields are unknown without fabricated unit or strength',
      (tester) async {
    await mount(tester, candidates: DrugSelectionDemoFixtures.missing);
    await tester.tap(candidate(0));
    await tester.pump();
    for (final label in ['Hoạt chất', 'Hàm lượng', 'Dạng bào chế', 'Đơn vị']) {
      expect(find.text('$label: Chưa có thông tin'), findsOneWidget);
    }
    expect(find.textContaining('null'), findsNothing);
    expect(find.textContaining('500 mg'), findsNothing);
    expect(find.text('Đơn vị: viên'), findsNothing);
  });

  testWidgets('empty offers manual search and never confirms', (tester) async {
    var manual = 0;
    await mount(tester, candidates: const [], manual: () => manual++);
    expect(confirm, findsNothing);
    await tester.tap(find.text('Tìm kiếm thủ công'));
    expect(manual, 1);
  });

  for (final size in [const Size(320, 568), const Size(375, 812)]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('long list/name $size scale $scale scroll review and confirm',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final results = <DrugCatalogItem>[];
        await mount(tester,
            candidates: DrugSelectionDemoFixtures.longList,
            onConfirm: results.add);
        final lastName =
            find.text(DrugSelectionDemoFixtures.longList.last.name);
        await tester.scrollUntilVisible(lastName, 250,
            maxScrolls: 200, scrollable: find.byType(Scrollable).first);
        await tester.ensureVisible(lastName);
        await tester.pumpAndSettle();
        await tester.tap(lastName);
        await tester.pumpAndSettle();
        expect(
            find.text('Thông tin thuốc đã chọn').hitTestable(), findsOneWidget);
        expect(find.text('Hàm lượng: 500 mg'), findsOneWidget);
        await tester.tap(confirm);
        await tester.pump();
        expect(results.single, same(DrugSelectionDemoFixtures.longList.last));
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('semantics labels selected state and enabled confirm',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await mount(tester);
    await tester.tap(candidate(0));
    await tester.pumpAndSettle();
    await tester.ensureVisible(candidate(0));
    await tester.pumpAndSettle();
    final selected = tester.getSemantics(candidate(0));
    expect(selected.flagsCollection.isSelected, Tristate.isTrue);
    expect(selected.flagsCollection.isButton, isTrue);
    expect(tester.getSemantics(confirm).flagsCollection.isEnabled,
        Tristate.isTrue);
    semantics.dispose();
  });
}
