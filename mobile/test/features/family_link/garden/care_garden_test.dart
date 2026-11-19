import 'package:drugtime_mobile/features/family_link/presentation/garden/care_garden.dart';
import 'package:drugtime_mobile/features/family_link/presentation/garden/garden_mood.dart';
import 'package:drugtime_mobile/shared/widgets/mascot/mascot_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _plants = [
  GardenPlant(
      id: 'mother', label: 'Chậu cây của Mẹ Hoa', shape: PlantShape.droop),
  GardenPlant(
      id: 'father', label: 'Chậu cây của Bố Minh', shape: PlantShape.bloom),
];

Future<CareGardenState> pumpGarden(WidgetTester tester,
    {GardenMood mood = GardenMood.ok,
    List<GardenPlant> plants = _plants,
    ValueChanged<String>? onPlantTap,
    DateTime Function()? now}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: ListView(children: [
        CareGarden(
            mood: mood, plants: plants, onPlantTap: onPlantTap, now: now),
        const SizedBox(height: 1200),
      ]),
    ),
  ));
  await tester.pump();
  return tester.state<CareGardenState>(find.byType(CareGarden));
}

void main() {
  testWidgets('dựng đủ 6 trạng thái, tư thế hai linh vật đúng bảng (AC15)',
      (tester) async {
    for (final mood in GardenMood.values) {
      final state = await pumpGarden(tester, mood: mood);
      final spec = gardenSpecs[mood]!;
      expect(state.left.mood, spec.left, reason: mood.name);
      expect(state.right.mood, spec.right, reason: mood.name);
      expect(find.bySemanticsLabel(spec.label), findsOneWidget,
          reason: mood.name);
      await tester.pump(const Duration(milliseconds: 300));
    }
  });

  testWidgets('đổi trạng thái thì hai linh vật đổi tư thế theo (AC15)',
      (tester) async {
    final state = await pumpGarden(tester, mood: GardenMood.missed);
    expect(state.right.mood, MascotMood.sleepy);
    await pumpGarden(tester, mood: GardenMood.nudged);
    expect(state.right.mood, MascotMood.poke);
    expect(state.left.mood, MascotMood.wave);
    await pumpGarden(tester, mood: GardenMood.recovered);
    expect(state.left.mood, MascotMood.celebrate);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('chạm một bạn: bạn đó phản ứng, bạn kia vẫy theo (AC17)',
      (tester) async {
    final state = await pumpGarden(tester);
    await tester.tap(find.byKey(const Key('garden-mascot-left')));
    await tester.pump(const Duration(milliseconds: 50));
    expect(state.left.mood, MascotMood.poke);
    expect(state.right.mood, MascotMood.wave);
    expect(state.gestures, 1);
    await tester.tap(find.byKey(const Key('garden-mascot-right')));
    await tester.pump(const Duration(milliseconds: 50));
    expect(state.right.mood, MascotMood.wave);
    expect(state.left.mood, MascotMood.wave);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('chạm liên tục: nhảy cùng nhau, có giới hạn tần suất (AC17)',
      (tester) async {
    var now = DateTime.utc(2026, 11, 20, 8);
    final state = await pumpGarden(tester, now: () => now);
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byKey(const Key('garden-mascot-left')));
      await tester.pump(const Duration(milliseconds: 50));
      now = now.add(const Duration(milliseconds: 300));
    }
    expect(state.left.mood, MascotMood.celebrate);
    expect(state.right.mood, MascotMood.celebrate);
    // trong thời gian chờ: chạm tiếp không nhảy lại
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byKey(const Key('garden-mascot-left')));
      await tester.pump(const Duration(milliseconds: 50));
      now = now.add(const Duration(milliseconds: 200));
    }
    expect(state.right.mood, MascotMood.wave);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('xoa đầu (kéo ngang ở phần đầu) → nhắm mắt cười (AC17)',
      (tester) async {
    final state = await pumpGarden(tester);
    final box = tester.getRect(find.byKey(const Key('garden-mascot-left')));
    await tester.dragFrom(
        box.topCenter + Offset(0, box.height * .2), const Offset(90, 0));
    await tester.pump(const Duration(milliseconds: 50));
    expect(state.left.mood, MascotMood.blissful);
    expect(state.right.mood, isNot(MascotMood.blissful));
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('kéo một bạn sang bạn kia rồi thả → ôm nhau, nảy về chỗ (AC17)',
      (tester) async {
    final state = await pumpGarden(tester);
    final start = tester.getRect(find.byKey(const Key('garden-mascot-left')));
    await tester.dragFrom(
        start.center + Offset(0, start.height * .25), const Offset(600, 0));
    await tester.pump(const Duration(milliseconds: 50));
    expect(state.left.mood, MascotMood.hug);
    expect(state.right.mood, MascotMood.hug);
    await tester.pump(const Duration(seconds: 2));
    expect(tester.getRect(find.byKey(const Key('garden-mascot-left'))).left,
        closeTo(start.left, 1));
  });

  testWidgets('kéo một đoạn ngắn rồi thả: không ôm', (tester) async {
    final state = await pumpGarden(tester);
    final start = tester.getRect(find.byKey(const Key('garden-mascot-right')));
    await tester.dragFrom(
        start.center + Offset(0, start.height * .25), const Offset(-60, 0));
    await tester.pump(const Duration(milliseconds: 50));
    expect(state.left.mood, isNot(MascotMood.hug));
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('chạm chậu cây: mở đúng người; nhãn và vùng chạm ≥ 48 (AC18)',
      (tester) async {
    final opened = <String>[];
    await pumpGarden(tester, onPlantTap: opened.add);
    final father = find.byKey(const Key('garden-plant-father'));
    expect(find.bySemanticsLabel('Chậu cây của Bố Minh'), findsOneWidget);
    final size = tester.getSize(father);
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
    await tester.tap(father);
    await tester.pump();
    expect(opened, ['father']);
    expect(find.bySemanticsLabel('Bạn thuốc xanh'), findsOneWidget);
    expect(find.bySemanticsLabel('Bạn thuốc cam'), findsOneWidget);
  });

  testWidgets(
      '4 chậu trên màn 360dp: mỗi chậu vẫn ≥ 48, cuộn ngang tới chậu cuối và mở đúng người (review M4)',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final opened = <String>[];
    await pumpGarden(tester,
        plants: [
          for (final id in ['a', 'b', 'c', 'd'])
            GardenPlant(id: id, label: 'Chậu $id', shape: PlantShape.bloom)
        ],
        onPlantTap: opened.add);
    expect(find.byKey(const Key('garden-plants-scroll')), findsOneWidget);
    for (final id in ['a', 'b', 'c', 'd']) {
      final size = tester.getSize(find.byKey(Key('garden-plant-$id')));
      expect(size.width, greaterThanOrEqualTo(48), reason: id);
      expect(size.height, greaterThanOrEqualTo(48), reason: id);
    }
    await tester.ensureVisible(find.byKey(const Key('garden-plant-d')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('garden-plant-d')));
    await tester.pump();
    expect(opened, ['d']);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('kéo bình tưới lên chậu: tưới cây, không mở màn nào (AC17)',
      (tester) async {
    final opened = <String>[];
    final state = await pumpGarden(tester, onPlantTap: opened.add);
    final can = tester.getCenter(find.byKey(const Key('garden-watering-can')));
    final pot = tester.getCenter(find.byKey(const Key('garden-plant-mother')));
    final gesture = await tester.startGesture(can);
    await tester.pump();
    for (var i = 1; i <= 10; i++) {
      await gesture.moveTo(Offset.lerp(can, pot, i / 10)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pump();
    expect(state.gestures, 1);
    expect(opened, isEmpty);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets(
      'mọi cử chỉ chỉ trang trí: chỉ chạm chậu mới gọi ra ngoài, dáng cây không đổi (AC17)',
      (tester) async {
    final opened = <String>[];
    final state = await pumpGarden(tester, onPlantTap: opened.add);
    await tester.tap(find.byKey(const Key('garden-mascot-left')));
    await tester.pump(const Duration(milliseconds: 50));
    final box = tester.getRect(find.byKey(const Key('garden-mascot-right')));
    await tester.dragFrom(
        box.topCenter + Offset(0, box.height * .2), const Offset(-90, 0));
    await tester.pump(const Duration(milliseconds: 50));
    expect(state.gestures, 2);
    expect(opened, isEmpty);
    final garden = tester.widget<CareGarden>(find.byType(CareGarden));
    expect(garden.plants.map((p) => p.shape),
        [PlantShape.droop, PlantShape.bloom]);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('vuốt dọc bắt đầu trên linh vật vẫn cuộn trang (AC18)',
      (tester) async {
    await pumpGarden(tester);
    final list = tester.state<ScrollableState>(find.byType(Scrollable).first);
    expect(list.position.pixels, 0);
    await tester.drag(
        find.byKey(const Key('garden-mascot-left')), const Offset(0, -200));
    await tester.pump();
    expect(list.position.pixels, greaterThan(100));
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('giảm chuyển động: không còn yêu cầu khung hình (AC16)',
      (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    for (final mood in GardenMood.values) {
      final state = await pumpGarden(tester, mood: mood);
      expect(state.left.mood, isNotNull);
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse, reason: mood.name);
    }
  });

  testWidgets('chưa theo dõi ai: có chậu đất trống, không có bình tưới',
      (tester) async {
    await pumpGarden(tester, mood: GardenMood.empty, plants: const []);
    expect(find.byKey(const Key('garden-watering-can')), findsNothing);
    expect(find.bySemanticsLabel(gardenSpecs[GardenMood.empty]!.label),
        findsOneWidget);
  });
}
