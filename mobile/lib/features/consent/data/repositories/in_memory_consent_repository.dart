import '../../domain/entities/consent.dart';
import '../../domain/repositories/consent_repository.dart';

/// Consent trong bộ nhớ: bản web xem thử và test. Mặc định đã đồng ý `health_data`, để app
/// dựng không truyền repository vẫn vào thẳng Trang chủ như trước khi có luồng consent.
class InMemoryConsentRepository implements ConsentRepository {
  InMemoryConsentRepository({Set<ConsentPurpose> granted = const {ConsentPurpose.healthData}})
      : _granted = {...granted};

  final Set<ConsentPurpose> _granted;

  @override
  Future<List<ConsentState>> fetchAll() async =>
      [for (final p in ConsentPurpose.values) _state(p)];

  @override
  Future<ConsentState> grant(ConsentPurpose purpose) async {
    _granted.add(purpose);
    return _state(purpose);
  }

  @override
  Future<ConsentState> withdraw(ConsentPurpose purpose) async {
    _granted.remove(purpose);
    return _state(purpose);
  }

  ConsentState _state(ConsentPurpose p) => ConsentState(
        purpose: p,
        granted: _granted.contains(p),
        documentVersion: _granted.contains(p) ? consentDocumentVersion : null,
      );
}
