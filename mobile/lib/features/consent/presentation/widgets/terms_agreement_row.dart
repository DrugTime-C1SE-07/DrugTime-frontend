import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/app_theme.dart';

/// Ô tick "Tôi đồng ý với Điều khoản dịch vụ và Chính sách quyền riêng tư" (màn đăng nhập và màn
/// "Điều khoản đã cập nhật").
///
/// Cả dòng (cao tối thiểu 48dp) là vùng chạm đổi trạng thái; chạm link thì mở văn bản, không đổi
/// trạng thái. Ô tick thẳng mép trái với ô nhập và nút phía dưới; dòng lỗi căn giữa.
/// [onTermsTapped]/[onPrivacyTapped] thay cho việc mở route mặc định.
class TermsAgreementRow extends StatefulWidget {
  const TermsAgreementRow({
    super.key,
    required this.value,
    required this.onChanged,
    this.errorText,
    this.onTermsTapped,
    this.onPrivacyTapped,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? errorText;
  final VoidCallback? onTermsTapped;
  final VoidCallback? onPrivacyTapped;

  @override
  State<TermsAgreementRow> createState() => _TermsAgreementRowState();
}

class _TermsAgreementRowState extends State<TermsAgreementRow> {
  late final _terms = TapGestureRecognizer()..onTap = _openTerms;
  late final _privacy = TapGestureRecognizer()..onTap = _openPrivacy;

  static const _textStyle = TextStyle(fontSize: 13, height: 1.4, color: AppColors.ink);
  static const _linkStyle = TextStyle(
    color: AppColors.brand,
    fontWeight: FontWeight.w600,
    decoration: TextDecoration.underline,
  );

  @override
  void dispose() {
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  void _onToggle() => widget.onChanged?.call(!widget.value);

  void _openTerms() => widget.onTermsTapped != null
      ? widget.onTermsTapped!()
      : Navigator.of(context).pushNamed(AppRoutes.termsOfService);

  void _openPrivacy() => widget.onPrivacyTapped != null
      ? widget.onPrivacyTapped!()
      : Navigator.of(context).pushNamed(AppRoutes.privacyPolicy);

  @override
  Widget build(BuildContext context) {
    final errorText = widget.value ? null : widget.errorText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: widget.onChanged == null ? null : _onToggle,
          borderRadius: BorderRadius.circular(8.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSizes.tapTarget),
            child: Row(
              children: [
                // Ô tick gọn (không đệm 48dp) để thẳng mép trái; vùng chạm 48dp là cả dòng.
                Semantics(
                  label: 'Đồng ý Điều khoản dịch vụ và Chính sách quyền riêng tư',
                  child: SizedBox.square(
                    dimension: 24,
                    child: Checkbox(
                      key: const Key('terms-checkbox'),
                      value: widget.value,
                      onChanged: widget.onChanged == null
                          ? null
                          : (v) => widget.onChanged!(v ?? false),
                      activeColor: AppColors.brand,
                      isError: errorText != null,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: const VisualDensity(
                        horizontal: VisualDensity.minimumDensity,
                        vertical: VisualDensity.minimumDensity,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                    child: Text.rich(
                      TextSpan(
                        style: _textStyle,
                        children: [
                          const TextSpan(text: 'Tôi đồng ý với '),
                          TextSpan(
                            text: 'Điều khoản dịch vụ',
                            style: _linkStyle,
                            recognizer: _terms,
                          ),
                          const TextSpan(text: ' và '),
                          TextSpan(
                            text: 'Chính sách quyền riêng tư',
                            style: _linkStyle,
                            recognizer: _privacy,
                          ),
                          const TextSpan(text: ' của DrugTime.'),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              errorText,
              key: const Key('terms-error'),
              textAlign: TextAlign.center,
              style: _textStyle.copyWith(color: AppColors.danger),
            ),
          ),
      ],
    );
  }
}
