import 'package:drugtime_mobile/app/theme/simple_mode_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WcagContrast (TC-01)', () {
    test('TC-01: black on white is 21:1 and symmetric', () {
      final ratio1 = WcagContrast.contrastRatio(Colors.black, Colors.white);
      final ratio2 = WcagContrast.contrastRatio(Colors.white, Colors.black);

      expect(ratio1, closeTo(21.0, 0.05));
      expect(ratio2, closeTo(21.0, 0.05));
      expect(WcagContrast.meetsAaaNormalText(Colors.black, Colors.white), isTrue);
      expect(WcagContrast.meetsAaaNormalText(Colors.grey, Colors.white), isFalse);
    });
  });

  group('SimpleModeColors WCAG AAA >= 7:1 (TC-02, TC-03)', () {
    test('TC-02: primary, muted, and brand pairs meet >= 7:1 contrast', () {
      const pairs = <(String, Color, Color)>[
        ('ink on canvas', SimpleModeColors.ink, SimpleModeColors.canvas),
        ('ink on surface', SimpleModeColors.ink, SimpleModeColors.surface),
        ('ink on surfaceMuted', SimpleModeColors.ink, SimpleModeColors.surfaceMuted),
        ('ink on brandTint', SimpleModeColors.ink, SimpleModeColors.brandTint),
        ('inkMuted on canvas', SimpleModeColors.inkMuted, SimpleModeColors.canvas),
        ('inkMuted on surfaceMuted', SimpleModeColors.inkMuted, SimpleModeColors.surfaceMuted),
        ('onBrand on brand', SimpleModeColors.onBrand, SimpleModeColors.brand),
        ('onBrand on brandStrong', SimpleModeColors.onBrand, SimpleModeColors.brandStrong),
        ('brand on brandTint', SimpleModeColors.brand, SimpleModeColors.brandTint),
      ];

      for (final (label, fg, bg) in pairs) {
        final ratio = WcagContrast.contrastRatio(fg, bg);
        expect(
          ratio,
          greaterThanOrEqualTo(7.0),
          reason: '$label contrast was ${ratio.toStringAsFixed(2)}:1 (< 7:1)',
        );
      }
    });

    test('TC-03: clinical status color pairs meet >= 7:1 contrast', () {
      const pairs = <(String, Color, Color)>[
        ('safe on safeBg', SimpleModeColors.safe, SimpleModeColors.safeBg),
        ('safe on surface', SimpleModeColors.safe, SimpleModeColors.surface),
        ('caution on cautionBg', SimpleModeColors.caution, SimpleModeColors.cautionBg),
        ('caution on surface', SimpleModeColors.caution, SimpleModeColors.surface),
        ('danger on dangerBg', SimpleModeColors.danger, SimpleModeColors.dangerBg),
        ('danger on surface', SimpleModeColors.danger, SimpleModeColors.surface),
        ('info on infoBg', SimpleModeColors.info, SimpleModeColors.infoBg),
        ('info on surface', SimpleModeColors.info, SimpleModeColors.surface),
      ];

      for (final (label, fg, bg) in pairs) {
        final ratio = WcagContrast.contrastRatio(fg, bg);
        expect(
          ratio,
          greaterThanOrEqualTo(7.0),
          reason: '$label contrast was ${ratio.toStringAsFixed(2)}:1 (< 7:1)',
        );
      }
    });
  });

  group('SimpleModeTextStyles & ThemeData typography >= 18sp (TC-04)', () {
    test('TC-04: all SimpleModeTextStyles and textTheme slots are >= 18sp', () {
      const styles = <String, TextStyle>{
        'display': SimpleModeTextStyles.display,
        'title': SimpleModeTextStyles.title,
        'heading': SimpleModeTextStyles.heading,
        'body': SimpleModeTextStyles.body,
        'bodyStrong': SimpleModeTextStyles.bodyStrong,
        'buttonLabel': SimpleModeTextStyles.buttonLabel,
        'caption': SimpleModeTextStyles.caption,
        'figure': SimpleModeTextStyles.figure,
      };

      for (final entry in styles.entries) {
        expect(
          entry.value.fontSize,
          isNotNull,
          reason: '${entry.key} must define fontSize',
        );
        expect(
          entry.value.fontSize!,
          greaterThanOrEqualTo(18.0),
          reason: '${entry.key} fontSize must be >= 18.0',
        );
      }

      final theme = buildSimpleModeTheme();
      final themeSlots = <String, TextStyle?>{
        'headlineSmall': theme.textTheme.headlineSmall,
        'titleMedium': theme.textTheme.titleMedium,
        'bodyLarge': theme.textTheme.bodyLarge,
        'bodyMedium': theme.textTheme.bodyMedium,
        'bodySmall': theme.textTheme.bodySmall,
        'labelLarge': theme.textTheme.labelLarge,
      };

      for (final entry in themeSlots.entries) {
        expect(entry.value?.fontSize, isNotNull, reason: '${entry.key} missing');
        expect(
          entry.value!.fontSize!,
          greaterThanOrEqualTo(18.0),
          reason: 'ThemeData.textTheme.${entry.key} must be >= 18.0',
        );
      }
    });
  });

  group('SimpleModeSizes & touch targets >= 48dp (TC-05)', () {
    testWidgets('TC-05: themed buttons render with >= 48x48dp touch targets',
        (tester) async {
      expect(SimpleModeSizes.minTapTarget, greaterThanOrEqualTo(48.0));
      expect(SimpleModeSizes.primaryButtonHeight, greaterThanOrEqualTo(48.0));
      expect(SimpleModeSizes.fieldHeight, greaterThanOrEqualTo(48.0));

      final theme = buildSimpleModeTheme();

      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Column(
              children: [
                FilledButton(
                  key: const Key('filled_btn'),
                  onPressed: () {},
                  child: const Text('Xác nhận'),
                ),
                OutlinedButton(
                  key: const Key('outlined_btn'),
                  onPressed: () {},
                  child: const Text('Bỏ qua'),
                ),
                TextButton(
                  key: const Key('text_btn'),
                  onPressed: () {},
                  child: const Text('Xem'),
                ),
              ],
            ),
          ),
        ),
      );

      for (final key in const [
        Key('filled_btn'),
        Key('outlined_btn'),
        Key('text_btn'),
      ]) {
        final size = tester.getSize(find.byKey(key));
        expect(size.width, greaterThanOrEqualTo(48.0), reason: '$key width < 48');
        expect(size.height, greaterThanOrEqualTo(48.0), reason: '$key height < 48');
      }
    });
  });
}
