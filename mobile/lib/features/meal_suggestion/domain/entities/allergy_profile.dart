/// Hồ sơ dị ứng dùng cho gợi ý bữa ăn (task 5.11).
///
/// Hình dạng giống phần `allergies` của `GET /profile/health-setup` (nhánh hồ sơ sức khỏe):
/// trạng thái `unreported` / `none_known` / `reported`, dị ứng theo danh mục (id, tên) và dị ứng
/// tự nhập. Ở task này nguồn là mock; nối API thật sau (01 mục B).
library;

import 'meal_suggestion.dart';

enum AllergyStatus { unreported, noneKnown, reported }

class AllergyCatalogItem {
  const AllergyCatalogItem({required this.id, required this.name});

  final String id;
  final String name;
}

class AllergyProfile {
  const AllergyProfile({
    required this.status,
    this.catalogItems = const [],
    this.customItems = const [],
  });

  const AllergyProfile.unreported() : this(status: AllergyStatus.unreported);

  final AllergyStatus status;
  final List<AllergyCatalogItem> catalogItems;
  final List<String> customItems;

  /// `null` khi chưa khai: app không gọi API gợi ý (QD-40).
  DietaryDeclaration? toDeclaration() {
    switch (status) {
      case AllergyStatus.unreported:
        return null;
      case AllergyStatus.noneKnown:
        return const DietaryDeclaration.none();
      case AllergyStatus.reported:
        final seen = <String>{};
        final items = <String>[];
        for (final name in [
          ...catalogItems.map((i) => i.name),
          ...customItems,
        ]) {
          final trimmed = name.trim();
          if (trimmed.isEmpty || !seen.add(trimmed.toLowerCase())) continue;
          items.add(trimmed);
        }
        // `reported` mà rỗng là dữ liệu sai: coi như chưa khai, không tự coi là "không dị ứng".
        if (items.isEmpty) return null;
        return DietaryDeclaration.items(items);
    }
  }
}
