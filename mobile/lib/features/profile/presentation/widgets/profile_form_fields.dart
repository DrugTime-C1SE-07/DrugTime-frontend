import 'package:flutter/material.dart';
import '../../../../app/theme/app_theme.dart';

/// Chữ trong ô nhập của Figma S08-1: 14/1.4, cùng input padding dưới cho ra ô
/// cao ~48 ở cỡ chữ thường và tự giãn khi người dùng bật chữ lớn.
const profileFieldTextStyle =
    TextStyle(fontSize: 14, height: 1.4, color: AppColors.ink);

/// Decoration dùng chung cho ô nhập: padding ngang 14, viền 1px `#E4E4E1` bo 12
/// (lấy từ `inputDecorationTheme`), chừa chỗ cho icon ở cuối.
InputDecoration profileFieldDecoration({
  String? hintText,
  String? helperText,
  Widget? suffixIcon,
  String? errorText,
}) =>
    InputDecoration(
      hintText: hintText,
      helperText: helperText,
      helperMaxLines: 2,
      errorText: errorText,
      errorMaxLines: 2,
      hintStyle: AppTextStyles.caption,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      suffixIcon: suffixIcon,
    );

/// Số điện thoại API trả về ở dạng E.164 (`+84912…`); hiển thị dạng nội địa cho
/// dễ đọc. Không đổi giá trị gửi lên, chỉ đổi cách hiển thị.
String profilePhoneLabel(String? phone) {
  final value = phone?.trim();
  if (value == null || value.isEmpty) return 'Chưa cung cấp';
  if (value.startsWith('+84') && value.length > 3) {
    return '0${value.substring(3)}';
  }
  return value;
}

class ProfileFieldPair extends StatelessWidget {
  const ProfileFieldPair({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        if (box.maxWidth < 330 ||
            MediaQuery.textScalerOf(context).scale(16) > 21) {
          return Column(children: children);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: children[0]),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: children[1]),
        ]);
      });
}

class ProfileField extends StatelessWidget {
  const ProfileField({super.key, required this.label, required this.child});
  final String label;
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(label,
            style: AppTextStyles.captionStrong
                .copyWith(color: AppColors.ink, fontWeight: FontWeight.w700)),
        const SizedBox(height: AppSpacing.sm),
        child,
      ]));
}
