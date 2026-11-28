import 'package:drugtime_mobile/app/theme/simple_mode_theme.dart';
import 'package:drugtime_mobile/features/simple_mode/presentation/widgets/simple_mode_scaling.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrapWithViewport({
  required Size viewport,
  required double textScale,
  required Widget child,
}) {
  return MediaQuery(
    data: MediaQueryData(
      size: viewport,
      textScaler: TextScaler.linear(textScale),
    ),
    child: MaterialApp(
      theme: buildSimpleModeTheme(),
      home: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(SimpleModeSizes.spacingMd),
            child: child,
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('SimpleModeScaling helpers (TC-09)', () {
    testWidgets('TC-09: scaledTapTarget >= 48dp and isLargeTextScale threshold',
        (tester) async {
      late double lowScaleTarget;
      late double highScaleTarget;
      late bool lowIsLarge;
      late bool highIsLarge;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(0.85)),
          child: Builder(
            builder: (context) {
              lowScaleTarget = SimpleModeScaling.scaledTapTarget(context);
              lowIsLarge = SimpleModeScaling.isLargeTextScale(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: Builder(
            builder: (context) {
              highScaleTarget = SimpleModeScaling.scaledTapTarget(context);
              highIsLarge = SimpleModeScaling.isLargeTextScale(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(lowScaleTarget, greaterThanOrEqualTo(48.0));
      expect(lowIsLarge, isFalse);
      expect(highScaleTarget, greaterThanOrEqualTo(48.0));
      expect(highIsLarge, isTrue);
    });
  });

  group('SimpleModeActionButton scaling & overflow (TC-06)', () {
    for (final viewport in const [Size(320, 640), Size(375, 812)]) {
      for (final scale in const [1.0, 1.5, 2.0]) {
        testWidgets(
          'TC-06: zero overflow & >=48dp at ${viewport.width.toInt()}x${viewport.height.toInt()} @ ${scale}x',
          (tester) async {
            tester.view.physicalSize = viewport;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);

            await tester.pumpWidget(
              _wrapWithViewport(
                viewport: viewport,
                textScale: scale,
                child: SimpleModeActionButton(
                  key: const Key('action_btn'),
                  label: 'Đã uống đủ liều buổi sáng',
                  icon: Icons.check_circle_outline,
                  onPressed: () {},
                ),
              ),
            );

            expect(tester.takeException(), isNull);
            final size = tester.getSize(find.byKey(const Key('action_btn')));
            expect(size.width, greaterThanOrEqualTo(48.0));
            expect(size.height, greaterThanOrEqualTo(48.0));

            final textWidget = tester.widget<Text>(
              find.text('Đã uống đủ liều buổi sáng'),
            );
            expect(textWidget.softWrap, isNot(isFalse));
            expect(textWidget.overflow, isNot(TextOverflow.ellipsis));
          },
        );
      }
    }
  });

  group('SimpleModeScalableRow responsive layout (TC-07)', () {
    testWidgets('TC-07: uses Row at 1.0x and stacks vertically at 2.0x without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _wrapWithViewport(
          viewport: const Size(375, 812),
          textScale: 1.0,
          child: const SimpleModeScalableRow(
            leading: Text('Metformin 500mg'),
            trailing: Text('08:00'),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(Row), findsOneWidget);

      tester.view.physicalSize = const Size(320, 640);
      await tester.pumpWidget(
        _wrapWithViewport(
          viewport: const Size(320, 640),
          textScale: 2.0,
          child: const SimpleModeScalableRow(
            leading: Text('Metformin 500mg uống sau ăn sáng'),
            trailing: Text('08:00 sáng'),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(Column), findsAtLeastNWidgets(1));
    });
  });

  group('SimpleModeContrastCard scaling (TC-08)', () {
    for (final scale in const [1.0, 1.5, 2.0]) {
      testWidgets(
        'TC-08: renders without overflow on 320x640 at ${scale}x',
        (tester) async {
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(
            _wrapWithViewport(
              viewport: const Size(320, 640),
              textScale: scale,
              child: SimpleModeContrastCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Liều kế tiếp lúc 08:00',
                      style: SimpleModeTextStyles.heading,
                    ),
                    const SizedBox(height: SimpleModeSizes.spacingSm),
                    Text(
                      'Amlodipine 5mg · 1 viên sau ăn',
                      style: SimpleModeTextStyles.body,
                    ),
                    const SizedBox(height: SimpleModeSizes.spacingMd),
                    SimpleModeActionButton(
                      label: 'Tôi đã uống thuốc',
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
            ),
          );

          expect(tester.takeException(), isNull);
        },
      );
    }
  });
}
