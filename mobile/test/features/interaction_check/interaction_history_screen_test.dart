import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/features/interaction_check/presentation/screens/interaction_history_screen.dart';

void main() {
  testWidgets('InteractionHistoryScreen displays summary, filters and opens detail sheet', (tester) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    bool rechecked = false;

    await tester.pumpWidget(
      MaterialApp(
        home: InteractionHistoryScreen(
          onRecheck: () => rechecked = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Title and Summary Banner
    expect(find.text('Lịch sử kiểm tra'), findsOneWidget);
    expect(find.text('Lần kiểm tra'), findsOneWidget);
    expect(find.text('Cặp cần theo dõi'), findsOneWidget);

    // Verify Filter Chips
    expect(find.widgetWithText(ChoiceChip, 'Tất cả (4)'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Cần theo dõi (3)'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'An toàn (1)'), findsOneWidget);

    // Verify Monthly group and items
    expect(find.text('THÁNG 11, 2026'), findsOneWidget);
    expect(find.text('Paracetamol ⇄ Warfarin'), findsOneWidget);

    // Filter by "An toàn"
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'An toàn (1)'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'An toàn (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Không phát hiện tương tác nguy cơ'), findsOneWidget);
    expect(find.text('Paracetamol ⇄ Warfarin'), findsNothing);

    // Filter back to "Tất cả"
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Tất cả (4)'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Tất cả (4)'));
    await tester.pumpAndSettle();

    // Tap on card to open S06e-1 Detail Modal Sheet
    await tester.tap(find.text('Paracetamol ⇄ Warfarin'));
    await tester.pumpAndSettle();

    // Detail sheet content
    expect(find.text('Chi tiết lần kiểm tra'), findsOneWidget);
    expect(find.text('Mức độ 3'), findsOneWidget);
    expect(find.textContaining('Nguy cơ xuất huyết cao khi phối hợp'), findsOneWidget);
    expect(find.text('BẠN ĐÃ LÀM GÌ?'), findsOneWidget);
    expect(find.text('Đã hỏi ý kiến bác sĩ'), findsOneWidget);
    expect(find.text('DANH SÁCH THUỐC TRONG LẦN KIỂM TRA'), findsOneWidget);
    expect(find.text('Metformin 500mg'), findsOneWidget);

    // Close detail sheet
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    // Tap Bottom Recheck CTA
    await tester.tap(find.byKey(const Key('interaction-recheck-button')));
    await tester.pump();
    expect(rechecked, isTrue);
  });
}
