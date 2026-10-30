import '../../domain/entities/caregiver_failure.dart';

/// Tên hiển thị khi người dùng kia chưa có tên (server trả `null`).
const fallbackFamilyName = 'Người dùng DrugTime';

String familyDisplayName(String? name) => name ?? fallbackFamilyName;

/// Dải nhắc khi người dùng chưa bật `family_sharing`.
const familySharingConsentHint =
    'Cần bật "Chia sẻ với người thân" trong Quyền riêng tư để chấp thuận yêu cầu hoặc bật chia '
    'sẻ dữ liệu.';

/// Câu báo cho [kind]; `null` với 401 vì `ApiClient` đã đưa người dùng về màn Đăng nhập.
String? caregiverFailureMessage(CaregiverFailureKind kind) => switch (kind) {
      CaregiverFailureKind.forbidden => 'Bạn không có quyền thực hiện thao tác này.',
      CaregiverFailureKind.consentRequired => familySharingConsentHint,
      CaregiverFailureKind.notFound => 'Liên kết không còn tồn tại. Đang tải lại.',
      CaregiverFailureKind.conflict => 'Đã có thay đổi, đang tải lại.',
      CaregiverFailureKind.confirmationMissing =>
        'Liên kết này chưa có xác nhận đồng ý nên không bật chia sẻ được. Hãy hủy liên kết và '
            'để người thân gửi lại yêu cầu.',
      CaregiverFailureKind.documentOutdated =>
        'Nội dung đồng ý vừa được cập nhật. Vui lòng cập nhật ứng dụng rồi thử lại.',
      CaregiverFailureKind.network => 'Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.',
      CaregiverFailureKind.invalid ||
      CaregiverFailureKind.unknown =>
        'Đã có lỗi xảy ra. Vui lòng thử lại sau.',
      CaregiverFailureKind.unauthorized => null,
    };

// Việt Nam dùng UTC+7 quanh năm (không có giờ mùa hè), cùng cách reminder_occurrence_generator.
const _vietnamOffset = Duration(hours: 7);

String _two(int value) => value.toString().padLeft(2, '0');

/// `dd/MM/yyyy` theo giờ Việt Nam.
String formatVietnamDate(DateTime time) {
  final local = time.toUtc().add(_vietnamOffset);
  return '${_two(local.day)}/${_two(local.month)}/${local.year}';
}

/// `HH:mm dd/MM/yyyy` theo giờ Việt Nam.
String formatVietnamDateTime(DateTime time) {
  final local = time.toUtc().add(_vietnamOffset);
  return '${_two(local.hour)}:${_two(local.minute)} ${formatVietnamDate(time)}';
}
