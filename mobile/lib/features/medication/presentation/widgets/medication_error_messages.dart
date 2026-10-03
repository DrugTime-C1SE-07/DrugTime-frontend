import '../../domain/entities/medication_failure.dart';

/// Câu hiển thị cho người dùng ứng với lỗi của thao tác thuốc.
String medicationErrorMessage(MedicationFailure failure) => switch (failure.kind) {
      MedicationFailureKind.network =>
        'Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.',
      MedicationFailureKind.unauthorized =>
        'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
      MedicationFailureKind.forbidden => 'Bạn không có quyền thực hiện thao tác này.',
      MedicationFailureKind.consentRevoked =>
        'Bạn đã tắt đồng ý chia sẻ dữ liệu sức khỏe nên không thể quản lý thuốc. '
            'Bật lại trong phần Quyền riêng tư để tiếp tục.',
      MedicationFailureKind.notFound => 'Thuốc này không còn trong danh sách của bạn.',
      MedicationFailureKind.catalogNotFound =>
        'Thuốc này không còn trong danh mục. Vui lòng chọn thuốc khác.',
      MedicationFailureKind.ruleViolation =>
        'Thông tin liều và giờ uống chưa hợp lệ. Vui lòng kiểm tra lại.',
      MedicationFailureKind.stopped =>
        'Thuốc đang tạm ngừng. Hãy chọn "Tiếp tục dùng thuốc này" trước khi sửa.',
      MedicationFailureKind.validation =>
        'Thông tin nhập chưa hợp lệ. Vui lòng kiểm tra lại.',
      MedicationFailureKind.unknown => 'Đã có lỗi xảy ra. Vui lòng thử lại sau.',
    };
