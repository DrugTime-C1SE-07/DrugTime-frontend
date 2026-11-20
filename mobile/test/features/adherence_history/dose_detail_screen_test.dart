import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/features/adherence_history/domain/entities/adherence_history.dart';
import 'package:drugtime_mobile/features/adherence_history/presentation/screens/dose_detail_screen.dart';

void main() {
  testWidgets('DoseDetailScreen displays medication details and confirmation flow', (tester) async {
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
    expect(find.textContaining('Đã xác nhận uống liều Losartan 50 mg'), findsOneWidget);
  });
}
