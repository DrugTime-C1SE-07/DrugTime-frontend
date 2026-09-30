import 'package:drugtime_mobile/app/theme/app_theme.dart';
import 'package:drugtime_mobile/features/medication/presentation/widgets/medication_filter_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const _counts = {
  MedicationFilter.all: 5,
  MedicationFilter.active: 4,
  MedicationFilter.stopped: 1,
};

String _labelOf(MedicationFilter f) => '${f.label} · ${_counts[f]}';

/// Dựng thanh lọc với lề ngang giống màn S06 (AppSpacing.page).
Future<void> pumpBar(
  WidgetTester tester, {
  required double width,
  MedicationFilter selected = MedicationFilter.all,
  double textScale = 1,
  ValueChanged<MedicationFilter>? onChanged,
}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
          child: Align(
            alignment: Alignment.topLeft,
            child: MedicationFilterBar(
              selected: selected,
              counts: _counts,
              onChanged: onChanged ?? (_) {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Vùng nhận chạm của chip chứa nhãn [label].
Finder chipOf(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(InkWell)).first;

void expectOneRow(WidgetTester tester, double width) {
  final rects = [for (final f in MedicationFilter.values) tester.getRect(chipOf(_labelOf(f)))];
  for (final r in rects.skip(1)) {
    expect(r.top, rects.first.top, reason: 'chip rớt xuống dòng khác');
  }
  for (final r in rects) {
    expect(r.right, lessThanOrEqualTo(width - AppSpacing.page), reason: 'chip tràn khỏi lề phải');
  }
}

void main() {
  group('ba chip nằm một hàng ở cỡ chữ 1.0', () {
    for (final width in [360.0, 375.0]) {
      for (final selected in MedicationFilter.values) {
        testWidgets('rộng $width, đang chọn ${selected.label}', (tester) async {
          await pumpBar(tester, width: width, selected: selected);
          expectOneRow(tester, width);
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  testWidgets('phóng chữ 1.5x: ba chip vẫn một hàng, không cắt chữ, không overflow', (tester) async {
    await pumpBar(tester, width: 375, textScale: 1.5);

    expectOneRow(tester, 375);
    expect(tester.takeException(), isNull);
    for (final f in MedicationFilter.values) {
      final label = tester.getRect(find.text(_labelOf(f)));
      final chip = tester.getRect(chipOf(_labelOf(f)));
      expect(chip.contains(label.topLeft) && chip.contains(label.bottomRight - const Offset(1, 1)),
          isTrue, reason: 'nhãn "${_labelOf(f)}" bị cắt: $label ngoài $chip');
      expect(tester.renderObject<RenderParagraph>(find.text(_labelOf(f))).didExceedMaxLines, isFalse);
    }
  });

  testWidgets('vùng chạm mỗi chip cao ít nhất 44', (tester) async {
    await pumpBar(tester, width: 375);
    for (final f in MedicationFilter.values) {
      expect(tester.getSize(chipOf(_labelOf(f))).height, greaterThanOrEqualTo(44));
    }
  });

  testWidgets('nhấn chip gọi onChanged với đúng bộ lọc', (tester) async {
    final picked = <MedicationFilter>[];
    await pumpBar(tester, width: 375, onChanged: picked.add);

    for (final f in MedicationFilter.values.reversed) {
      await tester.tap(chipOf(_labelOf(f)));
    }
    expect(picked, MedicationFilter.values.reversed.toList());
  });

  testWidgets('chip đang chọn được đánh dấu selected cho trình đọc màn hình', (tester) async {
    await pumpBar(tester, width: 375, selected: MedicationFilter.stopped);

    // Đọc thẳng thuộc tính Semantics thay vì matcher semantics: matcher cũ đã
    // deprecated từ Flutter 3.40, matcher mới lại chưa có ở bản cũ hơn.
    SemanticsProperties propsOf(MedicationFilter f) => tester
        .widget<Semantics>(find.ancestor(of: chipOf(_labelOf(f)), matching: find.byType(Semantics)).first)
        .properties;

    for (final f in MedicationFilter.values) {
      final props = propsOf(f);
      expect(props.button, isTrue);
      expect(props.selected, f == MedicationFilter.stopped, reason: f.label);
      expect(props.label, '${f.label}, ${_counts[f]} thuốc');
    }
  });
}
