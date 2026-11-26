import 'package:drugtime_mobile/core/motion/shared_axis.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget home, {bool reduceMotion = false}) => MaterialApp(
      theme: ThemeData(pageTransitionsTheme: sharedAxisPageTransitionsTheme),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: child!,
      ),
      home: home,
    );

class _Counter extends StatefulWidget {
  const _Counter(this.label);
  final String label;
  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int count = 0;
  @override
  Widget build(BuildContext context) => Center(
        child: TextButton(
          onPressed: () => setState(() => count++),
          child: Text('${widget.label} $count'),
        ),
      );
}

double _dx(WidgetTester tester, Finder finder) =>
    tester.getTopLeft(finder).dx -
    tester.getTopLeft(find.byType(Scaffold).first).dx;

void main() {
  testWidgets('push and pop use the shared-axis slide and fade (AC9)',
      (tester) async {
    await tester.pumpWidget(_app(Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('second')))),
          child: const Text('open'),
        ),
      ),
    )));
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(sharedAxisDuration * .5);
    final opacity = tester
        .widgetList<Opacity>(find.ancestor(
            of: find.text('second'), matching: find.byType(Opacity)))
        .first
        .opacity;
    expect(opacity, inExclusiveRange(0, 1));
    final transform = tester
        .widgetList<Transform>(find.ancestor(
            of: find.text('second'), matching: find.byType(Transform)))
        .first;
    expect(transform.transform.getTranslation().x, greaterThan(0));
    await tester.pumpAndSettle();
    expect(find.text('second'), findsOneWidget);

    Navigator.of(tester.element(find.text('second'))).pop();
    await tester.pump();
    await tester.pump(sharedAxisDuration * .5);
    expect(find.text('second'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('second'), findsNothing);
  });

  testWidgets('sharedAxisRoute returns a typed result', (tester) async {
    bool? result;
    await tester.pumpWidget(_app(Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () async => result = await Navigator.of(context).push(
              sharedAxisRoute<bool>(
                  builder: (context) => Scaffold(
                      body: TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('done'))))),
          child: const Text('open'),
        ),
      ),
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('done'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('reduce motion shows the new page without a slide (AC10)',
      (tester) async {
    await tester.pumpWidget(_app(
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: Text('second')))),
            child: const Text('open'),
          ),
        ),
      ),
      reduceMotion: true,
    ));
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(sharedAxisDuration * .5);
    final opacities = tester.widgetList<Opacity>(
        find.ancestor(of: find.text('second'), matching: find.byType(Opacity)));
    expect(opacities.every((o) => o.opacity == 1), isTrue);
  });

  group('SharedAxisTabSwitcher (AC8, AC10)', () {
    Widget switcher(int index, {bool reduceMotion = false}) => _app(
          Scaffold(
            body: SharedAxisTabSwitcher(index: index, children: const [
              _Counter('home'),
              _Counter('meds'),
              _Counter('profile'),
            ]),
          ),
          reduceMotion: reduceMotion,
        );

    testWidgets('animates between tabs and keeps each tab state',
        (tester) async {
      await tester.pumpWidget(switcher(0));
      await tester.tap(find.text('home 0'));
      await tester.pump();
      expect(find.text('home 1'), findsOneWidget);

      await tester.pumpWidget(switcher(1));
      await tester.pump(sharedAxisDuration * .5);
      // Mid-switch: both tabs are on stage, the new one offset to the right.
      expect(find.text('home 1'), findsOneWidget);
      expect(find.text('meds 0'), findsOneWidget);
      expect(_dx(tester, find.text('meds 0')), greaterThan(0));
      await tester.pumpAndSettle();
      expect(find.text('home 1'), findsNothing); // offstage
      expect(find.text('meds 0'), findsOneWidget);

      await tester.pumpWidget(switcher(0));
      await tester.pumpAndSettle();
      expect(find.text('home 1'), findsOneWidget,
          reason: 'state survives the round trip');
    });

    testWidgets('only the current tab receives taps', (tester) async {
      await tester.pumpWidget(switcher(0));
      await tester.pumpWidget(switcher(2));
      await tester.pump(sharedAxisDuration * .2);
      await tester.tap(find.text('home 0'), warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.pumpWidget(switcher(0));
      await tester.pumpAndSettle();
      expect(find.text('home 0'), findsOneWidget);
    });

    testWidgets('reduce motion switches immediately', (tester) async {
      await tester.pumpWidget(switcher(0, reduceMotion: true));
      await tester.pumpWidget(switcher(1, reduceMotion: true));
      await tester.pump();
      expect(find.text('home 0'), findsNothing);
      expect(find.text('meds 0'), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('SharedAxisTabSwitcher swipe', () {
    late ValueNotifier<double> swipe;
    late List<int> swiped;

    Future<void> pumpSwiper(WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      swipe = ValueNotifier(0);
      addTearDown(swipe.dispose);
      swiped = [];
      var index = 0;
      await tester.pumpWidget(_app(StatefulBuilder(
        builder: (context, setState) => Scaffold(
          body: SharedAxisTabSwitcher(
            index: index,
            swipe: swipe,
            swipeTarget: (i, dir) =>
                i + dir < 0 || i + dir > 2 ? null : i + dir,
            onSwiped: (i) {
              swiped.add(i);
              setState(() => index = i);
            },
            children: const [
              _Counter('home'),
              _Counter('meds'),
              _Counter('profile'),
            ],
          ),
        ),
      )));
    }

    testWidgets('vuốt một chút rồi giữ tay: trang vẫn tự chạy hẳn sang tab kế',
        (tester) async {
      await pumpSwiper(tester);
      final gesture = await tester.startGesture(const Offset(300, 400));
      await gesture.moveBy(const Offset(-30, 0)); // qua ngưỡng nhận kéo
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final mid = swipe.value;
      expect(mid, greaterThan(.3), reason: 'đã tự chạy, không đứng theo tay');
      await tester.pump(const Duration(seconds: 1)); // vẫn đang giữ tay
      expect(swiped, [1], reason: 'không dừng giữa hai tab');
      expect(swipe.value, 0);
      expect(find.text('meds 0'), findsOneWidget);
      expect(find.text('home 0'), findsNothing);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(swiped, [1]);
    });

    testWidgets('kéo tiếp hoặc kéo ngược trong lúc trang đang chạy: bỏ qua',
        (tester) async {
      await pumpSwiper(tester);
      final gesture = await tester.startGesture(const Offset(300, 400));
      await gesture.moveBy(const Offset(-30, 0));
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.moveBy(const Offset(200, 0)); // kéo ngược
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(swiped, [1]);
      final second = await tester.startGesture(const Offset(300, 400));
      await second.moveBy(const Offset(-30, 0));
      await tester.pump(const Duration(milliseconds: 50));
      // cú vuốt mới khi trang còn chạy dở không xếp hàng thêm tab nữa
      final third = await tester.startGesture(const Offset(300, 400));
      await third.moveBy(const Offset(-30, 0));
      await tester.pumpAndSettle();
      await second.up();
      await third.up();
      await tester.pumpAndSettle();
      expect(swiped, [1, 2]);
    });

    testWidgets('kéo dài gần hết màn vẫn chỉ sang một tab', (tester) async {
      await pumpSwiper(tester);
      final gesture = await tester.startGesture(const Offset(390, 400));
      for (var i = 0; i < 30; i++) {
        await gesture.moveBy(const Offset(-20, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester
          .pump(const Duration(milliseconds: 200)); // dừng tay trước khi thả
      await gesture.up();
      await tester.pumpAndSettle();
      expect(swiped, [1], reason: 'kéo gần hết màn vẫn chỉ sang một tab');
      expect(find.text('meds 0'), findsOneWidget);
      expect(find.text('home 0'), findsNothing);
    });

    testWidgets('lướt nhanh quãng ngắn cũng sang tab kế', (tester) async {
      await pumpSwiper(tester);
      await tester.flingFrom(
          const Offset(300, 400), const Offset(-60, 0), 1200);
      await tester.pumpAndSettle();
      expect(swiped, [1]);
    });

    testWidgets('không có tab phía trước: kéo nặng dần rồi bật về',
        (tester) async {
      await pumpSwiper(tester);
      final gesture = await tester.startGesture(const Offset(50, 400));
      await gesture.moveBy(const Offset(30, 0));
      await gesture.moveBy(const Offset(300, 0));
      await tester.pump();
      expect(swipe.value, inInclusiveRange(-.15, 0));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(swiped, isEmpty);
      expect(swipe.value, 0);
    });
  });
}
