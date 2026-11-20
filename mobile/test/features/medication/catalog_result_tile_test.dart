import 'package:drugtime_mobile/features/medication/domain/entities/medication.dart';
import 'package:drugtime_mobile/features/medication/presentation/widgets/catalog_result_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _full = DrugCatalogItem(
    id: '1',
    name: 'Medve',
    activeIngredient: 'Levetiracetam',
    strength: '100mg/ml',
    dosageForm: 'Dung dịch uống',
    unit: 'ml');
const _many = DrugCatalogItem(
    id: '2',
    name: 'Me2B',
    activeIngredient:
        'Vitamin B1 (Thiamin nitrat) 125mg; Vitamin B12 (Mecobalamin) 500µg; '
        'Vitamin B6 (Pyridoxin HCl) 125mg; Vitamin E',
    strength: '125mg',
    dosageForm: 'Viên nén bao phim');
const _missing = DrugCatalogItem(
    id: '3', name: 'Melas', activeIngredient: '', strength: '', dosageForm: '');

void main() {
  Future<void> mount(WidgetTester tester) => tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: ListView(children: [
        for (final d in [_full, _many, _missing]) CatalogResultTile(item: d),
      ]))));

  testWidgets('mọi dòng cùng một khuôn: tên + hàm lượng / hoạt chất / dạng (AC24)',
      (tester) async {
    await mount(tester);
    for (final key in [
      'catalog-result-tile',
      'catalog-result-strength',
      'catalog-result-ingredients',
      'catalog-result-form',
    ]) {
      expect(find.byKey(Key(key)), findsNWidgets(3), reason: key);
    }
    expect(find.text('100 mg/ml'), findsOneWidget);
  });

  testWidgets('nhiều hoạt chất: hiện 2, dư thì "+N hoạt chất" (AC24)',
      (tester) async {
    await mount(tester);
    expect(find.textContaining('+2 hoạt chất'), findsOneWidget);
  });

  testWidgets('thiếu dữ liệu ghi rõ, không để số trơ hay trống (AC24)',
      (tester) async {
    await mount(tester);
    expect(find.text('Hoạt chất: Chưa có thông tin'), findsOneWidget);
    expect(find.text('Chưa rõ hàm lượng'), findsOneWidget);
    expect(find.text('Chưa có thông tin'), findsOneWidget); // dạng bào chế
  });

  test('ingredientSummary tách theo dấu ;', () {
    expect(CatalogResultTile.ingredientSummary(''), ('Chưa có thông tin', 0));
    expect(CatalogResultTile.ingredientSummary('A; B'), ('A; B', 0));
    expect(CatalogResultTile.ingredientSummary('A; B; C; D'), ('A; B', 2));
  });
}
