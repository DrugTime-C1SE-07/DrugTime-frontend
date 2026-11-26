import 'package:drugtime_mobile/app/app_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Host extends StatefulWidget {
  const _Host({required this.swipe});
  final ValueNotifier<double> swipe;
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  int index = 0;
  void select(int i) => setState(() => index = i);

  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Scaffold(
          bottomNavigationBar: AppNavBar(
            selectedIndex: index,
            onSelected: select,
            swipe: widget.swipe,
          ),
        ),
      );
}

int _selected(WidgetTester tester) =>
    tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;

Finder _pill() => find.byWidgetPredicate((w) =>
    w is Container &&
    w.key is ValueKey<String> &&
    (w.key! as ValueKey<String>).value.startsWith('selected-nav-') &&
    !(w.key! as ValueKey<String>).value.startsWith('selected-nav-label-'));

void main() {
  late ValueNotifier<double> swipe;

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    swipe = ValueNotifier(0);
    addTearDown(swipe.dispose);
    await tester.pumpWidget(_Host(swipe: swipe));
  }

  testWidgets('bấm: viên trượt qua các tab ở giữa rồi nhãn mới bung ra',
      (tester) async {
    await pump(tester);
    final start = tester.getCenter(_pill()).dx;
    await tester.tap(find.byWidgetPredicate(
        (w) => w is NavigationDestination && w.label == 'Lịch nhắc'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final mid = tester.getCenter(_pill()).dx;
    expect(mid, greaterThan(start + 20));
    await tester.pumpAndSettle();
    expect(_selected(tester), 2);
    expect(find.byKey(const ValueKey('selected-nav-label-Lịch nhắc')),
        findsOneWidget);
    expect(tester.getCenter(_pill()).dx, greaterThan(mid));
  });

  testWidgets('kéo trên thanh không làm gì: chỉ vuốt nội dung mới dời viên',
      (tester) async {
    await pump(tester);
    final start = tester.getCenter(_pill()).dx;
    final gesture =
        await tester.startGesture(tester.getCenter(find.byType(NavigationBar)));
    await gesture.moveBy(const Offset(150, 0));
    await tester.pump();
    expect(tester.getCenter(_pill()).dx, start);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(_selected(tester), 0);
  });

  testWidgets('viên đứng đúng theo tiến độ vuốt, kể cả khi giữ tay giữa chừng',
      (tester) async {
    await pump(tester);
    final slot = tester.getSize(find.byType(NavigationBar)).width / 4;
    final start = tester.getCenter(_pill()).dx;
    swipe.value = .5;
    await tester.pump();
    final held = tester.getCenter(_pill()).dx;
    // tâm viên ở giữa ô 0 và ô 1, tức đúng mép giữa hai ô
    expect(held, closeTo(slot, 1));
    expect(held, greaterThan(start));
    // giữa hai tab: viên thu gọn, nhãn chưa bung
    final label = find.byWidgetPredicate((w) =>
        w is Text &&
        (w.key as ValueKey<String>?)?.value.startsWith('selected-nav-label-') ==
            true);
    expect(tester.getSize(label).width, greaterThan(0));
    expect(
        tester
            .widget<Opacity>(
                find.ancestor(of: label, matching: find.byType(Opacity)).first)
            .opacity,
        0);
    expect(find.descendant(of: _pill(), matching: find.byType(Icon)),
        findsOneWidget,
        reason: 'giữa hai tab viên chỉ mang một icon, không chồng hai icon');
    await tester
        .pump(const Duration(seconds: 1)); // giữ tay: viên không tự chạy
    expect(tester.getCenter(_pill()).dx, held);
    swipe.value = 0; // buông chưa đủ xa: trang về chỗ cũ, viên theo
    await tester.pump();
    expect(tester.getCenter(_pill()).dx, start);
  });

  testWidgets('vuốt sang hẳn tab sau rồi chốt: viên không chạy lại lần nữa',
      (tester) async {
    await pump(tester);
    swipe.value = 1;
    await tester.pump();
    final arrived = tester.getCenter(_pill()).dx;
    swipe.value = 0;
    tester.state<_HostState>(find.byType(_Host)).select(1);
    await tester.pump();
    for (var i = 0; i < 5; i++) {
      expect(tester.getCenter(_pill()).dx, closeTo(arrived, 1));
      await tester.pump(const Duration(milliseconds: 40));
    }
  });

  testWidgets('giảm chuyển động: bấm là viên tới đích ngay', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pump(tester);
    await tester.tap(find.byWidgetPredicate(
        (w) => w is NavigationDestination && w.label == 'Hồ sơ'));
    await tester.pump();
    await tester.pump();
    expect(
        find.byKey(const ValueKey('selected-nav-label-Hồ sơ')), findsOneWidget);
  });
}
