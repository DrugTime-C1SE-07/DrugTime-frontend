/// Consent theo mục đích của chính người dùng (`/consents`, api_contract/openapi.json).
library;

/// Phiên bản văn bản mô tả mục đích mà app đang hiển thị. Phải bằng
/// `current_document_version` mà server công bố; đổi câu chữ thì đổi phiên bản ở cả hai nơi.
const consentDocumentVersion = '2026-10-v1';

/// Thứ tự khai báo là thứ tự hiển thị và thứ tự server trả về.
enum ConsentPurpose {
  /// Bắt buộc: thuốc, lịch uống, lịch sử uống thuốc, cảnh báo tương tác, hồ sơ sức khỏe.
  healthData('health_data'),

  /// Tùy chọn: người thân có liên kết xem dữ liệu và nhận cảnh báo bỏ liều.
  familySharing('family_sharing'),

  /// Tùy chọn: gợi ý bữa ăn bằng AI.
  aiMeal('ai_meal');

  const ConsentPurpose(this.apiValue);

  final String apiValue;

  bool get isRequired => this == ConsentPurpose.healthData;

  static ConsentPurpose fromApi(String value) => ConsentPurpose.values.firstWhere(
        (p) => p.apiValue == value,
        orElse: () => throw FormatException('Unknown consent purpose: $value'),
      );
}

class ConsentState {
  const ConsentState({
    required this.purpose,
    required this.granted,
    this.grantedAt,
    this.documentVersion,
    this.currentDocumentVersion = consentDocumentVersion,
  });

  final ConsentPurpose purpose;
  final bool granted;
  final DateTime? grantedAt;

  /// Phiên bản người dùng đã đồng ý; `null` khi chưa đồng ý.
  final String? documentVersion;
  final String currentDocumentVersion;
}
