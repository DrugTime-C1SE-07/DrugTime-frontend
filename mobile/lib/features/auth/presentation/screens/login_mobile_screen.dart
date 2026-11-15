import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/mascot/mascot_controller.dart';
import '../../../consent/presentation/widgets/terms_agreement_row.dart';
import '../../domain/entities/login_method.dart';
import '../state/auth_controller.dart';
import '../widgets/email_input_field.dart';
import '../widgets/login_hero.dart';
import '../widgets/login_segmented_picker.dart';
import '../widgets/phone_input_field.dart';
import '../widgets/pill_sky_scene.dart';

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

class _LoginMobileScreenState extends State<LoginMobileScreen>
    with SingleTickerProviderStateMixin {
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _mascot = MascotController();
  final _mascotKey = GlobalKey();
  final _fieldKey = GlobalKey();
  late final _intro = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2000));
  LoginMethod _method = LoginMethod.phone;
  bool _accepted = false;
  bool _showTermsError = false;
  bool _sending = false;
  String? _emailError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_reduceMotion) {
        _intro.value = 1;
      } else {
        _intro.forward();
      }
    });
  }

  @override
  void dispose() {
    _intro.dispose();
    _mascot.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  bool get _reduceMotion =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// Linh vật nhìn đúng vị trí con trỏ đang gõ trong ô nhập.
  void _lookAtCaret() {
    final field = _fieldKey.currentContext?.findRenderObject() as RenderBox?;
    final eyes = _mascotKey.currentContext?.findRenderObject() as RenderBox?;
    if (field == null || eyes == null || !field.attached || !eyes.attached) {
      return;
    }
    final text = (_method.isEmail ? _email : _phone).text;
    final painter = TextPainter(
      text: TextSpan(text: text, style: const TextStyle(fontSize: 16)),
      textDirection: TextDirection.ltr,
    )..layout();
    final prefix = _method.isEmail ? 48.0 : 104.0;
    final caret = field.localToGlobal(Offset(
        math.min(prefix + painter.width, field.size.width - 16),
        field.size.height / 2));
    painter.dispose();
    final eye = eyes.localToGlobal(
        Offset(eyes.size.width / 2, eyes.size.height * 114 / 300));
    final width = MediaQuery.sizeOf(context).width;
    _mascot.lookAt(
        Offset((caret.dx - eye.dx) / (width * .45), (caret.dy - eye.dy) / 220));
  }

  void _onFieldFocus(bool focused) {
    if (focused) {
      if (_mascot.mood == MascotMood.concerned) _mascot.play(MascotMood.idle);
      _lookAtCaret();
    } else {
      _mascot.clearLook();
    }
  }

  /// Sau khi gửi mã thành công: linh vật ăn mừng, chờ một nhịp rồi mới chuyển màn.
  Future<void> _celebrate() async {
    _mascot.play(MascotMood.celebrate);
    if (_reduceMotion) return;
    await Future<void>.delayed(const Duration(milliseconds: 450));
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
      _mascot.play(MascotMood.concerned);
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
        await _celebrate();
        if (!mounted) return;
        Navigator.of(context).pushNamed(AppRoutes.otpEmail, arguments: email);
      } else if (widget.onSubmitOtp case final submit?) {
        await submit(email, LoginMethod.email);
        if (mounted) _mascot.play(MascotMood.celebrate);
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
                SizedBox(
                  height: (constraints.maxHeight * .44).clamp(300.0, 400.0),
                  child: LoginHero(
                    entrance: _intro,
                    mascot: _mascot,
                    mascotKey: _mascotKey,
                  ),
                ),
                Expanded(
                  child: ColoredBox(
                    color: PillSkyScenePainter.skyBottom,
                    child: AnimatedBuilder(
                      animation: _intro,
                      // sheet trượt lên khi vào màn; chỉ đổi lúc vẽ, không đổi layout
                      builder: (context, child) {
                        final e = Curves.easeOutCubic.transform(
                            ((_intro.value - .48) / .4).clamp(0.0, 1.0));
                        return Transform.translate(
                          offset: Offset(0, (1 - e) * 160),
                          child: Opacity(
                              opacity: math.min(1.0, e * 1.6), child: child),
                        );
                      },
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
                                Focus(
                                  key: _fieldKey,
                                  canRequestFocus: false,
                                  skipTraversal: true,
                                  onFocusChange: _onFieldFocus,
                                  child: _method.isPhone
                                      ? PhoneInputField(
                                          controller: _phone,
                                          enabled: !sending,
                                          onChanged: (_) {
                                            setState(() {});
                                            _lookAtCaret();
                                          },
                                        )
                                      : AutofillGroup(
                                          child: EmailInputField(
                                            controller: _email,
                                            enabled: !sending,
                                            errorMessage: _emailError,
                                            onChanged: (_) {
                                              setState(
                                                  () => _emailError = null);
                                              _lookAtCaret();
                                            },
                                            onSubmitted: (_) => _send(auth),
                                          ),
                                        ),
                                ),
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
                                          if (value &&
                                              _mascot.mood ==
                                                  MascotMood.concerned) {
                                            _mascot.play(MascotMood.idle);
                                          }
                                        },
                                  errorText: _showTermsError
                                      ? 'Vui lòng đồng ý Điều khoản dịch vụ và Chính sách quyền riêng tư'
                                      : null,
                                  onTermsTapped: widget.onTermsTapped,
                                  onPrivacyTapped: widget.onPrivacyTapped,
                                ),
                                const SizedBox(height: 18),
                                // nút bám đáy sheet: khoảng trống dư nằm trên nút,
                                // không bỏ trống dưới nút (màn nhỏ vẫn cuộn như cũ)
                                const Spacer(),
                                FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.brand,
                                    elevation: 4,
                                    shadowColor:
                                        AppColors.brand.withValues(alpha: .35),
                                    minimumSize: const Size(0, 58),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(16)),
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.white,
        // sau thanh trạng thái: màu đỉnh trời; sau thanh điều hướng: trắng như sheet
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                PillSkyScenePainter.skyTop,
                PillSkyScenePainter.skyTop,
                Colors.white,
                Colors.white,
              ],
              stops: [0, .5, .5, 1],
            ),
          ),
          child: SafeArea(
            child: widget.enableFramePreview
                ? Center(
                    child: SizedBox(width: 375, height: 812, child: content))
                : content,
          ),
        ),
      ),
    );
  }
}
