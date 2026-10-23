import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_exception.dart';
import '../../domain/entities/family_alert.dart';
import '../../domain/repositories/family_alert_repository.dart';

class RemoteFamilyAlertRepository implements FamilyAlertRepository {
  RemoteFamilyAlertRepository(this._client);
  final ApiClient _client;
  // Chuẩn hóa lỗi HTTP/parse để controller quyết định khi nào phải xóa dữ liệu cũ.
  Future<T> _request<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on FormatException {
      throw const FamilyAlertFailure('invalid_response');
    } on ApiException catch (e) {
      throw FamilyAlertFailure(switch (e.statusCode) {
        401 => 'unauthorized',
        403 => 'forbidden',
        404 => 'not_found',
        null => 'offline',
        _ => 'unavailable',
      });
    }
  }

  @override
  Future<FamilyAlertPage> list({int offset = 0, int limit = 20}) =>
      _request(() async => FamilyAlertPage.fromJson(await _client.getJson(
          '/notifications',
          query: {'offset': '$offset', 'limit': '$limit'})));
  Future<FamilyAlert> _item(int id, {bool patch = false}) => _request(() async {
        final value = patch
            ? await _client
                .patchJson('/notifications/$id', body: {'is_read': true})
            : await _client.getJson('/notifications/$id');
        final item = FamilyAlert.fromJson(value);
        // Chỉ nhận đúng cảnh báo và trạng thái đọc đã được server xác nhận.
        if (item.id != id || (patch && !item.isRead)) {
          throw const FormatException('Mismatched alert');
        }
        return item;
      });
  @override
  Future<FamilyAlert> detail(int id) => _item(id);
  @override
  Future<FamilyAlert> markRead(int id) => _item(id, patch: true);
}
