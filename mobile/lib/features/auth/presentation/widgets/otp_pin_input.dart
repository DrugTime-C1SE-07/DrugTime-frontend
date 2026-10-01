import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_theme.dart';

/// Ô nhập mã OTP 6 số theo đặc tả Figma:
/// - Container: 327px x 56px, gap: 8px, căn giữa
/// - 6 ô nhập: mỗi ô 47px x 56px, nền #FFFFFF, bo góc 8px
/// - Viền:
///   + Bình thường: 1px #E4E4E1 ([AppColors.border])
///   + Đang trỏ/kích hoạt: 2px #01554F ([AppColors.brand])
///   + Có lỗi: 2px #B91C1C ([AppColors.danger])
/// - Chữ số: Inter 20px, line-height 27px, màu #211D1D ([AppColors.ink])
/// - Hỗ trợ gõ liên tục, xoá lùi (Backspace), dán cả chuỗi 6 số (Paste)
class OtpPinInput extends StatefulWidget {
  const OtpPinInput({
    super.key,
    required this.controller,
    required this.focusNode,
    this.onChanged,
    this.onCompleted,
    this.hasError = false,
    this.enabled = true,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onCompleted;
  final bool hasError;
  final bool enabled;

  @override
  State<OtpPinInput> createState() => _OtpPinInputState();
}

class _OtpPinInputState extends State<OtpPinInput> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleTextChange);
    widget.focusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant OtpPinInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleTextChange);
      widget.controller.addListener(_handleTextChange);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_handleFocusChange);
      widget.focusNode.addListener(_handleFocusChange);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleTextChange);
    widget.focusNode.removeListener(_handleFocusChange);
    super.dispose();
  }

  void _handleTextChange() {
    setState(() {});
    final text = widget.controller.text;
    widget.onChanged?.call(text);
    if (text.length == 6) {
      widget.onCompleted?.call(text);
    }
  }

  void _handleFocusChange() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.controller.text;
    final hasFocus = widget.focusNode.hasFocus;

    return Semantics(
      label: 'Mã xác thực OTP gồm 6 chữ số',
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 6 ô hiển thị giao diện theo đúng CSS Figma
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(6, (index) {
              final isFilled = index < text.length;
              final digit = isFilled ? text[index] : '';

              // Ô đang được trỏ: là ô trống đầu tiên hoặc ô thứ 6 khi đã nhập đủ 6 số
              final isActive = hasFocus &&
                  (index == text.length || (index == 5 && text.length == 6));

              return Container(
                key: ValueKey<String>('otp_box_$index'),
                width: 47.0,
                height: 56.0,
                margin: EdgeInsets.only(right: index < 5 ? 8.0 : 0.0),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(
                    color: widget.hasError
                        ? AppColors.danger
                        : isActive
                            ? AppColors.brand
                            : AppColors.border,
                    width: (isActive || widget.hasError) ? 2.0 : 1.0,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  digit,
                  style: const TextStyle(
                    fontSize: 20.0,
                    fontWeight: FontWeight.w400,
                    height: 27.0 / 20.0,
                    color: AppColors.ink,
                    fontFamily: 'Inter',
                  ),
                ),
              );
            }),
          ),

          // TextField ẩn tiếp nhận phím nhập từ bàn phím hệ điều hành
          Positioned.fill(
            child: Opacity(
              opacity: 0.0,
              child: TextField(
                controller: widget.controller,
                focusNode: widget.focusNode,
                enabled: widget.enabled,
                keyboardType: TextInputType.number,
                autofocus: true,
                maxLength: 6,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
