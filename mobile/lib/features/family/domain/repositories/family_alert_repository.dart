import '../entities/family_alert.dart';

class FamilyAlertFailure implements Exception {
  const FamilyAlertFailure(this.kind);
  final String kind;
  // Mất phiên/quyền/kết nối hoặc cảnh báo bị gỡ thì không hiển thị dữ liệu cũ.
  bool get clearsHealth => const [
        'unauthorized',
        'forbidden',
        'not_found',
        'offline'
      ].contains(kind);
  String get message => switch (kind) {
        'unauthorized' => 'Phiên đăng nhập đã hết hạn',
        'forbidden' || 'not_found' => 'Cảnh báo không còn khả dụng',
        'offline' => 'Không có kết nối. Vui lòng thử lại',
        _ => 'Không tải được cảnh báo. Vui lòng thử lại',
      };
}

// markRead trả bản ghi đã lưu trên server thay vì cập nhật lạc quan cục bộ.
abstract class FamilyAlertRepository {
  Future<FamilyAlertPage> list({int offset = 0, int limit = 20});
  Future<FamilyAlert> detail(int id);
  Future<FamilyAlert> markRead(int id);
}
