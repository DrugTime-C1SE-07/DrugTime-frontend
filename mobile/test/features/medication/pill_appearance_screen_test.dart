import 'package:drugtime_mobile/features/medication/domain/entities/pill_appearance.dart';
import 'package:drugtime_mobile/features/medication/presentation/screens/pill_appearance_screen.dart';
import 'package:drugtime_mobile/features/medication/presentation/widgets/pill_appearance_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('chọn Viên tròn + Vàng rồi "Dùng hình này" trả lựa chọn (AC11)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    PillAppearanceChoice? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await showPillAppearanceScreen(context,
              drugName: 'Paracetamol 500mg', dosageForm: 'Viên nang'),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Mặc định gợi ý hình theo dạng bào chế, màu trắng.
    PillAppearanceTile preview() =>
        tester.widget<PillAppearanceTile>(find.byKey(const Key('pill-preview')));
    expect(preview().shape, PillShape.capsule);
    expect(preview().color, PillColor.white);
    expect(find.text('Hiện ở mọi nơi trong app'), findsOneWidget);
    expect(find.text('Bước 3/3 · Xác nhận'), findsOneWidget);
    for (final s in PillShape.values) {
      expect(find.byKey(Key('pill-shape-${s.apiValue}')), findsOneWidget);
    }
    for (final c in PillColor.values) {
      expect(find.byKey(Key('pill-color-${c.apiValue}')), findsOneWidget);
    }

    await tester.tap(find.byKey(const Key('pill-shape-round_tablet')));
    await tester.tap(find.byKey(const Key('pill-color-yellow')));
    await tester.pump();
    expect(preview().shape, PillShape.roundTablet);
    expect(preview().color, PillColor.yellow);
    expect(find.bySemanticsLabel('Màu Vàng'), findsOneWidget);

    await tester.tap(find.byKey(const Key('use-pill-appearance')));
    await tester.pumpAndSettle();
    expect(result, (PillShape.roundTablet, PillColor.yellow));
  });

  testWidgets('quay lại không đổi gì', (tester) async {
    PillAppearanceChoice? result = (PillShape.syrup, PillColor.red);
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async =>
              result = await showPillAppearanceScreen(context, drugName: 'Siro ho'),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Quay lại'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });
}
