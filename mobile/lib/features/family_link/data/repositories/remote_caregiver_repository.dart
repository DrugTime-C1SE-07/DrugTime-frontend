import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_exception.dart';
import '../../domain/entities/caregiver.dart';
import '../../domain/entities/caregiver_failure.dart';
import '../../domain/entities/incoming_link_request.dart';
import '../../domain/repositories/caregiver_repository.dart';
import '../models/caregiver_api_mapper.dart';

/// Phía patient của liên kết người thân qua Backend API.
class RemoteCaregiverRepository implements CaregiverRepository {
  RemoteCaregiverRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<IncomingLinkRequest>> listPendingRequests() => _call(() async {
        final json = await _api.getJson('/family/links', query: {'status': 'pending'});
        return CaregiverApiMapper.pendingFromJson(json as Map<String, dynamic>);
      });

  @override
  Future<void> approve({
    required int linkId,
    required String familyUserId,
    required String documentVersion,
  }) =>
      _call(() => _api.postJson(
            '/family/links/$linkId/approve',
            body: CaregiverApiMapper.approveBody(
              familyUserId: familyUserId,
              documentVersion: documentVersion,
            ),
          ));

  // Server từ chối mọi body ở reject/revoke, kể cả `null`: dùng `post` không body.
  @override
  Future<void> reject(int linkId) => _call(() => _api.post('/family/links/$linkId/reject'));

  @override
  Future<List<Caregiver>> listCaregivers() => _call(() async {
        final json = await _api.getJson('/family/caregivers');
        return CaregiverApiMapper.caregiversFromJson(json as Map<String, dynamic>);
      });

  @override
  Future<Caregiver> setSharing(int linkId, {required bool enabled}) => _call(() async {
        final json = await _api.patchJson(
          '/family/links/$linkId/sharing',
          body: CaregiverApiMapper.sharingBody(enabled),
        );
        return CaregiverApiMapper.caregiverFromJson(json as Map<String, dynamic>);
      });

  @override
  Future<void> revoke(int linkId) => _call(() => _api.post('/family/links/$linkId/revoke'));

  Future<T> _call<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on ApiException catch (error) {
      throw CaregiverApiMapper.failureFrom(error);
    } on FormatException {
      // Body 2xx không phải JSON đúng contract.
      throw const CaregiverFailure(CaregiverFailureKind.unknown);
    } on TypeError {
      throw const CaregiverFailure(CaregiverFailureKind.unknown);
    }
  }
}
