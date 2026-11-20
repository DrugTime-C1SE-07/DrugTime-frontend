import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/features/adherence_history/presentation/utils/reminder_palette.dart';
import 'package:drugtime_mobile/features/adherence_history/presentation/widgets/reminder_scene_header.dart';
import 'package:drugtime_mobile/features/home/presentation/scene/living_banner.dart';

void main() {
  testWidgets('day header follows compact Figma hierarchy and time tint',
      (tester) async {
    Future<Color?> headerAt(int hour) async {
      final now = DateTime.utc(2026, 11, 20, hour).subtract(
        const Duration(hours: 7),
      );
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              ReminderSceneHeader(
                title: 'Lịch nhắc',
                subtitle: 'Thứ Sáu, 20/11',
                now: now,
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 800)),
            ],
          ),
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Lịch nhắc'), findsOneWidget);
      expect(find.text('Thứ Sáu, 20/11'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      expect(find.byType(LivingBanner), findsNothing);
      return tester
          .widget<Material>(find.byKey(const Key('reminder-scene-header')))
          .color;
    }

    final morning = await headerAt(8);
    final evening = await headerAt(20);
    expect(morning, ReminderPalette.headerFor(DateTime.utc(2026, 11, 20, 1)));
    expect(morning, isNot(evening));
  });

  testWidgets('month header is a compact month toolbar', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CustomScrollView(
          slivers: [
            ReminderSceneHeader(
              title: 'Tháng 9, 2026',
              monthMode: true,
              leading: const Icon(Icons.chevron_left),
              trailing: const Icon(Icons.more_horiz),
            ),
          ],
        ),
      ),
    ));
    expect(find.text('Tháng 9, 2026'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(find.byType(LivingBanner), findsNothing);
  });
}
