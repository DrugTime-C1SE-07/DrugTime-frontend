import 'package:flutter/material.dart';

import '../../../../app/router.dart';
import '../../domain/entities/medication_failure.dart';

/// Câu hiển thị cho người dùng ứng với lỗi của thao tác thuốc.
String medicationErrorMessage(MedicationFailure failure) => switch (failure.kind) {
      MedicationFailureKind.network =>
        'Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.',
      MedicationFailureKind.unauthorized =>
        'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
      MedicationFailureKind.forbidden => 'Bạn không có quyền thực hiện thao tác này.',
      MedicationFailureKind.consentRevoked =>
        'Để quản lý thuốc, DrugTime cần bạn đồng ý cho xử lý dữ liệu sức khỏe.',
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

/// Nhãn nút mời đồng ý khi lỗi là `consent_revoked`.
const consentActionLabel = 'Đồng ý';

/// Mở màn đồng ý xử lý dữ liệu (route `/onboarding/consent`).
Future<void> openConsentScreen(BuildContext context) =>
    Navigator.of(context).pushNamed<bool>(AppRoutes.consent);

/// SnackBar báo lỗi thao tác thuốc; lỗi `consent_revoked` có thêm nút mở màn đồng ý.
void showMedicationFailure(BuildContext context, MedicationFailure failure) {
  final consentRevoked = failure.kind == MedicationFailureKind.consentRevoked;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(medicationErrorMessage(failure)),
      action: consentRevoked
          ? SnackBarAction(
              key: const Key('consent-revoked-action'),
              label: consentActionLabel,
              onPressed: () => openConsentScreen(context),
            )
          : null,
    ));
}
