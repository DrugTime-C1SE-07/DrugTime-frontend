import '../entities/medication.dart';

/// Cổng dữ liệu thuốc. Bản hiện tại chạy trong bộ nhớ; sau này thay bằng
/// local DB + đồng bộ API mà không phải sửa tầng presentation.
abstract interface class MedicationRepository {
  Future<List<Medication>> fetchAll();

  Future<void> add(Medication medication);

  Future<void> update(Medication medication);

  Future<void> delete(String id);

  /// Tìm theo tên thuốc hoặc hoạt chất; chuỗi rỗng trả về toàn bộ danh mục.
  Future<List<DrugCatalogItem>> searchCatalog(String query);

  Future<DrugCatalogItem?> findCatalogItem(String catalogId);
}
