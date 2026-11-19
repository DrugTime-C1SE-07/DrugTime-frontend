import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/features/adherence_history/presentation/widgets/dose_history_tile.dart';
import 'adherence_history_test_helpers.dart';

void main() {
  for (final width in [320.0, 375.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
          '$width dp, text $scale, long cards, week/month/menu are accessible',
          (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          final repo = FakeHistoryRepository()
            ..medicationName =
                'Metformin 500 mg giải phóng kéo dài, tên thuốc kiểm thử có dấu tiếng Việt';
          final c = await pumpHistory(tester, repo,
              width: width,
              height: 932,
              scale: scale,
              reducedMotion: true,
              safeInsets: const EdgeInsets.only(top: 24, bottom: 16));
          await c.selectDay(DateTime.utc(2026, 10, 19));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final week = find.byKey(const ValueKey('history-week-19'));
          expect(tester.getSize(week).width, greaterThanOrEqualTo(48));
          expect(tester.getSize(week).height, greaterThanOrEqualTo(48));
          final selected = tester.getSemantics(
              find.bySemanticsLabel(RegExp('^Thứ 2, 19/10/2026')));
          expect(selected.flagsCollection.isSelected, ui.Tristate.isTrue);
          expect(MediaQuery.of(tester.element(week)).disableAnimations, isTrue);
          await tester.scrollUntilVisible(find.text('Chờ'), 300,
              scrollable: find.byType(Scrollable).first);
          await tester.ensureVisible(find.text('Chờ'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(tester.getBottomRight(find.text('Chờ')).dy,
              lessThanOrEqualTo(932 - 16));
          final status = tester.getSemantics(
              find.bySemanticsLabel(RegExp('Đang chờ xác nhận, giờ dự kiến')));
          expect(status.flagsCollection.isButton, isFalse);
          await tester.drag(find.byType(ListView).first, const Offset(0, 5000));
          await tester.pumpAndSettle();
          await openHistoryMonth(tester);
          final day = find.byKey(const ValueKey('history-day-19'));
          expect(tester.getSize(day).width, greaterThanOrEqualTo(48));
          expect(tester.getSize(day).height, greaterThanOrEqualTo(48));
          expect(tester.takeException(), isNull);
          final cta = find.byKey(const Key('history-view-day'));
          await tester.scrollUntilVisible(cta, 300,
              scrollable: find.byType(Scrollable).first);
          await tester.pumpAndSettle();
          await tester.tap(cta);
          await tester.pumpAndSettle();
          await openMedicationHistory(tester);
          final group = find.byKey(const ValueKey('history-medication-7'));
          final arrow = find.byKey(const ValueKey('history-expand-7'));
          await tester.scrollUntilVisible(arrow, 300,
              scrollable: find.byType(Scrollable).first);
          expect(tester.getSize(group).width, greaterThanOrEqualTo(48));
          await tester.tap(arrow);
          await tester.pumpAndSettle();
          expect(c.expanded(7), isTrue);
          expect(tester.takeException(), isNull);
          expect(find.byType(DoseHistoryTile), findsWidgets);
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(c.selectedDay, DateTime.utc(2026, 10, 19));
        } finally {
          semantics.dispose();
        }
      });
    }
  }

  testWidgets('landscape day and month remain scrollable without overflow',
      (tester) async {
    final c = await pumpHistory(tester, FakeHistoryRepository(),
        width: 812, height: 375);
    await c.selectDay(DateTime.utc(2026, 10, 19));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await openHistoryMonth(tester);
    final cta = find.byKey(const Key('history-view-day'));
    await tester.scrollUntilVisible(cta, 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(cta);
    await tester.pumpAndSettle();
    expect(c.selectedDay, DateTime.utc(2026, 10, 19));
  });
}
