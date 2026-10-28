import 'dart:io';

import 'package:drugtime_mobile/app/router.dart';
import 'package:drugtime_mobile/app/theme/app_theme.dart';
import 'package:drugtime_mobile/features/medication/data/models/drug_selection_demo_fixtures.dart';
import 'package:drugtime_mobile/features/medication/data/repositories/in_memory_medication_repository.dart';
import 'package:drugtime_mobile/features/medication/domain/entities/medication.dart';
import 'package:drugtime_mobile/features/medication/presentation/state/medication_controller.dart';
import 'package:drugtime_mobile/features/medication/presentation/screens/drug_selection_demo_screen.dart';
import 'package:drugtime_mobile/features/medication/presentation/screens/drug_selection_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Any unexpected transport fails the test. Demo deliberately has no save port.
class _NoNetwork extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      throw StateError('Demo must run offline');
}

class _SaveSpy extends InMemoryMedicationRepository {
  var saves = 0;

  @override
  Future<Medication> add(Medication draft, {required String clientUuid}) {
    saves++;
    throw StateError('Selection must not save a medication');
  }

  @override
  Future<List<DrugCatalogItem>> searchCatalog(String query) =>
      throw StateError('Demo must use its injected search');
}

void main() {
  for (final preview in [true, false]) {
    testWidgets('demo route requires preview and debug: preview=$preview',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(),
        onGenerateRoute: (settings) =>
            onGenerateRoute(settings, preview: preview),
        home: Builder(
            builder: (context) => TextButton(
                  onPressed: () => Navigator.of(context)
                      .pushNamed(AppRoutes.drugSelectionDemo),
                  child: const Text('Mở demo'),
                )),
      ));
      await tester.tap(find.text('Mở demo'));
      await tester.pumpAndSettle();
      expect(find.byType(DrugSelectionDemoScreen),
          preview && kDebugMode ? findsOneWidget : findsNothing);
      if (!preview) {
        expect(find.text('Bản xem thử không khả dụng'), findsOneWidget);
      }
    });
  }

  testWidgets('four presets run offline; manual search and result stay in demo',
      (tester) async {
    final previous = HttpOverrides.current;
    HttpOverrides.global = _NoNetwork();
    addTearDown(() => HttpOverrides.global = previous);
    final repository = _SaveSpy();
    final controller = MedicationController(repository);
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: MedicationScope(
          controller: controller, child: const DrugSelectionDemoScreen()),
    ));
    for (final preset in [
      'OCR · Có kết quả',
      'OCR · Không có kết quả',
      'Tìm kiếm · Có kết quả',
      'Tìm kiếm · Không có kết quả',
    ]) {
      await tester.ensureVisible(find.text(preset));
      await tester.tap(find.text(preset));
      await tester.pumpAndSettle();
      expect(find.byType(DrugSelectionScreen), findsOneWidget);
      if (preset.contains('Không')) {
        await tester.tap(find.text('Tìm kiếm thủ công').hitTestable());
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'nothing');
        await tester.pumpAndSettle();
        await tester.tap(find.text('Tìm kiếm thủ công').hitTestable());
        await tester.enterText(find.byType(TextField), 'Paracetamol');
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byKey(const ValueKey('drug-candidate-0')));
      await tester.pump();
      await tester.tap(find.text('Xác nhận thuốc'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Mẫu · Đã xác nhận:'), findsOneWidget);
      expect(find.textContaining('demo-500'), findsOneWidget);
      expect(find.byType(DrugSelectionScreen), findsNothing);
      expect(repository.saves, 0);
    }
    await tester.ensureVisible(find.text('Thiếu thông tin'));
    await tester.tap(find.text('Thiếu thông tin'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('drug-candidate-0')));
    await tester.pump();
    expect(find.text('Đơn vị: Chưa có thông tin'), findsOneWidget);
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('Chưa có lựa chọn được xác nhận'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(repository.saves, 0);
  });

  test('synthetic search returns fixture identity and unknown query is empty',
      () async {
    expect(await DrugSelectionDemoFixtures.search(' Paracetamol '),
        DrugSelectionDemoFixtures.candidates);
    expect(await DrugSelectionDemoFixtures.search('unknown'), isEmpty);
    expect(DrugSelectionDemoFixtures.missing.single.unit, isEmpty);
  });
}
