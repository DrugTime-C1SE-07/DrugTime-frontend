/// Consent theo mục đích của chính người dùng (`/consents`, api_contract/openapi.json).
library;

/// Phiên bản văn bản mô tả mục đích mà app đang hiển thị. Phải bằng
/// `current_document_version` mà server công bố; đổi câu chữ thì đổi phiên bản ở cả hai nơi.
const consentDocumentVersion = '2026-10-v1';

/// Phiên bản Điều khoản dịch vụ và Chính sách quyền riêng tư (`legal_texts.dart`). Tăng khi
/// văn bản đổi: người dùng đã đồng ý bản cũ sẽ được hỏi lại.
const termsDocumentVersion = '2026-10-v1';

/// Thứ tự khai báo là thứ tự server trả về.
enum ConsentPurpose {
  /// Bắt buộc: thuốc, lịch uống, lịch sử uống thuốc, cảnh báo tương tác, hồ sơ sức khỏe.
  healthData('health_data'),

  /// Tùy chọn: người thân có liên kết xem dữ liệu và nhận cảnh báo bỏ liều.
  familySharing('family_sharing'),

  /// Tùy chọn: gợi ý bữa ăn bằng AI.
  aiMeal('ai_meal'),

  /// Đồng ý Điều khoản dịch vụ và Chính sách quyền riêng tư. Không phải công tắc: chỉ đồng ý
  /// (ô tick lúc đăng nhập hoặc màn "Điều khoản đã cập nhật"), không rút được.
  terms('terms');

  const ConsentPurpose(this.apiValue);

  final String apiValue;

  /// Các mục đích có công tắc, theo thứ tự hiển thị (màn đồng ý, màn Quyền riêng tư).
  static const toggleable = [healthData, familySharing, aiMeal];

  bool get isRequired => this == ConsentPurpose.healthData;

  /// Phiên bản văn bản app gửi kèm khi đồng ý mục đích này.
  String get documentVersion =>
      this == ConsentPurpose.terms ? termsDocumentVersion : consentDocumentVersion;

  /// `null` khi server trả mục đích app chưa biết (server mới hơn app): bỏ qua, không lỗi.
  static ConsentPurpose? tryFromApi(String value) {
    for (final p in ConsentPurpose.values) {
      if (p.apiValue == value) return p;
    }
    return null;
  }
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
