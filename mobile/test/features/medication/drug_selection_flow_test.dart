import 'package:drugtime_mobile/app/theme/app_theme.dart';
import 'package:drugtime_mobile/features/medication/data/models/drug_selection_demo_fixtures.dart';
import 'package:drugtime_mobile/features/medication/domain/entities/medication.dart';
import 'package:drugtime_mobile/features/medication/presentation/screens/drug_selection_screen.dart';
import 'package:drugtime_mobile/features/medication/presentation/widgets/drug_catalog_sheet.dart';
import 'package:drugtime_mobile/features/medication/presentation/widgets/drug_selection_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final source in DrugSelectionSource.values) {
    Future<List<DrugCatalogItem?>> open(WidgetTester tester,
        {bool empty = false}) async {
      final results = <DrugCatalogItem?>[];
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(),
        home: Builder(
            builder: (context) => Scaffold(
                  body: TextButton(
                      onPressed: () async {
                        results.add(await showDrugSelectionScreen(
                          context,
                          candidates: empty
                              ? const []
                              : DrugSelectionDemoFixtures.candidates,
                          source: source,
                          search: DrugSelectionDemoFixtures.search,
                        ));
                      },
                      child: const Text('Mở')),
                )),
      ));
      await tester.tap(find.text('Mở'));
      await tester.pumpAndSettle();
      return results;
    }

    testWidgets('$source same panel, explicit confirm returns original item',
        (tester) async {
      final results = await open(tester);
      expect(find.byType(DrugSelectionPanel), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('drug-candidate-0')));
      await tester.pump();
      expect(results, isEmpty);
      await tester.tap(find.text('Xác nhận thuốc'));
      await tester.pumpAndSettle();
      expect(results, [same(DrugSelectionDemoFixtures.candidates.first)]);
    });

    for (final cancel in [true, false]) {
      testWidgets('$source ${cancel ? 'cancel' : 'system Back'} returns null',
          (tester) async {
        final results = await open(tester);
        await tester.tap(find.byKey(const ValueKey('drug-candidate-0')));
        await tester.pump();
        if (cancel) {
          await tester.tap(find.text('Hủy'));
        } else {
          await tester.binding.handlePopRoute();
        }
        await tester.pumpAndSettle();
        expect(results, [null]);
      });
    }

    testWidgets(
        '$source empty manual search confirm reaches original caller once',
        (tester) async {
      final results = await open(tester, empty: true);
      await tester.tap(find.text('Tìm kiếm thủ công'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Paracetamol');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('drug-candidate-1')));
      await tester.pump();
      expect(results, isEmpty);
      await tester.tap(find.text('Xác nhận thuốc'));
      await tester.pumpAndSettle();
      expect(results, [same(DrugSelectionDemoFixtures.candidates.last)]);
      expect(find.byType(DrugSelectionScreen), findsNothing);
      expect(find.byType(DrugCatalogSheet), findsNothing);
    });

    testWidgets(
        '$source repeated no-result focuses same field; cancel and retry',
        (tester) async {
      final results = await open(tester, empty: true);
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.text('Tìm kiếm thủ công').hitTestable());
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'no-match');
        await tester.pumpAndSettle();
        await tester.tap(find.text('Tìm kiếm thủ công').hitTestable());
        await tester.pumpAndSettle();
        expect(find.byType(DrugCatalogSheet), findsOneWidget);
        final field = tester.widget<TextField>(find.byType(TextField));
        expect(field.focusNode!.hasFocus, isTrue);
        expect(field.controller!.selection,
            const TextSelection(baseOffset: 0, extentOffset: 8));
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(DrugSelectionScreen), findsOneWidget);
        expect(results, isEmpty);
      }
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(results, [null]);
    });
  }

  testWidgets('disposing host while manual search open never pops caller',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: DrugSelectionScreen(
      candidates: [],
      source: DrugSelectionSource.ocr,
      search: DrugSelectionDemoFixtures.search,
    )));
    await tester.tap(find.text('Tìm kiếm thủ công'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const MaterialApp(home: Text('Caller mới')));
    await tester.pumpAndSettle();
    expect(find.text('Caller mới'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
