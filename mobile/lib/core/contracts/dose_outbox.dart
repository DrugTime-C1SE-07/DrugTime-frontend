import '../storage/local_db/local_models.dart';

/// Contract quản lý hàng đợi gửi dữ liệu liều uống ngoại tuyến (Task 2.24 - SCRUM-54).
abstract class DoseOutbox {
  /// Đưa một lượt xác nhận liều vào hàng đợi lưu trữ cục bộ.
  ///
  /// - **Ai gọi:** Task 2.11 (Dose Confirmation UI khi người dùng bấm "Đã uống")
  ///   hoặc Task 2.07 (Notification action).
  /// - **Atomic Idempotent:** CÓ. Dựa vào SQLite UNIQUE(medication_schedule_id, scheduled_at).
  ///   Nếu lượt uống này đã tồn tại, trả về bản ghi cũ mà không ghi đè `taken_at`.
  Future<LocalDoseLog> enqueue({
    required int medicationScheduleId,
    required DateTime scheduledAt,
    required DateTime takenAt,
  });

  /// Lấy danh sách các liều đang chờ gửi lên server (`sync_state = 'pending_upload'`).
  ///
  /// - **Ai gọi:** Task 2.25 (Sync Engine).
  Future<List<LocalDoseLog>> getPendingLogs();

  /// Đánh dấu bản ghi đã gửi thành công lên Backend.
  ///
  /// - **Ai gọi:** Task 2.25 (Sync Engine).
  /// - Chuyển trạng thái sang `synced`, cập nhật `id = serverId`, `synced_at`.
  /// - Bỏ qua an toàn nếu `clientUuid` không tồn tại hoặc đã `synced`.
  Future<void> markSynced({
    required String clientUuid,
    required int? serverId,
    required DateTime syncedAt,
  });

  /// Đánh dấu bản ghi đồng bộ thất bại kèm nguyên nhân lỗi (lỗi 4xx vĩnh viễn).
  ///
  /// - **Ai gọi:** Task 2.25 (Sync Engine).
  /// - Chuyển trạng thái sang `failed` kèm `errorMessage`.
  /// - Bỏ qua an toàn nếu bản ghi đã `synced` hoặc không tồn tại.
  Future<void> markFailed({
    required String clientUuid,
    required String errorMessage,
  });

  /// Theo dõi trạng thái của một bản ghi liều cụ thể cho UI.
  ///
  /// - **Ai gọi:** Task 2.11 (Giao diện hiển thị trạng thái nút bấm/thẻ liều).
  /// - Emit trạng thái hiện tại ngay khi lắng nghe (trả về `null` nếu chưa có).
  /// - Chỉ emit khi trạng thái của đúng `clientUuid` đó thay đổi.
  Stream<DoseLogSyncState?> watchStatus(String clientUuid);

  /// Giải phóng tài nguyên StreamController nội bộ.
  Future<void> dispose();
}
