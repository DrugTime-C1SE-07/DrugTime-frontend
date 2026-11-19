import 'package:drugtime_mobile/features/home/presentation/scene/home_pet_signals.dart';
import 'package:drugtime_mobile/features/home/presentation/scene/living_banner.dart';
import 'package:drugtime_mobile/features/home/presentation/scene/pet_body.dart';
import 'package:drugtime_mobile/features/home/presentation/scene/pet_brain.dart';
import 'package:drugtime_mobile/features/home/presentation/scene/pet_props_painter.dart';
import 'package:drugtime_mobile/features/home/presentation/scene/scene_painter.dart';
import 'package:drugtime_mobile/features/home/presentation/scene/streak_milestone_store.dart';
import 'package:drugtime_mobile/features/home/presentation/scene/chibi_pet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime _ict(int h, [int m = 0]) =>
    DateTime.utc(2026, 11, 17, h, m).subtract(const Duration(hours: 7));

class _Harness extends StatelessWidget {
  const _Harness(
      {required this.now,
      this.signals = const HomePetSignals(ictMinutes: 600),
      this.showPet = true,
      this.onBrain,
      this.controller,
      this.onPressed});
  final DateTime now;
  final HomePetSignals signals;
  final bool showPet;
  final void Function(PetBrain)? onBrain;
  final ScrollController? controller;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Scaffold(
          body: ListView(
              controller: controller,
              padding: EdgeInsets.zero,
              children: [
                LivingBanner(
                  now: now,
                  signals: signals,
                  title: (_, ink, __) =>
                      Text('Chào buổi sáng', style: TextStyle(color: ink)),
                  trailing: const Icon(Icons.notifications),
                  chips: const [
                    Chip(label: Text('✓ 1/4 liều')),
                    Chip(label: Text('7 ngày'))
                  ],
                  showPet: showPet,
                  milestones: MemoryStreakMilestoneStore(),
                  debugOnBrain: onBrain,
                ),
                ElevatedButton(
                    onPressed: onPressed, child: const Text('Đã uống')),
                const SizedBox(height: 1600),
              ]),
        ),
      );
}

ScenePainter _scene(WidgetTester t) => t
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((c) => c.painter)
    .whereType<ScenePainter>()
    .single;

Future<void> _frames(WidgetTester t, double seconds) async {
  for (var i = 0; i < seconds * 60; i++) {
    await t.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  setUp(() => PetBrain.onboardingShown = false);

  testWidgets(
      'dựng tĩnh ở 4 mốc giờ không lỗi; ban đêm không có mặt trời (AC3)',
      (t) async {
    for (final h in [6, 12, 18, 2]) {
      await t.pumpWidget(_Harness(now: _ict(h)));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    }
    expect(_scene(t).sunPoint, isNull);
    await t.pumpWidget(_Harness(now: _ict(12)));
    await t.pump();
    expect(_scene(t).sunPoint, isNotNull);
  });

  testWidgets(
      'đổi giờ 1 phút thì mặt trời dịch; mở lại sau 6 giờ thì đúng giờ mới (AC5)',
      (t) async {
    await t.pumpWidget(_Harness(now: _ict(9)));
    await t.pump();
    final a = _scene(t).sunPoint!;
    await t.pumpWidget(_Harness(now: _ict(9, 1)));
    await t.pump();
    final b = _scene(t).sunPoint!;
    expect(b, isNot(a));
    expect(b.dx, greaterThan(a.dx));
    await t.pumpWidget(_Harness(now: _ict(15, 1)));
    await t.pump();
    expect(_scene(t).sunPoint!.dx, greaterThan(b.dx + 100));
  });

  testWidgets('đang tải: không có pet; tải xong: pet xuất hiện (AC14)',
      (t) async {
    await t.pumpWidget(_Harness(now: _ict(10), showPet: false));
    await t.pump();
    await t.pump();
    bool hasPet() => t
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .any((c) => c.painter is PetScenePainter);
    expect(hasPet(), isFalse);
    await t.pumpWidget(_Harness(now: _ict(10)));
    await t.pump();
    await t.pump();
    expect(hasPet(), isTrue);
  });

  group('cử chỉ (autoplay bật)', () {
    setUp(() => LivingBanner.autoplay = true);
    tearDown(() => LivingBanner.autoplay = false);

    Future<PetBrain> start(WidgetTester t,
        {HomePetSignals signals = const HomePetSignals(ictMinutes: 600),
        ScrollController? controller,
        VoidCallback? onPressed}) async {
      PetBrain? brain;
      await t.pumpWidget(_Harness(
          now: _ict(10),
          signals: signals,
          onBrain: (b) => brain = b,
          controller: controller,
          onPressed: onPressed));
      await _frames(t, .5);
      expect(brain, isNotNull);
      return brain!;
    }

    Offset petCenter(WidgetTester t, PetBrain b) {
      final box = t.renderObject<RenderBox>(find.byType(LivingBanner));
      return box
          .localToGlobal(b.body.feet - const Offset(0, PetBody.height / 2));
    }

    testWidgets('chạm, nhấn giữ, kéo thả trên pet (AC23)', (t) async {
      final b = await start(t);
      await t.tapAt(petCenter(t, b));
      await _frames(t, .1);
      expect([PetMood.wave, PetMood.poke, PetMood.hug], contains(b.mood));
      await _frames(t, 2);

      final g = await t.startGesture(petCenter(t, b));
      await _frames(t, .7);
      expect(b.mood, PetMood.hug);
      await g.up();
      await _frames(t, 1);

      final drag = await t.startGesture(petCenter(t, b));
      await drag.moveBy(const Offset(-40, -30));
      await _frames(t, .1);
      await drag.moveBy(const Offset(-40, -10));
      await _frames(t, .1);
      expect(b.mood, PetMood.carried);
      await drag.up();
      await _frames(t, .05);
      await _frames(t, 3);
      expect(b.body.motion, isNot(PetMotion.carried));
      expect(b.body.motion, isNot(PetMotion.falling));
    });

    testWidgets(
        'kéo ngoài pet thì danh sách cuộn; kéo pet thì không cuộn (AC24)',
        (t) async {
      final scroll = ScrollController();
      var pressed = 0;
      final b = await start(t, controller: scroll, onPressed: () => pressed++);
      final banner = t.getRect(find.byType(LivingBanner));
      // điểm trên trời phía trái, xa pet và xa mặt trời
      final pet = petCenter(t, b);
      final away = Offset(
          pet.dx > banner.center.dx ? banner.left + 30 : banner.right - 30,
          banner.top + banner.height * .7);
      await t.dragFrom(away, const Offset(0, -150));
      await _frames(t, .5);
      expect(scroll.offset, greaterThan(50));

      scroll.jumpTo(0);
      await _frames(t, .5);
      final before = scroll.offset;
      final drag = await t.startGesture(petCenter(t, b));
      await drag.moveBy(const Offset(0, -20));
      await _frames(t, .05);
      await drag.moveBy(const Offset(0, -60));
      await _frames(t, .05);
      expect(scroll.offset, before);
      expect(b.body.motion, PetMotion.carried);
      await drag.up();
      await _frames(t, 3);

      await t.tap(find.text('Đã uống'));
      await _frames(t, .2);
      expect(pressed, 1);
    });

    testWidgets(
        'chạm chip không làm pet phản ứng; kéo trên chip thì cuộn (AC26)',
        (t) async {
      final scroll = ScrollController();
      final b = await start(t, controller: scroll);
      await _frames(t, 1);
      await t.tap(find.text('✓ 1/4 liều'), warnIfMissed: false);
      await _frames(t, .2);
      expect(
          [PetMood.wave, PetMood.poke, PetMood.hug], isNot(contains(b.mood)));
      expect(b.layer, isNot(PetLayer.gesture));
      await t.dragFrom(t.getCenter(find.text('7 ngày')), const Offset(0, -150));
      await _frames(t, .5);
      expect(scroll.offset, greaterThan(50));
    });

    testWidgets(
        'pet cao 84 dp; bong bóng đạo cụ nằm trên đầu, không đè thân (AC27)',
        (t) async {
      final b = await start(t,
          signals: const HomePetSignals(ictMinutes: 600, inDoseWindow: true));
      await _frames(t, 10);
      expect(b.prop, PetProp.clock);
      expect(PetBody.height, 84);
      expect(PetScenePainter.box * 72 / 100, closeTo(84, .01));
      final c = PetScenePainter.bubbleCenter(b.body);
      final body = b.body.rect;
      expect(c.dy + 17, lessThanOrEqualTo(body.top));
      expect(Rect.fromCircle(center: c, radius: 17).overlaps(body), isFalse);
    });

    testWidgets(
        'đang ngủ: gõ thì hé mắt rồi ngủ lại; kéo pet không nhấc lên (AC22)',
        (t) async {
      final b =
          await start(t, signals: const HomePetSignals(ictMinutes: 23 * 60));
      await _frames(t, 12);
      expect(b.asleep, isTrue);
      final head = petCenter(t, b) + const Offset(10, 12);
      await t.tapAt(head);
      await _frames(t, .2);
      expect([PetMood.sleepPeek, PetMood.sleepBlanket], contains(b.mood));
      await _frames(t, 3);
      expect(b.asleep, isTrue);
    });
  });

  testWidgets('khung chưa có chiều rộng (khung đầu trên Android) không lỗi',
      (t) async {
    await t.pumpWidget(MaterialApp(
      home: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 0,
          child: LivingBanner(
            now: _ict(10),
            signals: const HomePetSignals(ictMinutes: 600),
            title: (_, __, ___) => const SizedBox(),
          ),
        ),
      ),
    ));
    await t.pump();
    await t.pump();
    expect(t.takeException(), isNull);
  });

  group('banner tự lấy giờ và mốc chuỗi (lưu ý review M1, M2)', () {
    setUp(() => LivingBanner.autoplay = true);
    tearDown(() {
      LivingBanner.autoplay = false;
      LivingBanner.clock = DateTime.now;
    });

    testWidgets(
        'không truyền now: qua 22:00 thì pet tự đi ngủ dù màn không dựng lại',
        (t) async {
      var now = _ict(21, 50);
      LivingBanner.clock = () => now;
      PetBrain? brain;
      await t.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LivingBanner(
            // tín hiệu tạo lúc build, giờ trong đó đứng yên ở 10:00
            signals: const HomePetSignals(ictMinutes: 600, empty: true),
            title: (_, ink, __) => const Text('Chào'),
            milestones: MemoryStreakMilestoneStore(),
            debugOnBrain: (b) => brain = b,
          ),
        ),
      ));
      await _frames(t, 2);
      expect(brain!.asleep, isFalse);
      now = _ict(22, 5);
      // màn test rộng 800 dp: pet có thể phải đi ~350 dp tới chỗ ngủ (38 dp/s)
      await _frames(t, 16);
      expect(brain!.layer, PetLayer.sleep,
          reason: '${brain!.body.feet} ${brain!.mood}');
      await _frames(t, 8);
      expect(brain!.asleep, isTrue,
          reason: '${brain!.body.feet} ${brain!.mood}');
    });

    testWidgets('mốc chuỗi về trước khi pet được tạo vẫn được cắm cờ',
        (t) async {
      // Trên Android khung đầu có thể rộng 0: pet chưa được tạo khi kết quả mốc chuỗi về.
      PetBrain? brain;
      final store = MemoryStreakMilestoneStore();
      Widget app(double width) => MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: width,
                  child: LivingBanner(
                    now: _ict(10),
                    signals: const HomePetSignals(ictMinutes: 600, streak: 7),
                    title: (_, ink, __) => const Text('Chào'),
                    milestones: store,
                    debugOnBrain: (b) => brain = b,
                  ),
                ),
              ),
            ),
          );
      await t.pumpWidget(app(0));
      await t.pump();
      expect(brain, isNull);
      expect(store.shown, {7}); // đã đánh dấu "đã phát" trên máy
      await t.pumpWidget(app(400));
      var flag = false;
      for (var i = 0; i < 180; i++) {
        await t.pump(const Duration(milliseconds: 16));
        flag |= brain?.prop == PetProp.flag;
      }
      expect(flag, isTrue);
    });

    testWidgets('gỡ banner khi đang nhấn giữ pet không lỗi', (t) async {
      PetBrain? brain;
      await t.pumpWidget(_Harness(now: _ict(10), onBrain: (b) => brain = b));
      await _frames(t, .5);
      final box = t.renderObject<RenderBox>(find.byType(LivingBanner));
      final g = await t.startGesture(box.localToGlobal(
          brain!.body.feet - const Offset(0, PetBody.height / 2)));
      await t.pump(const Duration(milliseconds: 100));
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 1));
      await g.up();
      expect(t.takeException(), isNull);
    });
  });
}
