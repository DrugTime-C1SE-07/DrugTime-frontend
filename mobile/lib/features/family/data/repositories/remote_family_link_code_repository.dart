import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_exception.dart';
import '../../domain/entities/family_link_code.dart';
import '../../domain/entities/family_link_code_failure.dart';
import '../../domain/repositories/family_link_code_repository.dart';

class RemoteFamilyLinkCodeRepository implements FamilyLinkCodeRepository {
  RemoteFamilyLinkCodeRepository(this._api);

  final ApiClient _api;

  @override
  Future<FamilyLinkCode> fetch() async {
    try {
      final json = await _api.getJson('/family/link-code');
      if (json is! Map<String, dynamic>) {
        throw const FamilyLinkCodeFailure(
            FamilyLinkCodeFailureKind.invalidResponse);
      }
      final code = json['code'];
      final qrPayload = json['qr_payload'];
      if (code is! String ||
          code.isEmpty ||
          qrPayload is! String ||
          qrPayload.isEmpty) {
        throw const FamilyLinkCodeFailure(
            FamilyLinkCodeFailureKind.invalidResponse);
      }
      return FamilyLinkCode(code: code, qrPayload: qrPayload);
    } on FamilyLinkCodeFailure {
      rethrow;
    } on ApiException catch (error) {
      final kind = switch (error.statusCode) {
        401 => FamilyLinkCodeFailureKind.unauthorized,
        403 => FamilyLinkCodeFailureKind.forbidden,
        503 => FamilyLinkCodeFailureKind.unavailable,
        _ when error.isTransient => FamilyLinkCodeFailureKind.network,
        _ => FamilyLinkCodeFailureKind.invalidResponse,
      };
      throw FamilyLinkCodeFailure(kind);
    } on FormatException {
      throw const FamilyLinkCodeFailure(
          FamilyLinkCodeFailureKind.invalidResponse);
    }
  }
}
