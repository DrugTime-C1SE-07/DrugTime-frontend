import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';

/// Ô nhập email cho màn hình đăng nhập:
/// - Rộng 327px, Cao 73px
/// - Label: 13px / line-height 19px [AppColors.ink]
/// - Khung nhập: Cao 48px, viền 1px [AppColors.border], bo góc 8px, nền [AppColors.surface]
class EmailInputField extends StatelessWidget {
  const EmailInputField({
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
            'Email',
            style: TextStyle(
              fontSize: 13.0,
              fontWeight: FontWeight.w400,
              height: 19.0 / 13.0,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 6.0),

          // Input container
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
            alignment: Alignment.centerLeft,
            child: TextField(
              controller: controller,
              enabled: enabled,
              onChanged: onChanged,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              enableSuggestions: false,
              style: const TextStyle(
                fontSize: 15.0,
                fontWeight: FontWeight.w400,
                height: 22.0 / 15.0,
                color: AppColors.ink,
              ),
              decoration: const InputDecoration(
                hintText: 'name@example.com',
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
