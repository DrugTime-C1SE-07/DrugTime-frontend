import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/services.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/login_method.dart';
import '../state/auth_controller.dart';
import '../widgets/otp_header.dart';
import '../widgets/floating_pills.dart';
import '../widgets/mascot_protect_widget.dart';
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
    if (controller?.isLoading ?? false) return;
    final pin = _pinController.text.trim();
    if (!RegExp(r'^[0-9]{6}$').hasMatch(pin)) {
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
        _localErrorMessage =
            controller.errorMessage ?? 'Mã xác thực không đúng';
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
    if (controller?.isLoading ?? false) return;
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
    final errorMessage = _localErrorMessage;
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
    return PopScope(
      canPop: !isLoading,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: Colors.white,
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
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        children: [
          SizedBox(
            height: 196,
            width: double.infinity,
            child: ColoredBox(
                color: AppColors.brand,
                child: Stack(children: [
                  Positioned(
                      top: -120,
                      right: -110,
                      child: Container(
                        width: 300,
                        height: 300,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: .06)),
                      )),
                  const Positioned.fill(child: FloatingPills()),
                  const Center(child: MascotProtectWidget()),
                  Positioned(
                      top: 4,
                      left: 20,
                      child: _buildBackRow(context, isLoading)),
                ])),
          ),
          Container(
            color: AppColors.brand,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 26, 20, 36),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OtpHeader(
                          method: widget.method,
                          targetIdentifier: widget.targetIdentifier),
                      const SizedBox(height: 20),
                      OtpPinInput(
                        controller: _pinController,
                        focusNode: _pinFocusNode,
                        hasError: _localHasError,
                        enabled: !isLoading,
                        onChanged: (_) {
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
                        const SizedBox(height: 8),
                        Text(errorMessage,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.danger)),
                      ],
                      const SizedBox(height: 20),
                      if (isLoading)
                        const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2)),
                              SizedBox(width: 8),
                              Text('Đang xác thực…'),
                            ])
                      else
                        OtpResendRow(
                            initialCountdown: 60,
                            onResend: () => _handleResend(controller)),
                      if (!isLoading && _localHasError)
                        _buildVerifyButton(context, isLoading, controller),
                      const SizedBox(height: 12),
                      _buildWrongRow(isPhone, isLoading),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// back-row (order: 0, 327x44px - Touch target 44x44px accessible)
  Widget _buildBackRow(BuildContext context, bool isLoading) {
    return SizedBox(
      width: 48.0,
      height: 48.0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Semantics(
            button: true,
            label: 'Quay lại màn hình trước',
            child: Tooltip(
              message: 'Quay lại',
              child: InkWell(
                onTap:
                    isLoading ? null : () => Navigator.of(context).maybePop(),
                borderRadius: BorderRadius.circular(22.0),
                child: const SizedBox(
                  width: 48.0,
                  height: 48.0,
                  child: Center(
                    child: Icon(LucideIcons.arrowLeft,
                        size: 20.0, color: AppColors.ink),
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
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Material(
          color: isLoading
              ? AppColors.brand.withValues(alpha: 0.7)
              : AppColors.brand,
          borderRadius: BorderRadius.circular(8.0),
          child: InkWell(
            onTap: isLoading ? null : () => _handleVerify(controller),
            borderRadius: BorderRadius.circular(8.0),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                isLoading ? 'Đang xác thực…' : 'Xác nhận',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.onBrand,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWrongRow(bool isPhone, bool isLoading) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(isPhone ? 'Sai số điện thoại?' : 'Sai email?'),
        TextButton(
          onPressed: isLoading ? null : _handleChangeIdentifier,
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          child: Text(isPhone ? 'Đổi số' : 'Đổi email'),
        ),
      ],
    );
  }
}
