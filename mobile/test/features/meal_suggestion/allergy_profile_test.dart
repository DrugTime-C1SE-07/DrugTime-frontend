// AllergyProfile.toDeclaration: gửi đủ mọi dị ứng đã khai sang gợi ý món ăn
// (task adhoc-20261118-health-profile-catalog, AC9; review 06 H2).
import 'package:drugtime_mobile/features/meal_suggestion/domain/entities/allergy_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reported profile with 15 catalog + 30 custom allergies sends all 45 (AC9)', () {
    final catalog = [
      for (var i = 0; i < 15; i++) AllergyCatalogItem(id: 'a$i', name: 'Danh mục $i'),
    ];
    final custom = [for (var i = 0; i < 30; i++) 'Tự nhập $i'];
    final declaration = AllergyProfile(
      status: AllergyStatus.reported,
      catalogItems: catalog,
      customItems: custom,
    ).toDeclaration()!;

    expect(declaration.none, isFalse);
    expect(declaration.items, [...catalog.map((i) => i.name), ...custom]);
    expect(declaration.items, hasLength(45));
  });

  test('duplicates are removed case-insensitively, nothing else is dropped (AC9)', () {
    final declaration = const AllergyProfile(
      status: AllergyStatus.reported,
      catalogItems: [AllergyCatalogItem(id: 'seafood', name: 'Hải sản')],
      customItems: ['hải sản', ' Phấn hoa ', 'Mè'],
    ).toDeclaration()!;

    expect(declaration.items, ['Hải sản', 'Phấn hoa', 'Mè']);
  });
}
