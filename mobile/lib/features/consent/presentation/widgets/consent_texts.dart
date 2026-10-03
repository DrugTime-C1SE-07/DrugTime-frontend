/// Văn bản mô tả từng mục đích, phiên bản `consentDocumentVersion` (2026-10-v1).
///
/// Bản nháp do agent soạn cho task 1.14; team duyệt câu chữ ở giai đoạn review. Đổi nội dung
/// thì tăng phiên bản ở `consent.dart` và ở backend (`CURRENT_DOCUMENT_VERSION`).
library;

import '../../domain/entities/consent.dart';
import '../../domain/entities/consent_failure.dart';

class ConsentText {
  const ConsentText({
    required this.title,
    required this.description,
    required this.withdrawTitle,
    required this.withdrawConsequence,
  });

  final String title;
  final String description;
  final String withdrawTitle;

  /// Hệ quả khi rút, hiện trong hộp xác nhận.
  final String withdrawConsequence;
}

const consentTexts = <ConsentPurpose, ConsentText>{
  ConsentPurpose.healthData: ConsentText(
    title: 'Dữ liệu sức khỏe',
    description: 'DrugTime lưu thuốc bạn dùng, giờ uống và lịch sử uống thuốc để nhắc đúng giờ, '
        'theo dõi việc dùng thuốc và cảnh báo tương tác thuốc. '
        'Bắt buộc để dùng các tính năng chính. Bạn có thể rút đồng ý trong phần Quyền riêng tư.',
    withdrawTitle: 'Rút đồng ý dữ liệu sức khỏe?',
    withdrawConsequence: 'Bạn sẽ không quản lý thuốc, xem lịch sử uống thuốc hay nhận cảnh báo '
        'tương tác được nữa. Người thân đang liên kết cũng mất quyền xem và không nhận cảnh báo '
        'bỏ liều. Dữ liệu đã lưu không bị xóa.',
  ),
  ConsentPurpose.familySharing: ConsentText(
    title: 'Chia sẻ với người thân',
    description: 'Cho người thân đã liên kết và được bạn bật chia sẻ xem thuốc, lịch sử uống '
        'thuốc của bạn và nhận cảnh báo khi bạn bỏ liều. Không bắt buộc.',
    withdrawTitle: 'Ngừng chia sẻ với người thân?',
    withdrawConsequence: 'Người thân sẽ không xem được dữ liệu của bạn và không nhận cảnh báo bỏ '
        'liều nữa. Liên kết với người thân vẫn được giữ.',
  ),
  ConsentPurpose.aiMeal: ConsentText(
    title: 'Gợi ý bữa ăn bằng AI',
    description: 'Dùng danh sách thuốc của bạn để gợi ý bữa ăn phù hợp, tránh thực phẩm tương '
        'tác với thuốc. Không bắt buộc.',
    withdrawTitle: 'Tắt gợi ý bữa ăn bằng AI?',
    withdrawConsequence: 'DrugTime sẽ không tạo gợi ý bữa ăn cho bạn nữa.',
  ),
};

String consentFailureMessage(ConsentFailure failure) => switch (failure.kind) {
      ConsentFailureKind.network => 'Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.',
      ConsentFailureKind.unauthorized => 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
      ConsentFailureKind.documentOutdated =>
        'Nội dung điều khoản vừa được cập nhật. Vui lòng cập nhật ứng dụng rồi thử lại.',
      ConsentFailureKind.unknown => 'Đã có lỗi xảy ra. Vui lòng thử lại sau.',
    };
