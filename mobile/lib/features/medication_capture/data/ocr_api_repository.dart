import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_exception.dart';
import '../domain/ocr_models.dart';
import '../domain/ocr_ports.dart';

class RemoteOcrMatchingRepository implements OcrMatchingRepository {
  const RemoteOcrMatchingRepository(this._api);
  final ApiClient _api;
  @override
  Future<OcrMatchResult> match(String text,
      {required String sessionToken, int limit = 5}) async {
    validateOcrText(text, limit);
    if (sessionToken.isEmpty) {
      throw const OcrFailure(OcrFailureKind.unauthorized);
    }
    try {
      final value = await _api.postJson('/catalog/medications/match',
          body: {'text': text, 'limit': limit},
          sessionToken: sessionToken,
          expectedStatus: 200);
      return OcrMatchResult.fromJson(value, limit: limit);
    } on OcrFailure {
      rethrow;
    } on ApiException catch (e) {
      // Never expose the server body: validation responses can echo OCR input.
      throw OcrFailure(switch (e.statusCode) {
        401 => OcrFailureKind.unauthorized,
        422 => OcrFailureKind.validation,
        final int s when s >= 500 => OcrFailureKind.server,
        _ =>
          e.isTransient ? OcrFailureKind.network : OcrFailureKind.badResponse,
      });
    } on FormatException {
      throw const OcrFailure(OcrFailureKind.badResponse);
    }
  }
}

class UnavailableOcrMatchingRepository implements OcrMatchingRepository {
  const UnavailableOcrMatchingRepository();
  @override
  Future<OcrMatchResult> match(String text,
          {required String sessionToken, int limit = 5}) async =>
      throw const OcrFailure(OcrFailureKind.unavailable);
}
