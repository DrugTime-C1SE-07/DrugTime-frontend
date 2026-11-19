import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/app/adherence_demo_app.dart';
import 'package:drugtime_mobile/features/adherence_history/presentation/state/adherence_history_controller.dart';
import 'package:drugtime_mobile/features/adherence_history/presentation/widgets/dose_history_tile.dart';
import 'package:drugtime_mobile/features/adherence_history/domain/entities/adherence_demo_preset.dart';
import 'adherence_history_test_helpers.dart';

void main() {
  for (final size in [
    const Size(320, 1000),
    const Size(375, 1000),
    const Size(430, 1000),
    const Size(812, 375)
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
          'demo $size text $scale keeps toolbar, dates and long content usable',
          (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await tester.pumpWidget(AdherenceDemoApp(
              now: DateTime.utc(2026, 10, 22),
              preset: AdherenceDemoPreset.longList));
          await tester.pumpAndSettle();
          expect(find.text('Mẫu'), findsOneWidget);
          expect(find.byKey(const Key('demo-preset-picker')), findsNothing);
          final lastDose = find.byWidgetPredicate(
              (w) => w is DoseHistoryTile && w.dose.scheduleId == 2023);
          final vertical = find
              .descendant(
                  of: find.byType(ListView).first,
                  matching: find.byType(Scrollable))
              .first;
          await tester.scrollUntilVisible(lastDose, 500,
              scrollable: vertical, maxScrolls: 100);
          await tester.ensureVisible(lastDose);
          await tester.pumpAndSettle();
          expect(tester.getRect(lastDose).overlaps(Offset.zero & size), isTrue);
          expect(tester.takeException(), isNull);
          await openHistoryMonth(tester);
          final day = find.byKey(const ValueKey('history-day-22'));
          await tester.scrollUntilVisible(day, 300,
              scrollable: find
                  .descendant(
                      of: find.byType(ListView).first,
                      matching: find.byType(Scrollable))
                  .first);
          expect(tester.getSize(day).width, greaterThanOrEqualTo(48));
          expect(tester.getSize(day).height, greaterThanOrEqualTo(48));
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          await openMedicationHistory(tester);
          final arrow = find.byKey(const ValueKey('history-expand-7'));
          await tester.scrollUntilVisible(arrow, 300,
              scrollable: find
                  .descendant(
                      of: find.byType(ListView).first,
                      matching: find.byType(Scrollable))
                  .first);
          await tester.ensureVisible(arrow);
          await tester.pumpAndSettle();
          await tester.tap(arrow);
          await tester.pumpAndSettle();
          final c = AdherenceHistoryScope.read(tester.element(arrow));
          expect(c.expanded(7), isTrue);
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      });
    }
  }
}
