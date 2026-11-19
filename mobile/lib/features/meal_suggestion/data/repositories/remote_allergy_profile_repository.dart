import '../../../../core/api/api_client.dart';
import '../../domain/entities/allergy_profile.dart';
import '../../domain/repositories/allergy_profile_repository.dart';

/// Hồ sơ dị ứng thật của chính người dùng, đọc từ phần `allergies` của
/// `GET /profile/health-setup`.
///
/// Tên dị ứng danh mục lấy từ `catalog_items` (backend trả cả mục đã ngừng dùng), nên không
/// cần gọi thêm `GET /allergens` và không làm rơi dị ứng đã khai khỏi khai báo gửi đi.
/// Lỗi mạng, lỗi API hay dữ liệu sai hình dạng đều ném lỗi: `MealPlanController` coi là
/// "tải hồ sơ dị ứng thất bại" và không gọi API gợi ý, không suy ra "không dị ứng" (QD-40).
class RemoteAllergyProfileRepository implements AllergyProfileRepository {
  RemoteAllergyProfileRepository(this._api);

  final ApiClient _api;

  static const _path = '/profile/health-setup';

  @override
  Future<AllergyProfile> load() async {
    final body = await _api.getJson(_path);
    if (body is! Map<String, dynamic>) {
      throw const FormatException('Health setup must be an object');
    }
    final allergies = body['allergies'];
    if (allergies is! Map<String, dynamic>) {
      throw const FormatException('Missing allergies step');
    }
    return switch (allergies['status']) {
      'unreported' => const AllergyProfile.unreported(),
      'none_known' => const AllergyProfile(status: AllergyStatus.noneKnown),
      'reported' => _reported(allergies),
      _ => throw const FormatException('Unknown allergies status'),
    };
  }

  AllergyProfile _reported(Map<String, dynamic> json) {
    final ids = json['catalog_ids'];
    final items = json['catalog_items'];
    final custom = json['custom_names'];
    if (ids is! List || items is! List || custom is! List) {
      throw const FormatException('Incomplete reported allergies');
    }
    final catalogItems = [
      for (final item in items)
        if (item case {'id': final String id, 'name': final String name})
          AllergyCatalogItem(id: id, name: name)
        else
          throw const FormatException('Invalid allergen catalog item'),
    ];
    // Mỗi id đã lưu phải có nhãn; thiếu nhãn thì không được âm thầm bỏ dị ứng đó.
    final labelled = {for (final item in catalogItems) item.id};
    if (ids.length != catalogItems.length ||
        !ids.every((id) => id is String && labelled.contains(id))) {
      throw const FormatException('Allergen labels do not match catalog_ids');
    }
    return AllergyProfile(
      status: AllergyStatus.reported,
      catalogItems: catalogItems,
      customItems: [
        for (final name in custom)
          if (name is String)
            name
          else
            throw const FormatException('Invalid custom allergy name'),
      ],
    );
  }
}
