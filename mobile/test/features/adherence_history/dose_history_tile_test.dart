import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/app/theme/app_theme.dart';
import 'package:drugtime_mobile/features/adherence_history/domain/entities/adherence_history.dart';
import 'package:drugtime_mobile/features/adherence_history/presentation/widgets/dose_history_tile.dart';

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
}
