import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/core/utils/app_assets.dart';
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

  Widget dayHeader({String mascot = AppAssets.mascotHappy, double scale = 1}) =>
      MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!),
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              ReminderSceneHeader(
                title: 'Lịch nhắc',
                subtitle: 'Thứ Sáu, 20/11',
                now: DateTime.utc(2026, 11, 20, 1),
                mascot: mascot,
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  for (var i = 0; i < 3; i++)
                    IconButton(onPressed: () {}, icon: const Icon(Icons.add)),
                ]),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 1600)),
            ],
          ),
        ),
      );

  testWidgets('title font size interpolates continuously 24→18 (AC13)',
      (tester) async {
    await tester.pumpWidget(dayHeader());
    final scrollable = find.byType(Scrollable);
    double size() => tester
        .widget<Text>(find.byKey(const Key('history-title')))
        .style!
        .fontSize!;
    expect(size(), 24);
    var previous = size();
    for (var offset = 2.0; offset <= 42; offset += 2) {
      final position = tester.state<ScrollableState>(scrollable).position;
      position.jumpTo(offset);
      await tester.pump();
      final current = size();
      expect(previous - current, lessThan(1),
          reason: 'jump at shrinkOffset $offset');
      expect(current, lessThanOrEqualTo(previous));
      previous = current;
    }
    expect(previous, closeTo(18, .01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('no overflow at text scale 2 on a narrow screen (AC17)',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(dayHeader(scale: 2));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Lịch nhắc'), findsOneWidget);
  });

  testWidgets('mascot cross-fades on mood change with stable label (AC14)',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(dayHeader(mascot: AppAssets.mascotHello));
    await tester.pumpAndSettle();
    Iterable<String> assets() => tester
        .widgetList<Image>(find.byType(Image))
        .map((i) => (i.image as AssetImage).assetName);
    expect(assets(), [AppAssets.mascotHello]);
    await tester.pumpWidget(dayHeader(mascot: AppAssets.mascotThinking));
    await tester.pump(const Duration(milliseconds: 100));
    expect(assets(),
        containsAll([AppAssets.mascotHello, AppAssets.mascotThinking]));
    await tester.pumpAndSettle();
    expect(assets(), [AppAssets.mascotThinking]);
    expect(find.bySemanticsLabel('Dumi, linh vật DrugTime'), findsOneWidget);
    semantics.dispose();
  });
}
