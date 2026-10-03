import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_exception.dart';
import '../../domain/entities/consent.dart';
import '../../domain/entities/consent_failure.dart';
import '../../domain/repositories/consent_repository.dart';
import '../models/consent_api_mapper.dart';

/// Consent của người dùng qua Backend API (`/consents`).
class RemoteConsentRepository implements ConsentRepository {
  RemoteConsentRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<ConsentState>> fetchAll() => _guard(() async {
        final json = await _api.getJson('/consents');
        return ConsentApiMapper.consentListFromJson(json);
      });

  @override
  Future<ConsentState> grant(ConsentPurpose purpose) => _guard(() async {
        final json = await _api.postJson('/consents', body: ConsentApiMapper.grantBody(purpose));
        return ConsentApiMapper.consentFromJson(json as Map<String, dynamic>);
      });

  @override
  Future<ConsentState> withdraw(ConsentPurpose purpose) => _guard(() async {
        // Endpoint không đọc body; ApiClient chỉ có POST kèm body nên gửi JSON `null`.
        final json = await _api.postJson('/consents/${purpose.apiValue}/withdraw', body: null);
        return ConsentApiMapper.consentFromJson(json as Map<String, dynamic>);
      });

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on ApiException catch (error) {
      throw ConsentApiMapper.failureFrom(error);
    } on FormatException catch (error) {
      // Body không phải JSON đúng contract.
      throw ConsentFailure(ConsentFailureKind.unknown, error.message);
    }
  }
}
