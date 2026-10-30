import '../../domain/entities/medication.dart';

/// Synthetic catalog data for preview and tests; never used by repositories.
abstract final class DrugSelectionDemoFixtures {
  static const candidates = [
    DrugCatalogItem(
        id: 'demo-500',
        name: 'Thuốc mẫu Paracetamol',
        activeIngredient: 'Paracetamol',
        strength: '500 mg',
        dosageForm: 'Viên nén',
        unit: 'viên'),
    DrugCatalogItem(
        id: 'demo-250',
        name: 'Thuốc mẫu Paracetamol',
        activeIngredient: 'Paracetamol',
        strength: '250 mg',
        dosageForm: 'Gói bột',
        unit: 'gói'),
  ];

  static const missing = [
    DrugCatalogItem(
        id: 'demo-missing',
        name: 'Thuốc mẫu thiếu thông tin',
        activeIngredient: '',
        strength: '',
        dosageForm: '',
        unit: ''),
  ];

  static final longList = List<DrugCatalogItem>.unmodifiable([
    for (var i = 0; i < 30; i++)
      DrugCatalogItem(
          id: 'demo-long-$i',
          name: 'Thuốc mẫu $i với tên rất dài để kiểm tra khả năng đọc và cuộn',
          activeIngredient: 'Hoạt chất mẫu có tên dài',
          strength: '500 mg',
          dosageForm: 'Viên nén',
          unit: 'viên'),
  ]);

  static Future<List<DrugCatalogItem>> search(String query) async {
    final normalized = query.trim().toLowerCase();
    return candidates
        .where((item) =>
            item.name.toLowerCase().contains(normalized) ||
            item.activeIngredient.toLowerCase().contains(normalized))
        .toList(growable: false);
  }
}
