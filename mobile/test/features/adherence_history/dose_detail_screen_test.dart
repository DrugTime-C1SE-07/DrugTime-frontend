import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/features/adherence_history/domain/entities/adherence_history.dart';
import 'package:drugtime_mobile/features/adherence_history/presentation/screens/dose_detail_screen.dart';
import 'package:drugtime_mobile/features/adherence_history/presentation/state/adherence_history_controller.dart';
import 'package:drugtime_mobile/features/adherence_history/presentation/widgets/dose_history_tile.dart';
import 'package:drugtime_mobile/features/adherence_history/presentation/widgets/dose_timeline_rail.dart';
import 'package:drugtime_mobile/features/adherence_history/presentation/widgets/history_motion.dart';
import 'adherence_history_test_helpers.dart';

void main() {
  testWidgets(
      'DoseDetailScreen displays medication details and confirmation flow',
      (tester) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    bool confirmed = false;
    final scheduledAt = DateTime.utc(2026, 11, 20, 13, 0); // 20:00 VN
    final dose = HistoryDose(
      medicationId: 1,
      scheduleId: 1,
      medicationName: 'Losartan 50 mg',
      scheduledAt: scheduledAt,
      takenAt: null,
      status: HistoryDoseStatus.pending,
      statusSource: 'local',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DoseDetailScreen(
          dose: dose,
          asOf: scheduledAt.subtract(const Duration(hours: 2)),
          onConfirm: () => confirmed = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Title and Hero card
    expect(find.text('Chi tiết liều dùng'), findsOneWidget);
    expect(find.text('Losartan 50 mg'), findsOneWidget);
    expect(find.text('1 viên · Trước ăn tối'), findsOneWidget);
    expect(find.textContaining('Sắp tới · 20:00'), findsOneWidget);

    // Verify Info sections
    expect(find.text('THÔNG TIN LIỀU DÙNG'), findsOneWidget);
    expect(find.text('Giờ theo lịch'), findsOneWidget);
    expect(find.text('20:00'), findsOneWidget);
    expect(find.text('Hướng dẫn dùng'), findsOneWidget);
    expect(find.text('Trước ăn tối'), findsOneWidget);

    // Verify Notes and History
    expect(find.text('GHI CHÚ'), findsOneWidget);
    expect(find.text('Chưa có ghi chú cho liều này'), findsOneWidget);
    expect(find.text('LỊCH SỬ GẦN ĐÂY'), findsOneWidget);
    expect(find.text('Hôm qua · 20:00'), findsOneWidget);

    // Verify Bottom CTA
    expect(find.byKey(const Key('dose-confirm-button')), findsOneWidget);
    expect(find.text('✓ Xác nhận đã uống'), findsOneWidget);

    // Tap Confirm CTA
    await tester.tap(find.byKey(const Key('dose-confirm-button')));
    await tester.pumpAndSettle();

    expect(confirmed, isTrue);
    expect(find.text('Đã xác nhận uống'), findsOneWidget);
    expect(find.textContaining('Đã xác nhận uống liều Losartan 50 mg'),
        findsOneWidget);
  });

  testWidgets('tile flies into the detail card with a shared Hero tag (AC12)',
      (tester) async {
    await pumpHistory(tester, FakeHistoryRepository());
    final c = AdherenceHistoryScope.read(
        tester.element(find.byKey(const Key('history-title'))));
    await c.selectDay(DateTime.utc(2026, 10, 19));
    await tester.pumpAndSettle();
    final tile = find.byType(DoseHistoryTile).first;
    final dose = tester.widget<DoseHistoryTile>(tile).dose;
    final tag = DoseHeroTag(dose.scheduleId, dose.scheduledAt);
    final tileRect = tester.getRect(tile);

    await tester.tap(tile);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    // Mid-flight the card is drawn in the overlay between the tile and its final place.
    final flying = find.byWidgetPredicate((w) => w is Hero && w.tag == tag,
        skipOffstage: false);
    expect(flying, findsWidgets);
    await tester.pumpAndSettle();
    expect(find.text('Chi tiết liều dùng'), findsOneWidget);
    final detailHero = tester.widget<Hero>(find.byType(Hero).last);
    expect(detailHero.tag, tag);
    final route = ModalRoute.of(tester.element(find.byType(DoseDetailScreen)))!;
    expect(route, isA<HistoryPageRoute<void>>());
    expect((route as PageRoute).allowSnapshotting, isFalse);

    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    await tester.pumpAndSettle();
    expect(find.text('Chi tiết liều dùng'), findsNothing);
    expect(tester.getRect(find.byType(DoseHistoryTile).first), tileRect);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion opens the detail without a hero flight (AC12)',
      (tester) async {
    final c =
        await pumpHistory(tester, FakeHistoryRepository(), reducedMotion: true);
    await c.selectDay(DateTime.utc(2026, 10, 19));
    await tester.pump();
    await tester.tap(find.byType(DoseHistoryTile).first);
    await tester.pump();
    await tester.pump();
    expect(find.text('Chi tiết liều dùng'), findsOneWidget);
    expect(
        tester
            .widgetList<HeroMode>(find.byType(HeroMode, skipOffstage: false))
            .every((m) => !m.enabled),
        isTrue);
    expect(tester.takeException(), isNull);
  });
}
