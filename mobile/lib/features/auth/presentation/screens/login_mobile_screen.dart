import 'package:flutter/material.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/widgets/home_indicator.dart';
import '../../../../core/widgets/status_bar_compact.dart';
import '../../../../core/widgets/vector_icons.dart';
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
/// - Status bar: 40px, [AppColors.canvas] (#FCFCFC)
/// - Nội dung: padding 28px 24px 24px, gap 20px
/// - Header: 60x60 logo y tế, heading 22px bold, subheading 13px
/// - Segmented Picker: 331x42px ([AppColors.surfaceMuted])
/// - Ô nhập dữ liệu: 327x48px (viền 1px [AppColors.border])
/// - Dòng phụ trợ: Icon 13x13 message-circle + chữ 11.5px
/// - Nút bấm: 327x48px (nền thương hiệu [AppColors.brand] #01554F)
/// - Trust Card: 327x118px (nền [AppColors.brandTint] #E7F3F1)
/// - Chân trang pháp lý: 11.5px [AppColors.inkMuted]
/// - Home indicator: 21px
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

    final isPhone = activeMethod == LoginMethod.phone;
    final rawIdentifier =
        isPhone ? _phoneController.text.trim() : _emailController.text.trim();

    // Nếu có AuthController trong cây Widget (chuẩn Clean Architecture)
    if (controller != null) {
      final success = await controller.requestOtp(rawIdentifier);
      if (!mounted) return;

      if (success) {
        final infoMsg = controller.infoMessage ?? 'Đã gửi mã OTP thành công';
        ScaffoldMessenger.of(context)
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
        Navigator.of(context).pushNamed(
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

          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text('Đã gửi mã OTP đến $displayTarget'),
                backgroundColor: AppColors.brand,
              ),
            );

          final targetRoute = isPhone ? AppRoutes.otpPhone : AppRoutes.otpEmail;
          Navigator.of(context).pushNamed(
            targetRoute,
            arguments: displayTarget,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
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

    final mediaQuery = MediaQuery.of(context);
    final isDesktopWidth = mediaQuery.size.width > 500;

    // Xem trước giao diện khung 375x812 trên Desktop/Web
    if (widget.enableFramePreview || isDesktopWidth) {
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
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        top: false,
        bottom: true,
        child: _buildContent(
          context: context,
          activeMethod: activeMethod,
          isLoading: isLoading,
          phoneError: phoneError,
          emailError: emailError,
          controller: authController,
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
        // order: 0 -> statusrow-slot (40px)
        const ExcludeSemantics(child: StatusBarCompact()),

        // order: 1 -> content (cuộn chống tràn khi mở bàn phím & chạm ngoài để ẩn phím)
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
                      const SizedBox(height: 20.0),

                      // btn/send-otp (order: 4)
                      _buildSendOtpButton(
                          context, activeMethod, isLoading, controller),
                      const SizedBox(height: 20.0),

                      // trust-card (order: 5)
                      const TrustCard(),
                      const SizedBox(height: 20.0),

                      // legal (order: 6)
                      _buildLegalText(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // order: 2 -> homeindicator-slot (21px)
        const ExcludeSemantics(child: HomeIndicator()),
      ],
    );
  }

  /// helper-row (order: 3)
  Widget _buildHelperRow(LoginMethod activeMethod) {
    return SizedBox(
      width: 327.0,
      height: 17.0,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const MessageCircleIcon(size: 13.0),
          const SizedBox(width: 6.0),
          Expanded(
            child: Text(
              activeMethod == LoginMethod.phone
                  ? 'Mã OTP sẽ được gửi qua tin nhắn SMS'
                  : 'Mã OTP sẽ được gửi qua hòm thư điện tử',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w400,
                height: 17.0 / 11.5,
                color: AppColors.inkMuted,
              ),
              overflow: TextOverflow.ellipsis,
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
        color: isLoading ? AppColors.brand.withOpacity(0.7) : AppColors.brand,
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

  /// legal text (order: 6)
  Widget _buildLegalText() {
    return SizedBox(
      width: 327.0,
      child: Text.rich(
        TextSpan(
          text: 'Bằng cách tiếp tục, bạn đồng ý với ',
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w400,
            height: 17.0 / 11.5,
            color: AppColors.inkMuted,
          ),
          children: [
            WidgetSpan(
              baseline: TextBaseline.alphabetic,
              alignment: PlaceholderAlignment.baseline,
              child: GestureDetector(
                onTap: widget.onTermsTapped,
                child: const Text(
                  'Điều khoản dịch vụ',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.brand,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
            const TextSpan(text: ' và '),
            WidgetSpan(
              baseline: TextBaseline.alphabetic,
              alignment: PlaceholderAlignment.baseline,
              child: GestureDetector(
                onTap: widget.onPrivacyTapped,
                child: const Text(
                  'Chính sách quyền riêng tư',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.brand,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
            const TextSpan(text: ' của DrugTime.'),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
