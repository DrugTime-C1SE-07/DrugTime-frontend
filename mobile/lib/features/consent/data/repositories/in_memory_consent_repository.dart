import '../../domain/entities/consent.dart';
import '../../domain/repositories/consent_repository.dart';

/// Consent trong bộ nhớ: bản web xem thử và test. Mặc định đã đồng ý `health_data` và `terms`,
/// để app dựng không truyền repository vẫn vào thẳng Trang chủ như trước khi có luồng consent.
class InMemoryConsentRepository implements ConsentRepository {
  /// [grantedVersions]: phiên bản người dùng đã đồng ý của từng mục trong [granted], mặc định
  /// là phiên bản hiện hành (dùng để giả lập người dùng đã đồng ý điều khoản bản cũ).
  InMemoryConsentRepository({
    Set<ConsentPurpose> granted = const {ConsentPurpose.healthData, ConsentPurpose.terms},
    Map<ConsentPurpose, String> grantedVersions = const {},
  }) : _versions = {
          for (final p in granted) p: grantedVersions[p] ?? p.documentVersion,
        };

  /// Mục đã đồng ý → phiên bản đã đồng ý.
  final Map<ConsentPurpose, String> _versions;

  @override
  Future<List<ConsentState>> fetchAll() async =>
      [for (final p in ConsentPurpose.values) _state(p)];

  @override
  Future<ConsentState> grant(ConsentPurpose purpose) async {
    // Như server: terms bản cũ được thay bằng bản hiện hành; mục khác đã đồng ý thì giữ.
    if (purpose == ConsentPurpose.terms || !_versions.containsKey(purpose)) {
      _versions[purpose] = purpose.documentVersion;
    }
    return _state(purpose);
  }

  @override
  Future<ConsentState> withdraw(ConsentPurpose purpose) async {
    _versions.remove(purpose);
    return _state(purpose);
  }

  ConsentState _state(ConsentPurpose p) => ConsentState(
        purpose: p,
        granted: _versions.containsKey(p),
        documentVersion: _versions[p],
        currentDocumentVersion: p.documentVersion,
      );
}
