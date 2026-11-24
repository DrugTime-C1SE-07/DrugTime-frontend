import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/app/theme/app_theme.dart';
import 'package:drugtime_mobile/features/adherence_history/domain/entities/adherence_history.dart';
import 'package:drugtime_mobile/features/adherence_history/presentation/utils/adherence_history_format.dart';
import 'package:drugtime_mobile/features/adherence_history/presentation/utils/reminder_palette.dart';
import 'package:drugtime_mobile/features/adherence_history/presentation/widgets/dose_history_tile.dart';
import 'package:drugtime_mobile/features/adherence_history/presentation/widgets/dose_timeline_rail.dart';
import 'package:drugtime_mobile/features/adherence_history/presentation/widgets/history_motion.dart';

void main() {
  final pendingDose = HistoryDose(
    medicationId: 1,
    medicationName: 'Strepsils original',
    scheduleId: 2,
    scheduledAt: DateTime.utc(2026, 10, 19, 1),
    takenAt: null,
    status: HistoryDoseStatus.pending,
    statusSource: 'inferred',
  );

  testWidgets('local Home confirmation overrides upcoming label for one tile',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: DoseHistoryTile(
          dose: pendingDose,
          upcoming: true,
          locallyConfirmed: true,
        ),
      ),
    ));

    expect(find.text('Đã uống'), findsOneWidget);
    expect(find.text('Sắp tới'), findsNothing);
    expect(find.text('Uống bù'), findsNothing);
    expect(
      find.bySemanticsLabel(RegExp('Đã xác nhận tại Trang chủ')),
      findsOneWidget,
    );
  });

  testWidgets('backend missed renders a label without catch-up action',
      (tester) async {
    final missed = HistoryDose(
      medicationId: 1,
      medicationName: 'Efferalgan',
      scheduleId: 3,
      scheduledAt: DateTime.utc(2026, 10, 19, 1),
      takenAt: null,
      status: HistoryDoseStatus.missed,
      statusSource: 'recorded',
    );
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(body: DoseHistoryTile(dose: missed)),
    ));

    expect(find.text('Bỏ lỡ'), findsOneWidget);
    expect(find.text('Uống bù'), findsNothing);
  });

  testWidgets('prototype row shows known details without inventing directions',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: DoseHistoryTile(
          dose: pendingDose,
          prototypeStyle: true,
          details: '500 mg · 1 viên',
          upcoming: true,
        ),
      ),
    ));

    expect(find.text('Strepsils original'), findsOneWidget);
    expect(find.text('500 mg · 1 viên'), findsOneWidget);
    expect(find.text('08:00'), findsOneWidget);
    expect(find.text('Sắp tới'), findsOneWidget);
    expect(find.text('Uống bù'), findsNothing);
  });

  Widget dayTile(HistoryDose dose,
          {bool upcoming = false,
          bool confirmed = false,
          int? countdown,
          bool prototype = true,
          bool reduced = false,
          VoidCallback? onTap}) =>
      MaterialApp(
        theme: buildAppTheme(),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
            child: child!),
        home: HistoryMotionScope(
          child: Scaffold(
            body: DoseHistoryTile(
              dose: dose,
              upcoming: upcoming,
              locallyConfirmed: confirmed,
              prototypeStyle: prototype,
              countdownMinutes: countdown,
              onTap: onTap,
            ),
          ),
        ),
      );

  CustomPaint checkPaint(WidgetTester tester) =>
      tester.widget<CustomPaint>(find.byKey(const Key('drawn-check')));

  testWidgets('status change animates badge and draws the check once (AC8)',
      (tester) async {
    await tester.pumpWidget(dayTile(pendingDose, upcoming: true));
    expect(find.text('Sắp tới'), findsOneWidget);
    expect(find.byKey(const Key('drawn-check')), findsNothing);

    await tester
        .pumpWidget(dayTile(pendingDose, upcoming: true, confirmed: true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    // Mid-transition both labels are on screen, and the check is still being drawn.
    expect(find.text('Sắp tới'), findsOneWidget);
    expect(find.text('Đã uống'), findsOneWidget);
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    await tester.pumpAndSettle();
    expect(find.text('Sắp tới'), findsNothing);
    expect(find.text('Đã uống'), findsOneWidget);
    expect(find.byKey(const Key('drawn-check')), findsOneWidget);
    // Final colours stay those of the status table.
    final text = tester.widget<Text>(find.text('Đã uống'));
    expect(text.style?.color, ReminderPalette.success);
  });

  testWidgets('first build of a taken dose does not animate (AC8)',
      (tester) async {
    final taken = HistoryDose(
      medicationId: 1,
      medicationName: 'Strepsils original',
      scheduleId: 2,
      scheduledAt: DateTime.utc(2026, 10, 19, 1),
      takenAt: DateTime.utc(2026, 10, 19, 1, 5),
      status: HistoryDoseStatus.taken,
      statusSource: 'patient',
    );
    await tester.pumpWidget(dayTile(taken));
    expect(find.byKey(const Key('drawn-check')), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);
    expect(checkPaint(tester).painter, isNotNull);
  });

  testWidgets('pending dose is never shown as missed (QD-03)', (tester) async {
    await tester.pumpWidget(dayTile(pendingDose));
    await tester.pumpAndSettle();
    expect(find.text('Bỏ lỡ'), findsNothing);
    final label = tester.widget<Text>(
        find.text(HistoryFormat.status(HistoryDoseStatus.pending)));
    expect(label.style?.color, isNot(ReminderPalette.missed));
  });

  testWidgets('countdown shows "Còn N phút" and no confirm button (AC11)',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await tester
        .pumpWidget(dayTile(pendingDose, upcoming: true, countdown: 25));
    await tester.pumpAndSettle();
    expect(find.text('Còn 25 phút'), findsOneWidget);
    expect(find.text('Sắp tới'), findsNothing);
    expect(find.bySemanticsLabel(RegExp('còn 25 phút')), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.text('Đã uống'), findsNothing);
    semantics.dispose();
  });

  testWidgets(
      '"Theo thuốc" tile keeps its old look: no countdown, no Hero (AC9)',
      (tester) async {
    await tester.pumpWidget(dayTile(pendingDose,
        upcoming: true, countdown: 25, prototype: false, onTap: () {}));
    expect(find.text('Sắp tới'), findsOneWidget);
    expect(find.text('Còn 25 phút'), findsNothing);
    expect(find.byType(Hero), findsNothing);
    expect(find.byType(AnimatedSwitcher), findsNothing);
  });

  testWidgets(
      'day-tab tile carries the shared Hero tag; reduced motion disables it',
      (tester) async {
    await tester.pumpWidget(dayTile(pendingDose, onTap: () {}));
    final hero = tester.widget<Hero>(find.byType(Hero));
    expect(hero.tag, DoseHeroTag(2, DateTime.utc(2026, 10, 19, 1)));
    expect(tester.widget<HeroMode>(find.byType(HeroMode)).enabled, isTrue);
    await tester.pumpWidget(dayTile(pendingDose, onTap: () {}, reduced: true));
    expect(tester.widget<HeroMode>(find.byType(HeroMode)).enabled, isFalse);
  });
}
