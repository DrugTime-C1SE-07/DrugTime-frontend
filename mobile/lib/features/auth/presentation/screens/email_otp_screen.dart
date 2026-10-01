import 'package:flutter/material.dart';
import 'otp_verification_screen.dart';

/// S00c-otp-2 · Xác thực OTP (Email)
///
/// Tuân thủ quy cách thiết kế CSS từ Figma:
/// - Kích thước: 375x812, nền trắng #FFFFFF, bo góc 16px
/// - Status row 40px (#FCFCFC)
/// - Back arrow (24x24)
/// - MascotSlot 96x88 + Heading "Xác thực OTP" (20px bold) + Subheading email
/// - 6 ô nhập OTP (47x56px, bo góc 8px, viền 2px #01554F khi trỏ)
/// - Clock icon (14x14) + Đếm ngược gửi lại mã
/// - Nút Xác nhận (327x48px, nền #01554F)
/// - Sửa thông tin: "Sai email? Đổi email"
class EmailOtpScreen extends StatelessWidget {
  const EmailOtpScreen({
    super.key,
    this.email,
    this.enableFramePreview = false,
    this.onVerifySuccess,
  });

  final String? email;
  final bool enableFramePreview;
  final VoidCallback? onVerifySuccess;

  @override
  Widget build(BuildContext context) {
    return OtpVerificationScreen.email(
      email: email,
      enableFramePreview: enableFramePreview,
      onVerifySuccess: onVerifySuccess,
    );
  }
}
