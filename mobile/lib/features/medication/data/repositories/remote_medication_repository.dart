import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_exception.dart';
import '../../domain/entities/medication.dart';
import '../../domain/entities/medication_failure.dart';
import '../../domain/repositories/medication_repository.dart';
import '../models/medication_api_mapper.dart';

/// Thuốc của người dùng qua Backend API (`/medications`, `/catalog/medications`).
/// Quyền được server kiểm ở mỗi request; app không giữ quyết định phân quyền.
class RemoteMedicationRepository implements MedicationRepository {
  RemoteMedicationRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<Medication>> fetchAll() => _guard(() async {
        final json = await _api.getJson('/medications');
        return MedicationApiMapper.medicationListFromJson(json);
      });

  @override
  Future<Medication> add(Medication draft, {required String clientUuid}) => _guard(() async {
        final json = await _api.postJson(
          '/medications',
          body: MedicationApiMapper.createBody(draft, clientUuid),
        );
        return MedicationApiMapper.medicationFromJson(json as Map<String, dynamic>);
      });

  @override
  Future<Medication> update(Medication before, Medication after) => _guard(() async {
        final body = MedicationApiMapper.patchBody(before, after);
        // Server trả 422 với body rỗng; không có gì đổi thì không gọi.
        if (body.isEmpty) return before;
        final json = await _api.patchJson('/medications/${before.id}', body: body);
        return MedicationApiMapper.medicationFromJson(json as Map<String, dynamic>);
      });

  @override
  Future<Medication> setStopped(String id, bool stopped) => _guard(() async {
        final json = await _api.patchJson('/medications/$id', body: {'stopped': stopped});
        return MedicationApiMapper.medicationFromJson(json as Map<String, dynamic>);
      });

  @override
  Future<void> delete(String id) async {
    try {
      await _api.delete('/medications/$id');
    } on ApiException catch (error) {
      // Theo contract: gửi lại sau lỗi mạng mà nhận 404 nghĩa là lần trước đã xoá xong.
      if (error.statusCode == 404) return;
      throw MedicationApiMapper.failureFrom(error);
    }
  }

  @override
  Future<List<DrugCatalogItem>> searchCatalog(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    return _guard(() async {
      final json = await _api.getJson('/catalog/medications', query: {'q': q});
      return MedicationApiMapper.catalogListFromJson(json);
    });
  }

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on ApiException catch (error) {
      throw MedicationApiMapper.failureFrom(error);
    } on FormatException catch (error) {
      // Body không phải JSON đúng contract.
      throw MedicationFailure(MedicationFailureKind.unknown, error.message);
    }
  }
}
