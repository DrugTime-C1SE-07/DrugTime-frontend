import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/widgets/vector_icons.dart';
import '../../domain/entities/login_method.dart';
import '../state/auth_controller.dart';
import '../widgets/otp_header.dart';
import '../widgets/otp_pin_input.dart';
import '../widgets/otp_resend_row.dart';

/// Màn hình:
/// - S00c-otp · Xác thực OTP (Số điện thoại)
/// - S00c-otp-2 · Xác thực OTP (Email)
///
/// Tuân thủ quy cách thiết kế CSS từ Figma:
/// - Kích thước: 375x812, nền [AppColors.surface] (#FFFFFF), viền 1px [AppColors.border], bo góc 16px
/// - Content: padding 24px, gap 20px, nền #FCFCFC
/// - Header: Mascot (96x88) + Heading (20px bold) + Subheading (13px)
/// - OTP Row: 6 ô (47x56px, bo góc 8px, viền 2px #01554F khi active)
/// - Resend Row: Icon Clock (14x14) + Đếm ngược / Gửi lại mã
/// - Nút Xác nhận: 327x48px (#01554F, bo góc 8px)
/// - Dòng sửa thông tin: "Sai số điện thoại? Đổi số" hoặc "Sai email? Đổi email"
/// Status bar và thanh điều hướng là của hệ điều hành (nội dung nằm trong [SafeArea]).
class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({
    super.key,
    required this.method,
    required this.targetIdentifier,
    this.enableFramePreview = false,
    this.onVerifySuccess,
  });

  /// Khởi tạo tiện lợi cho màn hình xác thực OTP qua Số điện thoại (S00c-otp)
  const OtpVerificationScreen.phone({
    Key? key,
    String? phoneNumber,
    bool enableFramePreview = false,
    VoidCallback? onVerifySuccess,
  }) : this(
          key: key,
          method: LoginMethod.phone,
          targetIdentifier: phoneNumber ?? '904****87',
          enableFramePreview: enableFramePreview,
          onVerifySuccess: onVerifySuccess,
        );

  /// Khởi tạo tiện lợi cho màn hình xác thực OTP qua Email (S00c-otp-2)
  const OtpVerificationScreen.email({
    Key? key,
    String? email,
    bool enableFramePreview = false,
    VoidCallback? onVerifySuccess,
  }) : this(
          key: key,
          method: LoginMethod.email,
          targetIdentifier: email ?? 'viet****@gmail.com',
          enableFramePreview: enableFramePreview,
          onVerifySuccess: onVerifySuccess,
        );

  final LoginMethod method;
  final String targetIdentifier;
  final bool enableFramePreview;
  final VoidCallback? onVerifySuccess;

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final TextEditingController _pinController = TextEditingController();
  final FocusNode _pinFocusNode = FocusNode();

  bool _localHasError = false;
  String? _localErrorMessage;

  @override
  void dispose() {
    _pinController.dispose();
    _pinFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleVerify(AuthController? controller) async {
    final pin = _pinController.text.trim();
    if (pin.length < 6) {
      setState(() {
        _localHasError = true;
        _localErrorMessage = 'Vui lòng nhập đủ 6 chữ số mã OTP';
      });
      return;
    }

    FocusScope.of(context).unfocus();

    if (controller == null) {
      // Không có AuthScope phía trên (chỉ xảy ra khi dựng màn hình lẻ): không giả lập đăng nhập.
      setState(() {
        _localHasError = true;
        _localErrorMessage = 'Chưa kết nối được dịch vụ đăng nhập';
      });
      return;
    }

    final success = await controller.verifyOtp(token: pin);
    if (!mounted) return;

    if (success) {
      _showSuccessAndNavigate(needsProfile: controller.needsProfile);
    } else {
      setState(() {
        _localHasError = true;
        _localErrorMessage = controller.errorMessage ?? 'Mã xác thực không đúng';
      });
    }
  }

  void _showSuccessAndNavigate({required bool needsProfile}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Xác thực OTP thành công!'),
          backgroundColor: AppColors.brand,
        ),
      );

    if (widget.onVerifySuccess case final callback?) {
      callback();
    } else {
      // Người mới (chưa có hồ sơ) đi qua màn hoàn thiện hồ sơ trước khi vào Trang chủ.
      Navigator.of(context).pushNamedAndRemoveUntil(
        needsProfile ? AppRoutes.completeProfile : AppRoutes.home,
        (route) => false,
      );
    }
  }

  Future<void> _handleResend(AuthController? controller) async {
    setState(() {
      _pinController.clear();
      _localHasError = false;
      _localErrorMessage = null;
    });
    _pinFocusNode.requestFocus();

    final isPhone = widget.method == LoginMethod.phone;
    final maskedTarget = isPhone
        ? AuthValidator.maskPhone(widget.targetIdentifier)
        : AuthValidator.maskEmail(widget.targetIdentifier);
    final targetLabel = isPhone ? 'số $maskedTarget' : maskedTarget;

    if (controller == null) {
      setState(() {
        _localHasError = true;
        _localErrorMessage = 'Chưa kết nối được dịch vụ đăng nhập';
      });
      return;
    }

    final sent = await controller.resendOtp();
    if (!mounted) return;
    if (!sent) {
      setState(() {
        _localHasError = true;
        _localErrorMessage = controller.errorMessage;
      });
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Đã gửi lại mã OTP đến $targetLabel'),
          backgroundColor: AppColors.brand,
        ),
      );
  }

  void _handleChangeIdentifier() {
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final authController = AuthScope.maybeOf(context);
    final isLoading = authController?.isLoading ?? false;
    final errorMessage = _localErrorMessage ?? authController?.errorMessage;
    final isPhone = widget.method == LoginMethod.phone;

    // Xem trước giao diện khung 375x812 (chỉ khi bật cờ, ví dụ trên Desktop/Web)
    if (widget.enableFramePreview) {
      return Scaffold(
        backgroundColor: const Color(0xFFEFEFEF),
        body: Center(
          child: Container(
            width: 375.0,
            height: 812.0,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppColors.border, width: 1.0),
              boxShadow: AppShadows.frameElevation,
            ),
            child: _buildContent(
              context: context,
              controller: authController,
              isLoading: isLoading,
              errorMessage: errorMessage,
              isPhone: isPhone,
            ),
          ),
        ),
      );
    }

    // Hiển thị gốc trên điện thoại di động
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        body: SafeArea(
          child: _buildContent(
            context: context,
            controller: authController,
            isLoading: isLoading,
            errorMessage: errorMessage,
            isPhone: isPhone,
          ),
        ),
      ),
    );
  }

  Widget _buildContent({
    required BuildContext context,
    required AuthController? controller,
    required bool isLoading,
    required String? errorMessage,
    required bool isPhone,
  }) {
    return Column(
      children: [
        // content (padding 24px, gap 20px)
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => FocusScope.of(context).unfocus(),
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 327.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // back-row (order: 0)
                      _buildBackRow(context),
                      const SizedBox(height: 4.0),

                      // header (order: 1)
                      OtpHeader(
                        method: widget.method,
                        targetIdentifier: widget.targetIdentifier,
                      ),
                      const SizedBox(height: 20.0),

                      // otp-row (order: 2)
                      OtpPinInput(
                        controller: _pinController,
                        focusNode: _pinFocusNode,
                        hasError: _localHasError,
                        enabled: !isLoading,
                        onChanged: (val) {
                          if (_localHasError) {
                            setState(() {
                              _localHasError = false;
                              _localErrorMessage = null;
                            });
                          }
                        },
                        onCompleted: (_) => _handleVerify(controller),
                      ),

                      if (errorMessage != null) ...[
                        const SizedBox(height: 8.0),
                        Text(
                          errorMessage,
                          style: const TextStyle(
                            fontSize: 12.0,
                            fontWeight: FontWeight.w400,
                            color: AppColors.danger,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 20.0),

                      // resend-row (order: 3)
                      OtpResendRow(
                        initialCountdown: 60,
                        onResend: () => _handleResend(controller),
                      ),
                      const SizedBox(height: 20.0),

                      // btn/verify or btn/verify-email (order: 4)
                      _buildVerifyButton(context, isLoading, controller),
                      const SizedBox(height: 20.0),

                      // wrong-row (order: 5)
                      _buildWrongRow(isPhone),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// back-row (order: 0, 327x44px - Touch target 44x44px accessible)
  Widget _buildBackRow(BuildContext context) {
    return SizedBox(
      width: 327.0,
      height: 44.0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Semantics(
            button: true,
            label: 'Quay lại màn hình trước',
            child: Tooltip(
              message: 'Quay lại',
              child: InkWell(
                onTap: () => Navigator.of(context).maybePop(),
                borderRadius: BorderRadius.circular(22.0),
                child: const SizedBox(
                  width: 44.0,
                  height: 44.0,
                  child: Center(
                    child: ArrowLeftIcon(size: 20.0, color: AppColors.ink),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// btn/verify (order: 4, 327x48px, #01554F, 8px radius)
  Widget _buildVerifyButton(
    BuildContext context,
    bool isLoading,
    AuthController? controller,
  ) {
    return SizedBox(
      width: 327.0,
      height: 48.0,
      child: Material(
        color: isLoading ? AppColors.brand.withValues(alpha: 0.7) : AppColors.brand,
        borderRadius: BorderRadius.circular(8.0),
        child: InkWell(
          onTap: isLoading ? null : () => _handleVerify(controller),
          borderRadius: BorderRadius.circular(8.0),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 20.0,
                    height: 20.0,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.0,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Xác nhận',
                    style: TextStyle(
                      fontSize: 15.0,
                      fontWeight: FontWeight.w500,
                      height: 22.0 / 15.0,
                      color: AppColors.onBrand,
                      fontFamily: 'Inter',
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  /// wrong-row (order: 5, 327x19px)
  Widget _buildWrongRow(bool isPhone) {
    final queryText = isPhone ? 'Sai số điện thoại?' : 'Sai email?';
    final ctaText = isPhone ? 'Đổi số' : 'Đổi email';

    return SizedBox(
      width: 327.0,
      height: 19.0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            queryText,
            style: const TextStyle(
              fontSize: 13.0,
              fontWeight: FontWeight.w400,
              height: 19.0 / 13.0,
              color: AppColors.inkMuted,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(width: 4.0),
          GestureDetector(
            onTap: _handleChangeIdentifier,
            child: Text(
              ctaText,
              style: const TextStyle(
                fontSize: 13.0,
                fontWeight: FontWeight.w500,
                height: 19.0 / 13.0,
                color: AppColors.brand,
                fontFamily: 'Inter',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
