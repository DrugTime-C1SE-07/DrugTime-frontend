import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_exception.dart';
import '../../domain/entities/condition.dart';
import '../../domain/entities/health_profile.dart';
import '../../domain/entities/profile_failure.dart';
import '../../domain/repositories/profile_repository.dart';
import '../models/profile_api_mapper.dart';

class RemoteProfileRepository implements ProfileRepository {
  RemoteProfileRepository(this._api);
  final ApiClient _api;
  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on ApiException catch (error) {
      throw ProfileApiMapper.failure(error);
    } on FormatException {
      throw const ProfileFailure(ProfileFailureKind.invalidResponse);
    } on TypeError {
      throw const ProfileFailure(ProfileFailureKind.invalidResponse);
    }
  }

  @override
  Future<HealthProfile> fetch() => _guard(
      () async => ProfileApiMapper.profile(await _api.getJson('/profile')));
  @override
  Future<void> update(ProfileDraft draft) => _guard(() async {
        await _api.putJson('/profile',
            body: ProfileApiMapper.updateBody(draft));
      });
  @override
  Future<ConditionPage> catalog({required int offset, int limit = 20}) =>
      _guard(() async => ProfileApiMapper.page(await _api.getJson('/conditions',
          query: {'offset': '$offset', 'limit': '$limit'})));
  @override
  Future<ProfileCondition> addCondition(int conditionId) => _guard(() async =>
      ProfileApiMapper.condition(await _api.postJson('/profile/conditions',
          body: {'condition_id': conditionId})));
  @override
  Future<ProfileCondition> updateCondition(
          int linkId, Map<String, String?> changes) =>
      _guard(() async => ProfileApiMapper.condition(
          await _api.patchJson('/profile/conditions/$linkId', body: changes)));
  @override
  Future<void> deleteCondition(int linkId) => _guard(() async {
        await _api.delete('/profile/conditions/$linkId');
      });
}
