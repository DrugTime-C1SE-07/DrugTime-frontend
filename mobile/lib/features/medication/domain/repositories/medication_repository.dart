import '../entities/medication.dart';

/// Cổng dữ liệu thuốc của chính người dùng. Bản chạy thật gọi Backend API
/// (`RemoteMedicationRepository`); bản trong bộ nhớ dùng cho web và test.
///
/// Mọi thao tác ném `MedicationFailure` khi lỗi.
abstract interface class MedicationRepository {
  /// Thuốc chưa xoá, cả đang dùng và đã ngừng; thuốc thêm sau đứng trước.
  Future<List<Medication>> fetchAll();

  /// Thêm thuốc từ [draft] (bỏ qua `id`, `status`). Gửi lại cùng [clientUuid] không tạo
  /// thêm thuốc mà trả thuốc đã tạo lần đầu.
  Future<Medication> add(Medication draft, {required String clientUuid});

  /// Sửa liều, tần suất, giờ, cách uống, tồn kho: chỉ gửi phần [after] khác [before].
  Future<Medication> update(Medication before, Medication after);

  /// `true`: ngừng thuốc; `false`: dùng lại thuốc đã ngừng (mở lại giờ uống cũ).
  Future<Medication> setStopped(String id, bool stopped);

  /// Xoá thuốc; lịch sử liều đã ghi vẫn giữ trên server.
  Future<void> delete(String id);

  /// Tìm theo tên thuốc hoặc hoạt chất. Chuỗi rỗng trả danh sách rỗng.
  Future<List<DrugCatalogItem>> searchCatalog(String query);
}
