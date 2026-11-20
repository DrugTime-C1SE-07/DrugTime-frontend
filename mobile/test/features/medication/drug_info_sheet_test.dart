import 'dart:async';

import 'package:drugtime_mobile/features/medication/domain/entities/medication.dart';
import 'package:drugtime_mobile/features/medication/domain/entities/medication_failure.dart';
import 'package:drugtime_mobile/features/medication/presentation/widgets/drug_info_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _known = DrugCatalogDetail(
  id: '1007',
  name: 'Paracetamol 500mg',
  activeIngredient: 'Paracetamol',
  strength: '500mg',
  dosageForm: 'Viên nén',
);

const _full = DrugCatalogDetail(
  id: '1007',
  name: 'Paracetamol 500mg',
  activeIngredient: 'Paracetamol',
  strength: '500mg',
  dosageForm: 'Viên nén',
  manufacturerName: 'Công ty CP Dược phẩm ABC',
  manufacturerCountry: 'Việt Nam',
  packagingSpec: 'Hộp 10 vỉ x 10 viên',
  source: 'duoc_thu_qg',
);

void main() {
  Future<void> mount(WidgetTester tester,
          Future<DrugCatalogDetail> Function() load) =>
      tester.pumpWidget(MaterialApp(
          home: Scaffold(body: DrugInfoSheet(known: _known, load: load))));

  String rowText(WidgetTester tester, String label) {
    final semantics = tester.getSemantics(find.bySemanticsLabel(RegExp('^$label: ')));
    return semantics.label.substring(label.length + 2);
  }

  testWidgets('hiện đủ trường dạng nhãn: giá trị, hàm lượng dễ đọc (AC7)',
      (tester) async {
    final handle = tester.ensureSemantics();
    await mount(tester, () async => _full);
    await tester.pumpAndSettle();
    expect(rowText(tester, 'Hoạt chất'), 'Paracetamol');
    expect(rowText(tester, 'Hàm lượng'), '500 mg');
    expect(rowText(tester, 'Dạng bào chế'), 'Viên nén');
    expect(rowText(tester, 'Nhà sản xuất'), 'Công ty CP Dược phẩm ABC');
    expect(rowText(tester, 'Nước sản xuất'), 'Việt Nam');
    expect(rowText(tester, 'Quy cách'), 'Hộp 10 vỉ x 10 viên');
    expect(find.text('Nguồn: Dược thư Quốc gia Việt Nam'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('trường thiếu ghi "Chưa có thông tin", không có công dụng (AC8)',
      (tester) async {
    final handle = tester.ensureSemantics();
    await mount(tester, () async => const DrugCatalogDetail(
        id: '2210', name: 'Melas', strength: '0,04', dosageForm: 'Kem bôi da'));
    await tester.pumpAndSettle();
    expect(rowText(tester, 'Hàm lượng'), '0,04'); // không quy đổi (QD-38)
    expect(rowText(tester, 'Nhà sản xuất'), 'Chưa có thông tin');
    expect(rowText(tester, 'Nước sản xuất'), 'Chưa có thông tin');
    for (final banned in ['Công dụng', 'Liều tối đa', 'Cảnh báo']) {
      expect(find.textContaining(banned), findsNothing);
    }
    handle.dispose();
  });

  testWidgets('hiện ngay phần đã có khi đang tải', (tester) async {
    final handle = tester.ensureSemantics();
    final pending = Completer<DrugCatalogDetail>();
    await mount(tester, () => pending.future);
    await tester.pump();
    expect(rowText(tester, 'Hàm lượng'), '500 mg');
    expect(rowText(tester, 'Nhà sản xuất'), 'Đang tải…');
    pending.complete(_full);
    await tester.pumpAndSettle();
    expect(rowText(tester, 'Nhà sản xuất'), 'Công ty CP Dược phẩm ABC');
    handle.dispose();
  });

  testWidgets('lỗi tải giữ phần đã có và cho thử lại', (tester) async {
    final handle = tester.ensureSemantics();
    var calls = 0;
    await mount(tester, () async {
      calls++;
      if (calls == 1) {
        throw const MedicationFailure(MedicationFailureKind.network);
      }
      return _full;
    });
    await tester.pumpAndSettle();
    expect(find.text('Chưa tải được thông tin nhà sản xuất'), findsOneWidget);
    expect(rowText(tester, 'Hoạt chất'), 'Paracetamol');
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('Chưa tải được thông tin nhà sản xuất'), findsNothing);
    expect(rowText(tester, 'Nhà sản xuất'), 'Công ty CP Dược phẩm ABC');
    handle.dispose();
  });
}
