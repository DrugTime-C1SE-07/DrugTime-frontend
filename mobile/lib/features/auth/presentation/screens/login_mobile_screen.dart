import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../consent/presentation/widgets/terms_agreement_row.dart';
import '../../domain/entities/login_method.dart';
import '../state/auth_controller.dart';
import '../widgets/email_input_field.dart';
import '../widgets/login_header.dart';
import '../widgets/login_segmented_picker.dart';
import '../widgets/phone_input_field.dart';
import '../widgets/trust_card.dart';

/// Screen: S00c · Đăng nhập (Số điện thoại / Email)
///
/// Tuân thủ quy cách thiết kế CSS từ Figma:
/// - Khung chứa: 375x812, nền [AppColors.surface] (#FFFFFF), viền 1px [AppColors.border], bo góc 16px
/// - Nội dung: padding 28px 24px 24px, gap 20px
/// - Header: ảnh mascot DrugTime cao 150px, heading 22px bold, subheading 13px
/// - Segmented Picker: 331x42px ([AppColors.surfaceMuted])
/// - Ô nhập dữ liệu: 327x48px (viền 1px [AppColors.border])
/// - Dòng phụ trợ: icon SMS (tab SĐT) hoặc thư (tab Email) 14px + chữ 11.5px, cao theo chữ
/// - Ô tick đồng ý Điều khoản và Chính sách, đặt ngay trên nút gửi; chưa tick thì không gửi OTP
/// - Nút bấm: 327x48px (nền thương hiệu [AppColors.brand] #01554F)
/// - Trust Card: 327x118px (nền [AppColors.brandTint] #E7F3F1)
/// Status bar và thanh điều hướng là của hệ điều hành (nội dung nằm trong [SafeArea]).
class LoginMobileScreen extends StatefulWidget {
  const LoginMobileScreen({
    super.key,
    this.onSubmitOtp,
    this.onTermsTapped,
    this.onPrivacyTapped,
    this.enableFramePreview = false,
  });

  final Future<void> Function(String identifier, LoginMethod method)?
      onSubmitOtp;
  final VoidCallback? onTermsTapped;
  final VoidCallback? onPrivacyTapped;
  final bool enableFramePreview;

  @override
  State<LoginMobileScreen> createState() => _LoginMobileScreenState();
}

class _LoginMobileScreenState extends State<LoginMobileScreen> {
  LoginMethod _localMethod = LoginMethod.phone;
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  String? _localPhoneError;
  String? _localEmailError;
  bool _localIsLoading = false;

  /// Dùng khi chạy độc lập (không có AuthScope); có controller thì đọc `termsAccepted` của nó.
  bool _localTermsAccepted = false;
  bool _showTermsError = false;

  static const _termsErrorText =
      'Vui lòng đồng ý Điều khoản dịch vụ và Chính sách quyền riêng tư';

  bool _termsAccepted(AuthController? controller) =>
      controller?.termsAccepted ?? _localTermsAccepted;

  void _setTermsAccepted(bool value, AuthController? controller) {
    if (controller != null) {
      controller.setTermsAccepted(value);
    }
    setState(() {
      _localTermsAccepted = value;
      if (value) _showTermsError = false;
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _onMethodChanged(LoginMethod method, AuthController? controller) {
    if (controller != null) {
      controller.setMethod(method);
    } else {
      setState(() {
        _localMethod = method;
        _localPhoneError = null;
        _localEmailError = null;
      });
    }
  }

  Future<void> _handleSendOtp(
    BuildContext context,
    LoginMethod activeMethod,
    AuthController? controller,
  ) async {
    FocusScope.of(context).unfocus();
    // Kiểm ô tick trước mọi bước khác: chưa đồng ý thì không gửi gì lên server.
    if (!_termsAccepted(controller)) {
      setState(() => _showTermsError = true);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final isPhone = activeMethod == LoginMethod.phone;
    final rawIdentifier =
        isPhone ? _phoneController.text.trim() : _emailController.text.trim();

    // Nếu có AuthController trong cây Widget (chuẩn Clean Architecture)
    if (controller != null) {
      final success = await controller.requestOtp(rawIdentifier);
      if (!mounted) return;

      if (success) {
        final infoMsg = controller.infoMessage ?? 'Đã gửi mã OTP thành công';
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(infoMsg),
              backgroundColor: AppColors.brand,
            ),
          );

        final targetRoute = isPhone ? AppRoutes.otpPhone : AppRoutes.otpEmail;
        final targetIdentifier = isPhone
            ? '+84 ${AuthValidator.cleanDigits(rawIdentifier)}'
            : rawIdentifier;
        navigator.pushNamed(
          targetRoute,
          arguments: targetIdentifier,
        );
      } else if (controller.errorMessage != null) {
        // Gán lỗi cho từng ô tương ứng nếu cần hiển thị tại trường nhập
        if (isPhone) {
          setState(() => _localPhoneError = controller.errorMessage);
        } else {
          setState(() => _localEmailError = controller.errorMessage);
        }
      }
      return;
    }

    // Chế độ chạy cục bộ độc lập (khi test widget đơn lẻ hoặc preview)
    setState(() {
      _localPhoneError = null;
      _localEmailError = null;
    });

    if (isPhone) {
      final clean = AuthValidator.cleanDigits(rawIdentifier);
      if (clean.isEmpty) {
        setState(() => _localPhoneError = 'Vui lòng nhập số điện thoại');
        return;
      }
      if (!AuthValidator.isValidPhone(clean)) {
        setState(() =>
            _localPhoneError = 'Số điện thoại không hợp lệ (9-11 chữ số)');
        return;
      }
    } else {
      if (rawIdentifier.isEmpty) {
        setState(() => _localEmailError = 'Vui lòng nhập địa chỉ email');
        return;
      }
      if (!AuthValidator.isValidEmail(rawIdentifier)) {
        setState(() => _localEmailError = 'Địa chỉ email không đúng định dạng');
        return;
      }
    }

    setState(() => _localIsLoading = true);

    try {
      if (widget.onSubmitOtp != null) {
        await widget.onSubmitOtp!(rawIdentifier, activeMethod);
      } else {
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          final displayTarget = isPhone
              ? '+84 ${AuthValidator.cleanDigits(rawIdentifier)}'
              : rawIdentifier;

          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text('Đã gửi mã OTP đến $displayTarget'),
                backgroundColor: AppColors.brand,
              ),
            );

          final targetRoute = isPhone ? AppRoutes.otpPhone : AppRoutes.otpEmail;
          navigator.pushNamed(
            targetRoute,
            arguments: displayTarget,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('Lỗi: ${e.toString()}'),
              backgroundColor: AppColors.danger,
            ),
          );
      }
    } finally {
      if (mounted) {
        setState(() => _localIsLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authController = AuthScope.maybeOf(context);
    final activeMethod = authController?.method ?? _localMethod;
    final isLoading = authController?.isLoading ?? _localIsLoading;
    final phoneError = activeMethod.isPhone
        ? (authController?.errorMessage ?? _localPhoneError)
        : null;
    final emailError = activeMethod.isEmail
        ? (authController?.errorMessage ?? _localEmailError)
        : null;

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
              activeMethod: activeMethod,
              isLoading: isLoading,
              phoneError: phoneError,
              emailError: emailError,
              controller: authController,
            ),
          ),
        ),
      );
    }

    // Hiển thị gốc trên điện thoại
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        body: SafeArea(
          child: _buildContent(
            context: context,
            activeMethod: activeMethod,
            isLoading: isLoading,
            phoneError: phoneError,
            emailError: emailError,
            controller: authController,
          ),
        ),
      ),
    );
  }

  Widget _buildContent({
    required BuildContext context,
    required LoginMethod activeMethod,
    required bool isLoading,
    required String? phoneError,
    required String? emailError,
    required AuthController? controller,
  }) {
    return Column(
      children: [
        // content (cuộn chống tràn khi mở bàn phím & chạm ngoài để ẩn phím)
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => FocusScope.of(context).unfocus(),
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24.0, 28.0, 24.0, 24.0),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 327.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // header (order: 0)
                      const LoginHeader(
                        heading: 'Đăng nhập',
                        subheading:
                            'Nhập số điện thoại hoặc email để quản lý lịch uống thuốc và chăm sóc sức khỏe an toàn.',
                      ),
                      const SizedBox(height: 20.0),

                      // SegmentedPicker/login-method (order: 1)
                      LoginSegmentedPicker(
                        selectedMethod: activeMethod,
                        onMethodChanged: (m) => _onMethodChanged(m, controller),
                      ),
                      const SizedBox(height: 20.0),

                      // field/phone or field/email (order: 2)
                      AnimatedCrossFade(
                        duration: const Duration(milliseconds: 200),
                        crossFadeState: activeMethod == LoginMethod.phone
                            ? CrossFadeState.showFirst
                            : CrossFadeState.showSecond,
                        firstChild: PhoneInputField(
                          controller: _phoneController,
                          errorMessage: phoneError,
                          enabled: !isLoading,
                          onChanged: (_) {
                            if (controller != null) controller.clearMessages();
                            if (_localPhoneError != null) {
                              setState(() => _localPhoneError = null);
                            }
                          },
                        ),
                        secondChild: EmailInputField(
                          controller: _emailController,
                          errorMessage: emailError,
                          enabled: !isLoading,
                          onChanged: (_) {
                            if (controller != null) controller.clearMessages();
                            if (_localEmailError != null) {
                              setState(() => _localEmailError = null);
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // helper-row (order: 3)
                      _buildHelperRow(activeMethod),
                      const SizedBox(height: AppSpacing.lg),

                      // terms (order: 4): đồng ý trước khi gửi OTP
                      TermsAgreementRow(
                        value: _termsAccepted(controller),
                        onChanged: isLoading
                            ? null
                            : (v) => _setTermsAccepted(v, controller),
                        errorText: _showTermsError ? _termsErrorText : null,
                        onTermsTapped: widget.onTermsTapped,
                        onPrivacyTapped: widget.onPrivacyTapped,
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // btn/send-otp (order: 5)
                      _buildSendOtpButton(
                          context, activeMethod, isLoading, controller),
                      const SizedBox(height: 20.0),

                      // trust-card (order: 6)
                      const TrustCard(),
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

  /// helper-row (order: 3). Không đặt chiều cao cố định: chữ phóng to thì dòng cao theo.
  Widget _buildHelperRow(LoginMethod activeMethod) {
    final isPhone = activeMethod == LoginMethod.phone;
    return SizedBox(
      key: const Key('login-helper-row'),
      width: 327.0,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            isPhone ? Icons.sms_outlined : Icons.mail_outline,
            size: 14.0,
            color: AppColors.inkMuted,
          ),
          const SizedBox(width: 6.0),
          Expanded(
            child: Text(
              isPhone
                  ? 'Mã OTP sẽ được gửi qua tin nhắn SMS'
                  : 'Mã OTP sẽ được gửi qua hòm thư điện tử',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w400,
                height: 17.0 / 11.5,
                color: AppColors.inkMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// btn/send-otp (order: 4)
  Widget _buildSendOtpButton(
    BuildContext context,
    LoginMethod activeMethod,
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
          onTap: isLoading
              ? null
              : () => _handleSendOtp(context, activeMethod, controller),
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
                    'Gửi mã OTP',
                    style: TextStyle(
                      fontSize: 15.0,
                      fontWeight: FontWeight.w500,
                      height: 22.0 / 15.0,
                      color: AppColors.onBrand,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
