import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_theme.dart';

/// Ô nhập số điện thoại theo thiết kế `field/phone` và `Input/phone`:
/// - Rộng 327px, Cao 73px
/// - Label: 13px / line-height 19px [AppColors.ink]
/// - Khung nhập: Cao 48px, viền 1px [AppColors.border], bo góc 8px, nền [AppColors.surface]
/// - Tiền tố: '+84' (15px / line-height 22px [AppColors.ink])
/// - Đường phân cách: 1px x 22px [AppColors.border]
/// - Placeholder: '090 123 4567'
class PhoneInputField extends StatelessWidget {
  const PhoneInputField({
    super.key,
    required this.controller,
    this.onChanged,
    this.errorMessage,
    this.enabled = true,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final String? errorMessage;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 327.0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // field-label
          const Text(
            'Số điện thoại',
            style: TextStyle(
              fontSize: 13.0,
              fontWeight: FontWeight.w400,
              height: 19.0 / 13.0,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 6.0),

          // Input/phone container
          Container(
            width: 327.0,
            height: 48.0,
            padding: const EdgeInsets.symmetric(horizontal: 14.0),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(
                color: errorMessage != null ? AppColors.danger : AppColors.border,
                width: 1.0,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // prefix
                const Text(
                  '+84',
                  style: TextStyle(
                    fontSize: 15.0,
                    fontWeight: FontWeight.w400,
                    height: 22.0 / 15.0,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(width: 8.0),

                // divider (1px x 22px)
                Container(
                  width: 1.0,
                  height: 22.0,
                  color: AppColors.border,
                ),
                const SizedBox(width: 8.0),

                // text field
                Expanded(
                  child: TextField(
                    controller: controller,
                    enabled: enabled,
                    onChanged: onChanged,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(11),
                      _VietnamesePhoneFormatter(),
                    ],
                    style: const TextStyle(
                      fontSize: 15.0,
                      fontWeight: FontWeight.w400,
                      height: 22.0 / 15.0,
                      color: AppColors.ink,
                    ),
                    decoration: const InputDecoration(
                      hintText: '090 123 4567',
                      hintStyle: TextStyle(
                        fontSize: 15.0,
                        fontWeight: FontWeight.w400,
                        height: 22.0 / 15.0,
                        color: AppColors.inkMuted,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (errorMessage case final msg?) ...[
            const SizedBox(height: 4.0),
            Text(
              msg,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w400,
                height: 17.0 / 11.5,
                color: AppColors.danger,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Tự động chèn dấu cách khi nhập số điện thoại Việt Nam: 090 123 4567
class _VietnamesePhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(' ', '');
    final buffer = StringBuffer();

    for (int i = 0; i < text.length; i++) {
      if (i == 3 || i == 6) {
        buffer.write(' ');
      }
      buffer.write(text[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
