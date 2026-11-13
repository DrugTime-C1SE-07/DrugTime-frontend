import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../consent/presentation/widgets/terms_agreement_row.dart';
import '../../domain/entities/login_method.dart';
import '../state/auth_controller.dart';
import '../widgets/email_input_field.dart';
import '../widgets/login_header.dart';
import '../widgets/login_segmented_picker.dart';
import '../widgets/phone_input_field.dart';

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
  final _email = TextEditingController();
  final _phone = TextEditingController();
  LoginMethod _method = LoginMethod.phone;
  bool _accepted = false;
  bool _showTermsError = false;
  bool _sending = false;
  String? _emailError;

  @override
  void dispose() {
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _select(LoginMethod method) {
    FocusScope.of(context).unfocus();
    setState(() {
      _method = method;
      _emailError = null;
    });
  }

  Future<void> _send(AuthController? auth) async {
    if (_sending || !_method.isEmail || (auth?.isLoading ?? false)) return;
    if (!(auth?.termsAccepted ?? _accepted)) {
      setState(() => _showTermsError = true);
      return;
    }

    final email = _email.text.trim();
    if (!AuthValidator.isValidEmail(email)) {
      setState(
        () => _emailError = email.isEmpty
            ? 'Vui lòng nhập địa chỉ email'
            : 'Địa chỉ email không đúng định dạng',
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _sending = true;
      _emailError = null;
    });
    try {
      if (auth != null) {
        auth.setMethod(LoginMethod.email);
        final sent = await auth.requestOtp(email);
        if (!mounted) return;
        if (!sent) {
          setState(() => _emailError = auth.errorMessage);
          return;
        }
        Navigator.of(context).pushNamed(AppRoutes.otpEmail, arguments: email);
      } else if (widget.onSubmitOtp case final submit?) {
        await submit(email, LoginMethod.email);
      } else {
        setState(() => _emailError = 'Chưa kết nối được dịch vụ đăng nhập');
      }
    } on Exception {
      if (mounted) {
        setState(
          () => _emailError = 'Không gửi được mã OTP. Vui lòng thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.maybeOf(context);
    final sending = _sending || (auth?.isLoading ?? false);
    final content = LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(
            child: Column(
              children: [
                const ColoredBox(
                    color: Color(0xFF01554F), child: LoginHeader()),
                Expanded(
                  child: Container(
                    color: const Color(0xFF01554F),
                    child: Container(
                      key: const Key('login-sheet'),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(32)),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: .16),
                              blurRadius: 20,
                              offset: const Offset(0, -4))
                        ],
                      ),
                      padding: const EdgeInsets.fromLTRB(20, 26, 20, 30),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 430),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Đăng nhập',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 30,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.ink)),
                              const SizedBox(height: 18),
                              LoginSegmentedPicker(
                                selectedMethod: _method,
                                onMethodChanged: sending ? null : _select,
                              ),
                              const SizedBox(height: 18),
                              if (_method.isPhone) ...[
                                PhoneInputField(
                                  controller: _phone,
                                  enabled: !sending,
                                  onChanged: (_) => setState(() {}),
                                ),
                              ] else ...[
                                AutofillGroup(
                                  child: EmailInputField(
                                    controller: _email,
                                    enabled: !sending,
                                    errorMessage: _emailError,
                                    onChanged: (_) =>
                                        setState(() => _emailError = null),
                                    onSubmitted: (_) => _send(auth),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              TermsAgreementRow(
                                value: auth?.termsAccepted ?? _accepted,
                                onChanged: sending
                                    ? null
                                    : (value) {
                                        auth?.setTermsAccepted(value);
                                        setState(() {
                                          _accepted = value;
                                          if (value) _showTermsError = false;
                                        });
                                      },
                                errorText: _showTermsError
                                    ? 'Vui lòng đồng ý Điều khoản dịch vụ và Chính sách quyền riêng tư'
                                    : null,
                                onTermsTapped: widget.onTermsTapped,
                                onPrivacyTapped: widget.onPrivacyTapped,
                              ),
                              const SizedBox(height: 18),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.brand,
                                  elevation: 4,
                                  shadowColor:
                                      AppColors.brand.withValues(alpha: .35),
                                  minimumSize: const Size(0, 58),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                ),
                                onPressed: sending ||
                                        _method.isPhone ||
                                        _email.text.trim().isEmpty
                                    ? null
                                    : () => _send(auth),
                                child: sending
                                    ? const Text('Đang gửi mã…')
                                    : const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                            Text('Nhận mã OTP'),
                                            SizedBox(width: 10),
                                            Icon(LucideIcons.arrowRight,
                                                size: 20)
                                          ]),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: widget.enableFramePreview
              ? Center(child: SizedBox(width: 375, height: 812, child: content))
              : content,
        ),
      ),
    );
  }
}
