import 'package:drugtime_mobile/features/medication_capture/presentation/widgets/scanning_mascot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<ScanningMascotState> mount(WidgetTester tester,
      {bool reduceMotion = false}) async {
    await tester.pumpWidget(MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: const MaterialApp(home: Scaffold(body: ScanningMascot()))));
    return tester.state<ScanningMascotState>(find.byType(ScanningMascot));
  }

  testWidgets('linh vật cầm kính lúp đang chuyển động (AC3)', (tester) async {
    final state = await mount(tester);
    expect(find.byKey(const Key('scanning-mascot')), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(
        find.byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is MagnifierPainter),
        findsOneWidget);
    expect(state.controller.isAnimating, isTrue);
    final before = state.controller.value;
    await tester.pump(const Duration(milliseconds: 400));
    expect(state.controller.value, isNot(before));
  });

  testWidgets('giảm chuyển động thì đứng yên (AC3)', (tester) async {
    final state = await mount(tester, reduceMotion: true);
    expect(state.controller.isAnimating, isFalse);
  });

  testWidgets('animation hữu hạn nên pumpAndSettle kết thúc', (tester) async {
    final state = await mount(tester);
    await tester.pumpAndSettle(const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate, const Duration(minutes: 2));
    expect(state.controller.isAnimating, isFalse);
  });
}
