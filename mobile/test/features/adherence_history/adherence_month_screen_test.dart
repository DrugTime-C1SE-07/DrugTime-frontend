import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/features/adherence_history/presentation/widgets/reminder_scene_header.dart';
import 'package:drugtime_mobile/features/home/presentation/scene/living_banner.dart';
import 'adherence_history_test_helpers.dart';

void main() {
  testWidgets('month screen follows compact prototype summary and calendar',
      (tester) async {
    final controller = await pumpHistory(tester, FakeHistoryRepository());
    await tester.tap(find.byTooltip('Mở lịch tháng'));
    await tester.pumpAndSettle();

    expect(find.byType(ReminderSceneHeader), findsOneWidget);
    expect(find.text('Tháng 10, 2026'), findsOneWidget);
    expect(find.byKey(const Key('history-month-summary')), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(LivingBanner), findsNothing);
    expect(find.byKey(const Key('history-calendar-card')), findsOneWidget);
    expect(find.text('Đủ liều'), findsOneWidget);
    expect(find.text('Có bỏ lỡ'), findsOneWidget);
    expect(find.text('Hôm nay'), findsNWidgets(2));
    expect(find.textContaining('ngày liên tục'), findsNothing);

    final day = find.byKey(const ValueKey('history-day-19'));
    await tester.ensureVisible(day);
    expect(controller.selectedDay, DateTime.utc(2026, 10, 21));
    await tester.tap(day);
    await tester.pumpAndSettle();

    expect(controller.selectedDay, DateTime.utc(2026, 10, 19));
    expect(find.text('Thứ 2, 19/10/2026'), findsOneWidget);
    expect(find.text('2/4 liều đã uống'), findsOneWidget);
  });
}
