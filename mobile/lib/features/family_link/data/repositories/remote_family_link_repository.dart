import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_exception.dart';
import '../../domain/entities/link_request.dart';
import '../../domain/entities/link_request_failure.dart';
import '../../domain/repositories/family_link_repository.dart';
import '../models/link_request_api_mapper.dart';

/// Gửi yêu cầu liên kết qua Backend API (`POST /family/link-requests`, task 3.13).
class RemoteFamilyLinkRepository implements FamilyLinkRepository {
  RemoteFamilyLinkRepository(this._api);

  final ApiClient _api;

  @override
  Future<LinkRequest> sendLinkRequest({
    required String code,
    required String clientUuid,
  }) async {
    try {
      final json = await _api.postJson(
        '/family/link-requests',
        body: LinkRequestApiMapper.createBody(code: code, clientUuid: clientUuid),
      );
      return LinkRequestApiMapper.linkRequestFromJson(json as Map<String, dynamic>);
    } on ApiException catch (error) {
      throw LinkRequestApiMapper.failureFrom(error);
    } on FormatException {
      // Body 2xx không phải JSON đúng contract.
      throw const LinkRequestFailure(LinkRequestFailureKind.unknown);
    } on TypeError {
      throw const LinkRequestFailure(LinkRequestFailureKind.unknown);
    }
  }
}
